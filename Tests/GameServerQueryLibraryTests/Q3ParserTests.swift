//
//  Q3ParserTests.swift
//  GameServerQueryLibraryTests
//
//  Tests for Q3Parser, focusing on the critical off-by-one bug in parseServers
//  where the last server in every master-server response was silently dropped.
//

import Testing
@testable import GameServerQueryLibrary

// MARK: - Helpers

/// Builds a syntactically valid master-server UDP response for the given
/// (ip, port) pairs. Format after the response header:
///   IP(4) PORT(2) \(1)  ← all entries except the last
///   IP(4) PORT(2)       ← last entry (separator consumed by EOT sequence)
///   \EOT\0\0\0          ← 7-byte end-of-transmission marker
private func masterResponseData(servers: [(ip: String, port: UInt16)]) -> Data {
    let responseMarker: [UInt8] = [
        0xff, 0xff, 0xff, 0xff,
        0x67, 0x65, 0x74, 0x73, 0x65, 0x72, 0x76, 0x65, 0x72, 0x73,
        0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x5c   // "getserversResponse\"
    ]
    let eot: [UInt8] = [0x5c, 0x45, 0x4f, 0x54, 0x00, 0x00, 0x00]  // \EOT\0\0\0

    var payload: [UInt8] = []
    for (index, server) in servers.enumerated() {
        let octets = server.ip.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { continue }
        payload += octets
        payload += [UInt8(server.port >> 8), UInt8(server.port & 0xff)]
        // All entries except the last are followed by the '\' separator.
        // The last entry's separator is the leading '\' of the EOT sequence.
        if index < servers.count - 1 {
            payload.append(0x5c)
        }
    }
    return Data(responseMarker + payload + eot)
}

// MARK: - parseServers tests

@Suite("Q3Parser — parseServers")
struct Q3ParserParseServersTests {

    // Before the fix: 1 server → returns 0 (loop never fired at i%7==0 for len=6).
    @Test("Single server is returned (was always dropped before fix)")
    func singleServerReturned() {
        let data = masterResponseData(servers: [("1.2.3.4", 27960)])
        let result = Q3Parser.parseServers(data)
        #expect(result.count == 1)
        #expect(result.first == "1.2.3.4:27960")
    }

    // Before the fix: 2 servers → returns 1 (only first was processed).
    @Test("All servers returned for two-server response")
    func twoServersReturned() {
        let data = masterResponseData(servers: [
            ("1.2.3.4", 27960),
            ("5.6.7.8", 27961)
        ])
        let result = Q3Parser.parseServers(data)
        #expect(result.count == 2)
        #expect(result[0] == "1.2.3.4:27960")
        #expect(result[1] == "5.6.7.8:27961")
    }

    // Verify N servers → exactly N results for a larger list.
    @Test("All N servers returned for a five-server response")
    func fiveServersReturned() {
        let input: [(String, UInt16)] = [
            ("10.0.0.1", 27960),
            ("10.0.0.2", 27961),
            ("10.0.0.3", 27962),
            ("10.0.0.4", 27963),
            ("10.0.0.5", 27964)
        ]
        let data = masterResponseData(servers: input)
        let result = Q3Parser.parseServers(data)
        #expect(result.count == 5)
        for (index, expected) in input.enumerated() {
            #expect(result[index] == "\(expected.0):\(expected.1)")
        }
    }

    @Test("Empty data returns empty array")
    func emptyDataReturnsEmptyArray() {
        let result = Q3Parser.parseServers(Data())
        #expect(result.isEmpty)
    }

    @Test("Port is decoded correctly from big-endian bytes")
    func portDecodedBigEndian() {
        // 0x6D38 = 27960
        let data = masterResponseData(servers: [("192.168.1.1", 0x6D38)])
        let result = Q3Parser.parseServers(data)
        #expect(result.first == "192.168.1.1:27960")
    }

    @Test("Response without header marker is handled gracefully")
    func noHeaderMarker() {
        // Raw data with no recognised header — parser should either parse or
        // return empty, but must not crash.
        let rawBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x6D, 0x38]
        let result = Q3Parser.parseServers(Data(rawBytes))
        // The important assertion is no crash; result may be empty or a single
        // entry depending on length — just confirm it's a valid array.
        #expect(result.count >= 0)
    }
}

// MARK: - parseServer tests

@Suite("Q3Parser — parseServer")
struct Q3ParserParseServerTests {

    private func infoResponseData(fields: [String: String]) -> Data {
        let header: [UInt8] = [
            0xff, 0xff, 0xff, 0xff,
            0x69, 0x6e, 0x66, 0x6f, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65,
            0x0a, 0x5c   // "infoResponse\n\"
        ]
        var body = fields.map { "\\\($0.key)\\\($0.value)" }.joined()
        let bytes = [UInt8](header) + [UInt8](body.utf8)
        return Data(bytes)
    }

    @Test("Parses hostname, mapname and gametype from info response")
    func parsesBasicFields() {
        let data = infoResponseData(fields: [
            "hostname": "My Server",
            "mapname": "q3dm1",
            "sv_maxclients": "16",
            "clients": "4",
            "gametype": "0"
        ])
        let result = Q3Parser.parseServer(data)
        #expect(result != nil)
        #expect(result?["hostname"] == "My Server")
        #expect(result?["mapname"] == "q3dm1")
        #expect(result?["gametype"] == "0")
    }

    @Test("Returns nil for empty data")
    func returnsNilForEmptyData() {
        #expect(Q3Parser.parseServer(Data()) == nil)
    }
}

// MARK: - parseServerStatus tests

@Suite("Q3Parser — parseServerStatus")
struct Q3ParserParseServerStatusTests {

    private func statusResponseData(rules: [String: String], playerLines: [String] = []) -> Data {
        let header: [UInt8] = [
            0xff, 0xff, 0xff, 0xff,
            0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65,
            0x0a, 0x5c   // "statusResponse\n\"
        ]
        let ruleStr = rules.map { "\\\($0.key)\\\($0.value)" }.joined()
        let players = playerLines.isEmpty ? "" : "\n" + playerLines.joined(separator: "\n")
        let bytes = [UInt8](header) + [UInt8]((ruleStr + players).utf8)
        return Data(bytes)
    }

    @Test("Parses server rules")
    func parsesRules() {
        let data = statusResponseData(rules: ["mapname": "q3dm7", "fraglimit": "30"])
        let result = Q3Parser.parseServerStatus(data)
        #expect(result != nil)
        #expect(result?.rules.first(where: { $0.key == "mapname" })?.value == "q3dm7")
        #expect(result?.rules.first(where: { $0.key == "fraglimit" })?.value == "30")
    }

    @Test("Parses players from status response")
    func parsesPlayers() {
        let data = statusResponseData(
            rules: ["mapname": "q3dm1"],
            playerLines: ["10 50 \"PlayerOne\"", "5 80 \"PlayerTwo\""]
        )
        let result = Q3Parser.parseServerStatus(data)
        #expect(result?.players.count == 2)
        #expect(result?.players.first?.name == "PlayerOne")
    }

    @Test("Returns nil for empty data")
    func returnsNilForEmptyData() {
        #expect(Q3Parser.parseServerStatus(Data()) == nil)
    }
}
