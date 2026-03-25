import Testing
@testable import PromptTimerCore

@Test func parsesValidDurations() throws {
    #expect(try DurationParser.parse("10") == 600)
    #expect(try DurationParser.parse("10m") == 600)
    #expect(try DurationParser.parse("30s") == 30)
    #expect(try DurationParser.parse("1h") == 3600)
    #expect(try DurationParser.parse("1h30m") == 5400)
    #expect(try DurationParser.parse("2m15s") == 135)
    #expect(try DurationParser.parse("1h2m3s") == 3723)
}

@Test func rejectsInvalidDurations() {
    #expect(throws: Error.self) { try DurationParser.parse("") }
    #expect(throws: Error.self) { try DurationParser.parse("0") }
    #expect(throws: Error.self) { try DurationParser.parse("-1") }
    #expect(throws: Error.self) { try DurationParser.parse("1hm") }
    #expect(throws: Error.self) { try DurationParser.parse("m10") }
    #expect(throws: Error.self) { try DurationParser.parse("10x") }
}
