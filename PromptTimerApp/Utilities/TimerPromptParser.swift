import Foundation

public struct TimerPrompt: Equatable, Sendable {
    public var durationSeconds: Int
    public var label: String?
    public var action: TimerAction?

    public init(durationSeconds: Int, label: String?, action: TimerAction?) {
        self.durationSeconds = durationSeconds
        self.label = label
        self.action = action
    }
}

public enum TimerPromptParser {
    public static func parse(tokens: [String]) throws -> TimerPrompt {
        if let actionFirstPrompt = try parseActionFirst(tokens: tokens) {
            return actionFirstPrompt
        }

        let (durationSeconds, remainingTokens) = try DurationParser.parseTokens(tokens)
        let (label, action) = parseDurationFirstDetails(from: remainingTokens)
        return TimerPrompt(durationSeconds: durationSeconds, label: label, action: action)
    }

    private static func parseActionFirst(tokens: [String]) throws -> TimerPrompt? {
        guard let actionMatch = leadingActionMatch(in: tokens) else {
            return nil
        }

        let remainingTokens = Array(tokens.dropFirst(actionMatch.length))
        let normalizedRemainingTokens = remainingTokens.map(normalize)

        guard let inIndex = normalizedRemainingTokens.firstIndex(of: "in"),
              inIndex > 0 else {
            return nil
        }

        let targetTokens = Array(remainingTokens[..<inIndex])
        guard let target = join(targetTokens) else {
            return nil
        }

        let timingTokens = Array(remainingTokens[(inIndex + 1)...])
        let (durationSeconds, detailTokens) = try DurationParser.parseTokens(timingTokens)

        var labelTokens = detailTokens
        if labelTokens.first.map(normalize) == "for" {
            labelTokens.removeFirst()
        }

        return TimerPrompt(
            durationSeconds: durationSeconds,
            label: join(labelTokens),
            action: .launchApplication(target: target)
        )
    }

    private static func parseDurationFirstDetails(from tokens: [String]) -> (String?, TimerAction?) {
        if let details = parseLeadingActionDetails(from: tokens) {
            return details
        }

        if let details = parseTrailingActionDetails(from: tokens) {
            return details
        }

        if let details = parseNaturalLanguageAppDetails(from: tokens) {
            return details
        }

        return (join(tokens), nil)
    }

    private static func parseLeadingActionDetails(from tokens: [String]) -> (String?, TimerAction?)? {
        guard let actionMatch = leadingActionMatch(in: tokens) else {
            return nil
        }

        let remainingTokens = Array(tokens.dropFirst(actionMatch.length))
        let normalizedRemainingTokens = remainingTokens.map(normalize)

        guard let separatorIndex = firstLabelSeparatorIndex(in: normalizedRemainingTokens),
              separatorIndex > 0,
              separatorIndex < remainingTokens.count - 1 else {
            return nil
        }

        let targetTokens = Array(remainingTokens[..<separatorIndex])
        let labelTokens = Array(remainingTokens[(separatorIndex + 1)...])
        guard let target = join(targetTokens),
              let label = join(labelTokens) else {
            return nil
        }

        return (label, .launchApplication(target: target))
    }

    private static func parseTrailingActionDetails(from tokens: [String]) -> (String?, TimerAction?)? {
        guard let actionMatch = trailingActionMatch(in: tokens) else {
            return nil
        }

        let labelTokens = Array(tokens[..<actionMatch.startIndex])
        let targetTokens = Array(tokens[actionMatch.endIndex...])
        guard !labelTokens.isEmpty else {
            return nil
        }

        let target = join(targetTokens)

        guard let target else {
            return nil
        }

        return (join(labelTokens), .launchApplication(target: target))
    }

    private static func parseNaturalLanguageAppDetails(from tokens: [String]) -> (String?, TimerAction?)? {
        let normalizedTokens = tokens.map(normalize)
        var bestMatch: ActionMatch?

        for startIndex in tokens.indices {
            for phrase in appPrepositionPhrases {
                let endIndex = startIndex + phrase.count
                guard endIndex < tokens.count else {
                    continue
                }
                guard startIndex > 0 else {
                    continue
                }
                guard Array(normalizedTokens[startIndex..<endIndex]) == phrase else {
                    continue
                }

                let match = ActionMatch(startIndex: startIndex, endIndex: endIndex, length: phrase.count)
                if bestMatch == nil || startIndex > bestMatch!.startIndex {
                    bestMatch = match
                }
            }
        }

        guard let bestMatch else {
            return nil
        }

        let labelTokens = Array(tokens[..<bestMatch.startIndex])
        let targetTokens = Array(tokens[bestMatch.endIndex...])
        guard let label = join(labelTokens),
              let target = join(targetTokens),
              isKnownNaturalLanguageAppTarget(target) else {
            return nil
        }

        return (label, .launchApplication(target: target))
    }

    private static func join(_ tokens: [String]) -> String? {
        let value = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func leadingActionMatch(in tokens: [String]) -> ActionMatch? {
        let normalizedTokens = tokens.map(normalize)
        for phrase in actionPhrases {
            guard normalizedTokens.count >= phrase.count else {
                continue
            }
            if Array(normalizedTokens.prefix(phrase.count)) == phrase {
                return ActionMatch(startIndex: 0, endIndex: phrase.count, length: phrase.count)
            }
        }
        return nil
    }

    private static func trailingActionMatch(in tokens: [String]) -> ActionMatch? {
        let normalizedTokens = tokens.map(normalize)
        var bestMatch: ActionMatch?

        for startIndex in tokens.indices {
            for phrase in actionPhrases {
                let endIndex = startIndex + phrase.count
                guard endIndex <= tokens.count else {
                    continue
                }
                guard Array(normalizedTokens[startIndex..<endIndex]) == phrase else {
                    continue
                }

                let match = ActionMatch(startIndex: startIndex, endIndex: endIndex, length: phrase.count)
                if startIndex == 0 || endIndex >= tokens.count {
                    continue
                }
                if bestMatch == nil || startIndex > bestMatch!.startIndex {
                    bestMatch = match
                }
            }
        }

        return bestMatch
    }

    private static func firstLabelSeparatorIndex(in normalizedTokens: [String]) -> Int? {
        for token in labelSeparatorWords {
            if let index = normalizedTokens.firstIndex(of: token) {
                return index
            }
        }
        return nil
    }

    private static func isKnownNaturalLanguageAppTarget(_ target: String) -> Bool {
        knownNaturalLanguageAppTargets.contains(normalizePhrase(target))
    }

    private static func normalize(_ token: String) -> String {
        token.lowercased()
    }

    private static func normalizePhrase(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let actionPhrases = [
        ["fire", "up"],
        ["launch"],
        ["start"],
        ["open"],
    ]

    private static let appPrepositionPhrases = [
        ["in"],
        ["on"],
        ["over"],
        ["through"],
        ["using"],
        ["via"],
    ]

    private static let labelSeparatorWords = [
        "about",
        "for",
        "to",
    ]

    private static let knownNaturalLanguageAppTargets: Set<String> = [
        "browser",
        "calendar",
        "chrome",
        "discord",
        "email",
        "facetime",
        "figma",
        "github",
        "gmail",
        "google meet",
        "linear",
        "mail",
        "meet",
        "messages",
        "microsoft teams",
        "notion",
        "safari",
        "slack",
        "teams",
        "terminal",
        "webex",
        "zoom",
    ]
}

private struct ActionMatch {
    let startIndex: Int
    let endIndex: Int
    let length: Int
}
