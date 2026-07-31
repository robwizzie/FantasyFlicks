//
//  FantasyFlicksTests.swift
//  FantasyFlicksTests
//
//  Created by Robert Wiscount on 1/31/26.
//

import Testing
@testable import FantasyFlicks

struct FantasyFlicksTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

// MARK: - Letterboxd CSV Parsing

/// Letterboxd writes every export with CRLF record separators. Swift treats
/// CRLF as a *single* extended grapheme cluster, so a `Character`-based
/// tokenizer matched it against neither "\r" nor "\n" — the whole file
/// collapsed into one row and every import reported zero matches.
struct LetterboxdCSVParsingTests {

    @Test func parsesCRLFRecords() {
        let csv = "Date,Name,Year,Letterboxd URI\r\n"
                + "2024-03-01,Fight Club,1999,https://boxd.it/2a1u\r\n"
                + "2024-03-02,Sinners,2025,https://boxd.it/xyz\r\n"

        let rows = SeenMoviesService.parseCSV(csv)

        #expect(rows.count == 3)
        #expect(rows[0] == ["Date", "Name", "Year", "Letterboxd URI"])
        #expect(rows[1][1] == "Fight Club")
        #expect(rows[2][1] == "Sinners")
    }

    @Test func parsesLFOnlyRecords() {
        let rows = SeenMoviesService.parseCSV("Date,Name,Year\n2024-03-01,Dune,2021\n")

        #expect(rows.count == 2)
        #expect(rows[1][1] == "Dune")
    }

    @Test func keepsCommasAndEscapedQuotesInsideQuotedFields() {
        let csv = "Name,Review\r\n"
                + "Fight Club,\"Great film, really \"\"peak\"\" Fincher.\"\r\n"

        let rows = SeenMoviesService.parseCSV(csv)

        #expect(rows.count == 2)
        #expect(rows[1][1] == "Great film, really \"peak\" Fincher.")
    }

    @Test func normalisesHardLineBreaksInsideAReviewBody() {
        let rows = SeenMoviesService.parseCSV("Name,Review\r\nX,\"line one\r\nline two\"\r\n")

        #expect(rows.count == 2)
        #expect(rows[1][1] == "line one\nline two")
    }

    @Test func handlesAByteOrderMarkAheadOfTheHeader() {
        let csv = "\u{FEFF}Date,Name,Year\r\n2024-03-01,Sinners,2025\r\n"
        let stripped = csv.hasPrefix("\u{FEFF}") ? String(csv.dropFirst()) : csv

        let rows = SeenMoviesService.parseCSV(stripped)

        #expect(rows[0][1] == "Name")
        #expect(rows[1][1] == "Sinners")
    }

    @Test func dropsTheEmptyRecordATrailingNewlineLeavesBehind() {
        let rows = SeenMoviesService.parseCSV("Name\r\nDune\r\n")

        #expect(rows.count == 2)
    }
}
