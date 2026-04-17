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
        guard let actionMatch = trailingActionMatch(in: tokens) else {
            return (join(tokens), nil)
        }

        let labelTokens = Array(tokens[..<actionMatch.startIndex])
        let targetTokens = Array(tokens[actionMatch.endIndex...])
        guard !labelTokens.isEmpty else {
            return (join(tokens), nil)
        }

        let target = join(targetTokens)

        guard let target else {
            return (join(tokens), nil)
        }

        return (join(labelTokens), .launchApplication(target: target))
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

    private static func normalize(_ token: String) -> String {
        token.lowercased()
    }

    private static let actionPhrases = [
        ["fire", "up"],
        ["launch"],
        ["start"],
        ["open"],
    ]
}

private struct ActionMatch {
    let startIndex: Int
    let endIndex: Int
    let length: Int
}
