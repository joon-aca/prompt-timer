import Testing
@testable import PromptTimerCore

@Test func parsesPromptWithLaunchActionSuffix() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["10:30am", "team", "call", "launch", "zoom"])

    #expect(prompt.durationSeconds > 0)
    #expect(prompt.durationSeconds <= 86400)
    #expect(prompt.label == "team call")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesPromptWithSynonymActionSuffix() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["10:30am", "team", "call", "fire", "up", "zoom"])

    #expect(prompt.durationSeconds > 0)
    #expect(prompt.durationSeconds <= 86400)
    #expect(prompt.label == "team call")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesActionFirstPrompt() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["start", "zoom", "in", "30min", "for", "team", "call"])

    #expect(prompt.durationSeconds == 1800)
    #expect(prompt.label == "team call")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesActionFirstPromptWithoutForKeyword() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["open", "zoom", "in", "25", "team", "call"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "team call")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func keepsOpenQuestionsAsLabel() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["25", "open", "questions"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "open questions")
    #expect(prompt.action == nil)
}

@Test func leavesLaunchWordInLabelWhenNoTargetFollows() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["25", "product", "launch"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "product launch")
    #expect(prompt.action == nil)
}
