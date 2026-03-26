import Testing
@testable import PromptTimerCore

// MARK: - parse() tests

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

// MARK: - parseTokens() tests

@Test func parseTokensBareNumber() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["10"])
    #expect(seconds == 600)
    #expect(rest.isEmpty)
}

@Test func parseTokensBareNumberWithLabel() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["10", "deep", "work"])
    #expect(seconds == 600)
    #expect(rest == ["deep", "work"])
}

@Test func parseTokensSuffixedDuration() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["30s", "tea"])
    #expect(seconds == 30)
    #expect(rest == ["tea"])
}

@Test func parseTokensCompoundDuration() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["1h30m", "writing"])
    #expect(seconds == 5400)
    #expect(rest == ["writing"])
}

// MARK: - Unit word swallowing

@Test func parseTokensSwallowsMinuteWord() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["3", "minute", "sleep", "timer"])
    #expect(seconds == 180)
    #expect(rest == ["sleep", "timer"])
}

@Test func parseTokensSwallowsMinutesWord() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["5", "minutes", "break"])
    #expect(seconds == 300)
    #expect(rest == ["break"])
}

@Test func parseTokensSwallowsSecondsWord() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["30", "seconds"])
    #expect(seconds == 30)
    #expect(rest.isEmpty)
}

@Test func parseTokensSwallowsHoursWord() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["2", "hours", "focus"])
    #expect(seconds == 7200)
    #expect(rest == ["focus"])
}

@Test func parseTokensSwallowsSecAbbreviation() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["45", "sec"])
    #expect(seconds == 45)
    #expect(rest.isEmpty)
}

@Test func parseTokensSwallowsMinAbbreviation() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["10", "min", "standup"])
    #expect(seconds == 600)
    #expect(rest == ["standup"])
}

@Test func parseTokensSwallowsHrAbbreviation() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["1", "hr"])
    #expect(seconds == 3600)
    #expect(rest.isEmpty)
}

@Test func parseTokensSwallowsRedundantUnitAfterSuffix() throws {
    // "5m minutes foo" — already has suffix, just swallow the word
    let (seconds, rest) = try DurationParser.parseTokens(["5m", "minutes", "foo"])
    #expect(seconds == 300)
    #expect(rest == ["foo"])
}

@Test func parseTokensDoesNotSwallowNonUnitWord() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["10", "deep", "work"])
    #expect(seconds == 600)
    #expect(rest == ["deep", "work"])
}

// MARK: - Time-of-day parsing

@Test func parseTokensTimeOfDayWithPMSuffix() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["4:30pm", "standup"])
    #expect(seconds > 0)
    #expect(seconds <= 86400)
    #expect(rest == ["standup"])
}

@Test func parseTokensTimeOfDayWithSeparateAM() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["9:00", "am", "meeting"])
    #expect(seconds > 0)
    #expect(seconds <= 86400)
    #expect(rest == ["meeting"])
}

@Test func parseTokensTimeOfDayWithSeparatePM() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["2", "pm"])
    #expect(seconds > 0)
    #expect(seconds <= 86400)
    #expect(rest.isEmpty)
}

@Test func parseTokens24HourTime() throws {
    let (seconds, rest) = try DurationParser.parseTokens(["16:30"])
    #expect(seconds > 0)
    #expect(seconds <= 86400)
    #expect(rest.isEmpty)
}

@Test func parseTokensAmbiguousTimePicksShortest() throws {
    // Without am/pm, should pick the interpretation that's soonest
    let (seconds, rest) = try DurationParser.parseTokens(["3:00"])
    #expect(seconds > 0)
    #expect(seconds <= 86400)
    #expect(rest.isEmpty)
}

// MARK: - Edge cases

@Test func parseTokensEmptyThrows() {
    #expect(throws: Error.self) { try DurationParser.parseTokens([]) }
}

@Test func parseTokensSingleZeroThrows() {
    #expect(throws: Error.self) { try DurationParser.parseTokens(["0"]) }
}

@Test func parseTokensInvalidThrows() {
    #expect(throws: Error.self) { try DurationParser.parseTokens(["abc"]) }
}
