//
//  ServerTests.swift
//  GameServerQueryLibraryTests
//
//  Tests for Server (now a struct) and its mutation methods.
//  Verifies that converting from class to struct preserves all update semantics
//  and that value-type copies are independent (the key property that eliminates
//  the @unchecked Sendable data race).
//

import Testing
@testable import GameServerQueryLibrary

@Suite("Server — value semantics and mutations")
struct ServerTests {

    // MARK: - Initialisation

    @Test("hostname is composed from ip and port")
    func hostnameComposed() {
        let server = Server(ip: "1.2.3.4", port: "27960")
        #expect(server.hostname == "1.2.3.4:27960")
        #expect(server.id == "1.2.3.4:27960")
    }

    @Test("default values are empty / zero after init")
    func defaultsAfterInit() {
        let server = Server(ip: "1.2.3.4", port: "27960")
        #expect(server.name.isEmpty)
        #expect(server.map.isEmpty)
        #expect(server.ping.isEmpty)
        #expect(server.pingInt == 0)
        #expect(server.inGamePlayers == "0/0")
        #expect(server.rules.isEmpty)
        #expect(server.players.isEmpty)
    }

    // MARK: - update(with:) gametype mapping

    @Test("gametype 0 maps to ffa")
    func gametypeFFA() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "0"))
        #expect(server.gametype == "ffa")
    }

    @Test("gametype 1 maps to tourney")
    func gametypeTourney() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "1"))
        #expect(server.gametype == "tourney")
    }

    @Test("gametype 2 maps to ffa")
    func gametypeFFA2() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "2"))
        #expect(server.gametype == "ffa")
    }

    @Test("gametype 3 maps to tdm")
    func gametypeTDM() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "3"))
        #expect(server.gametype == "tdm")
    }

    @Test("gametype 4 maps to ctf")
    func gametypeCTF() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "4"))
        #expect(server.gametype == "ctf")
    }

    @Test("unknown gametype integer maps to unknown")
    func gametypeUnknown() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "99"))
        #expect(server.gametype == "unknown")
    }

    @Test("non-numeric gametype maps to unknown")
    func gametypeNonNumeric() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(gametype: "ctf"))
        #expect(server.gametype == "unknown")
    }

    // MARK: - update(with:) field population

    @Test("update(with:) populates all fields correctly")
    func updateWithPopulatesFields() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(hostname: "Test Server", map: "q3dm7", maxClients: "16", clients: "5", gametype: "0", game: "baseq3"))
        #expect(server.originalName == "Test Server")
        #expect(server.name == "Test Server")
        #expect(server.map == "q3dm7")
        #expect(server.maxPlayers == "16")
        #expect(server.currentPlayers == "5")
        #expect(server.inGamePlayers == "5 / 16")
        #expect(server.mod == "baseq3")
    }

    @Test("update(with:) is a no-op when required keys are missing")
    func updateWithMissingKeys() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: ["hostname": "Only Host"])   // missing mapname, clients, etc.
        #expect(server.name.isEmpty)  // unchanged
    }

    @Test("update(with:) is a no-op for nil input")
    func updateWithNilInput() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: nil)
        #expect(server.name.isEmpty)
    }

    // MARK: - update(currentPlayers:map:ping:)

    @Test("update(currentPlayers:map:ping:) sets ping and inGamePlayers")
    func updateStatusSetsFields() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(maxClients: "16", clients: "0"))
        server.update(currentPlayers: "3", map: "q3dm1", ping: "42")
        #expect(server.ping == "42")
        #expect(server.pingInt == 42)
        #expect(server.map == "q3dm1")
        #expect(server.currentPlayers == "3")
        #expect(server.inGamePlayers == "3 / 16")
    }

    @Test("update(currentPlayers:map:ping:) is a no-op when ping is empty")
    func updateStatusIgnoresEmptyPing() {
        var server = Server(ip: "1.2.3.4", port: "27960")
        server.update(with: makeInfo(clients: "5"))
        server.update(currentPlayers: "9", map: "q3dm7", ping: "")
        // Nothing should have changed
        #expect(server.ping.isEmpty)
        #expect(server.pingInt == 0)
    }

    // MARK: - Value semantics (the key struct guarantee)

    @Test("Mutating a copy does not affect the original (value semantics)")
    func valueSemanticsIndependentCopies() {
        let original = Server(ip: "1.2.3.4", port: "27960")
        var copy = original
        copy.update(with: makeInfo(hostname: "Modified", map: "q3dm7"))
        // original must be untouched
        #expect(original.name.isEmpty)
        #expect(original.map.isEmpty)
        // copy must reflect the update
        #expect(copy.name == "Modified")
        #expect(copy.map == "q3dm7")
    }

    // MARK: - Equatable

    @Test("Two servers with the same ip:port are equal")
    func equalityByHostname() {
        let a = Server(ip: "1.2.3.4", port: "27960")
        let b = Server(ip: "1.2.3.4", port: "27960")
        #expect(a == b)
    }

    @Test("Two servers with different ports are not equal")
    func inequalityDifferentPorts() {
        let a = Server(ip: "1.2.3.4", port: "27960")
        let b = Server(ip: "1.2.3.4", port: "27961")
        #expect(a != b)
    }
}

// MARK: - Private helpers

private func makeInfo(
    hostname: String = "Test Server",
    map: String = "q3dm1",
    maxClients: String = "16",
    clients: String = "0",
    gametype: String = "0",
    game: String = "baseq3"
) -> [String: String] {
    [
        "hostname": hostname,
        "mapname": map,
        "sv_maxclients": maxClients,
        "clients": clients,
        "gametype": gametype,
        "game": game
    ]
}
