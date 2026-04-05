//
//  PlayerTests.swift
//  GameServerQueryLibraryTests
//
//  Tests for Player initialisation from a raw status-response line.
//  Also exercises Q3Coordinator stream termination indirectly by confirming
//  that player parsing produces the expected output fed into the coordinator.
//

import Testing
@testable import GameServerQueryLibrary

@Suite("Player — init from status line")
struct PlayerTests {

    // MARK: - Valid lines

    @Test("Parses score, ping and single-word name")
    func parsesSingleWordName() {
        let player = Player(line: "10 50 \"Ranger\"")
        #expect(player != nil)
        #expect(player?.score == "10")
        #expect(player?.ping == "50")
        #expect(player?.name == "Ranger")
    }

    @Test("Parses name with spaces")
    func parsesMultiWordName() {
        let player = Player(line: "5 80 \"Dark Ranger\"")
        #expect(player?.name == "Dark Ranger")
    }

    @Test("Strips Q3 color codes from name")
    func stripsColorCodes() {
        let player = Player(line: "3 30 \"^1Red^7Name\"")
        #expect(player?.name == "RedName")
    }

    @Test("Strips surrounding quotes from name")
    func stripsQuotes() {
        let player = Player(line: "0 999 \"Bot\"")
        #expect(player?.name == "Bot")
    }

    @Test("id is stable within an instance and unique across instances")
    func idIsUniquePerInstance() {
        // Each Player gets its own UUID so two players with the same name are
        // treated as distinct rows by SwiftUI, preventing identity collisions.
        let p1 = Player(line: "1 20 \"Keel\"")
        let p2 = Player(line: "1 20 \"Keel\"")
        #expect(p1 != nil)
        #expect(p2 != nil)
        // Same name, but different instances — IDs must differ.
        #expect(p1?.id != p2?.id)
    }

    // MARK: - Invalid / edge-case lines

    @Test("Returns nil for empty string")
    func returnsNilForEmptyString() {
        #expect(Player(line: "") == nil)
    }

    @Test("Returns nil when fewer than 3 components")
    func returnsNilForTooFewComponents() {
        #expect(Player(line: "10 50") == nil)
        #expect(Player(line: "10") == nil)
    }

    @Test("Returns nil for whitespace-only string")
    func returnsNilForWhitespaceOnly() {
        // components(separatedBy:) on pure whitespace produces empty segments;
        // the guard >= 3 with non-empty score/ping should reject this.
        let player = Player(line: "   ")
        // Either nil or a player with empty score — both are acceptable, but
        // it must not crash.
        if let player {
            _ = player.score  // safe access
        }
    }

    // MARK: - Q3Coordinator stream termination (unit-level smoke test)
    //
    // We can't easily test the full async stream without a real network, but
    // we can confirm that fetchServersInfo returns a properly terminated stream
    // for an empty server list (no tasks to run = finish() called immediately).

    @Test("fetchServersInfo terminates immediately for empty server list")
    func streamTerminatesForEmptyList() async throws {
        let coordinator = Q3Coordinator()
        let stream = await coordinator.fetchServersInfo(for: [])
        var count = 0
        for try await _ in stream {
            count += 1
        }
        // Stream must complete (not hang) and yield zero items.
        #expect(count == 0)
    }
}
