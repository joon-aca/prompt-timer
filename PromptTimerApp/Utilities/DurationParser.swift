import Foundation

public enum DurationParserError: LocalizedError, Equatable {
    case blank
    case invalid(String)
    case zero

    public var errorDescription: String? {
        switch self {
        case .blank:
            return "Duration is required."
        case let .invalid(value):
            return "Invalid duration. Use 10, 25m, 30s, or 1h30m. Input: \(value)"
        case .zero:
            return "Duration must be greater than zero."
        }
    }
}

public enum DurationParser {
    public static func parse(_ rawValue: String) throws -> Int {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else {
            throw DurationParserError.blank
        }

        if value.allSatisfy(\.isNumber) {
            guard let minutes = Int(value) else {
                throw DurationParserError.invalid(rawValue)
            }
            guard minutes > 0 else {
                throw DurationParserError.zero
            }
            return minutes * 60
        }

        var total = 0
        var digits = ""
        var consumedAtLeastOneUnit = false

        for character in value {
            if character.isNumber {
                digits.append(character)
                continue
            }

            guard let amount = Int(digits), amount > 0 else {
                throw amountError(for: rawValue, currentDigits: digits)
            }

            switch character {
            case "h":
                total += amount * 3600
            case "m":
                total += amount * 60
            case "s":
                total += amount
            default:
                throw DurationParserError.invalid(rawValue)
            }

            digits.removeAll(keepingCapacity: true)
            consumedAtLeastOneUnit = true
        }

        guard consumedAtLeastOneUnit, digits.isEmpty else {
            throw DurationParserError.invalid(rawValue)
        }

        guard total > 0 else {
            throw DurationParserError.zero
        }

        return total
    }

    /// Parses duration from the front of a token list, consuming an optional
    /// trailing unit word (e.g. "minute", "seconds", "hours").
    /// Returns (durationSeconds, remaining label tokens).
    public static func parseTokens(_ tokens: [String]) throws -> (Int, [String]) {
        guard let first = tokens.first else {
            throw DurationParserError.blank
        }

        // Try "until time" parsing first: 4:30pm, 4:30 pm, 16:30, 4pm
        if let (seconds, rest) = parseTimeOfDay(tokens) {
            guard seconds > 0 else {
                throw DurationParserError.invalid(first)
            }
            return (seconds, rest)
        }

        let seconds = try parse(first)
        var rest = Array(tokens.dropFirst())

        // If the duration was a bare number, a following unit word can override
        // the default "minutes" interpretation.
        let isBareDuration = first.allSatisfy(\.isNumber)
        if let unitWord = rest.first {
            let multiplier = unitMultiplier(for: unitWord.lowercased())
            if let multiplier {
                rest.removeFirst()
                if isBareDuration {
                    // Re-interpret: bare number × explicit unit
                    guard let amount = Int(first), amount > 0 else {
                        throw DurationParserError.invalid(first)
                    }
                    return (amount * multiplier, rest)
                }
                // Already had unit suffix (e.g. "5m minutes") — just swallow the word
            }
        }

        return (seconds, rest)
    }

    /// Attempts to parse a time-of-day from the front of the token list.
    /// Supports: "4:30pm", "4:30 PM", "16:30", "4pm", "4 pm"
    /// Returns nil if the tokens don't look like a time-of-day.
    private static func parseTimeOfDay(_ tokens: [String]) -> (Int, [String])? {
        guard let first = tokens.first else { return nil }
        var rest = Array(tokens.dropFirst())
        var timeStr = first.lowercased()

        // Extract am/pm suffix — might be attached ("4:30pm") or separate ("4:30 pm")
        var isPM: Bool?
        if timeStr.hasSuffix("pm") || timeStr.hasSuffix("p") {
            isPM = true
            timeStr = String(timeStr.dropLast(timeStr.hasSuffix("pm") ? 2 : 1))
        } else if timeStr.hasSuffix("am") || timeStr.hasSuffix("a") {
            isPM = false
            timeStr = String(timeStr.dropLast(timeStr.hasSuffix("am") ? 2 : 1))
        } else if let next = rest.first?.lowercased(), ["am", "pm", "a", "p"].contains(next) {
            isPM = (next == "pm" || next == "p")
            rest.removeFirst()
        }

        // Parse hour and optional minute from the numeric part
        let hour: Int
        let minute: Int

        if timeStr.contains(":") {
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2,
                  let h = Int(parts[0]),
                  let m = Int(parts[1]),
                  m >= 0, m < 60 else { return nil }
            hour = h
            minute = m
        } else if let h = Int(timeStr) {
            hour = h
            minute = 0
        } else {
            return nil
        }

        // Must have am/pm for 12-hour times, or be a valid 24-hour time
        // Bare numbers without am/pm or colon are ambiguous (could be duration)
        guard isPM != nil || timeStr.contains(":") else { return nil }

        let calendar = Calendar.current
        let now = Date()

        // Convert to 24-hour
        if let isPM {
            guard hour >= 1, hour <= 12 else { return nil }
            let hour24 = isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour)
            guard let seconds = secondsUntil(hour: hour24, minute: minute, calendar: calendar, now: now) else {
                return nil
            }
            return (seconds, rest)
        }

        // No am/pm: if it's a valid 12-hour time (1–12), try both AM and PM
        // and pick whichever is soonest. For unambiguous 24-hour times (13–23), use directly.
        if hour >= 0, hour <= 12 {
            // Try both interpretations, pick the shortest positive timer
            let candidates = [hour, (hour == 12 ? 0 : hour + 12)] // AM hour, PM hour
            let best = candidates.compactMap { h -> Int? in
                secondsUntil(hour: h, minute: minute, calendar: calendar, now: now)
            }.min()
            guard let seconds = best else { return nil }
            return (seconds, rest)
        } else if hour >= 13, hour < 24 {
            guard let seconds = secondsUntil(hour: hour, minute: minute, calendar: calendar, now: now) else {
                return nil
            }
            return (seconds, rest)
        }

        return nil
    }

    private static func unitMultiplier(for word: String) -> Int? {
        switch word {
        case "s", "sec", "secs", "second", "seconds":
            return 1
        case "m", "min", "mins", "minute", "minutes":
            return 60
        case "h", "hr", "hrs", "hour", "hours":
            return 3600
        default:
            return nil
        }
    }

    private static func secondsUntil(hour: Int, minute: Int, calendar: Calendar, now: Date) -> Int? {
        var target = calendar.dateComponents([.year, .month, .day, .timeZone], from: now)
        target.hour = hour
        target.minute = minute
        target.second = 0
        guard var targetDate = calendar.date(from: target) else { return nil }
        if targetDate <= now {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }
        let seconds = Int(targetDate.timeIntervalSince(now))
        return seconds > 0 ? seconds : nil
    }

    private static func amountError(for rawValue: String, currentDigits: String) -> Error {
        if currentDigits == "0" {
            return DurationParserError.zero
        }
        return DurationParserError.invalid(rawValue)
    }
}
