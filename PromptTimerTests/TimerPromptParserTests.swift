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

@Test func parsesNaturalLanguageAppPreposition() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["10AM", "call", "with", "Zo", "on", "zoom"])

    #expect(prompt.durationSeconds > 0)
    #expect(prompt.durationSeconds <= 86400)
    #expect(prompt.label == "call with Zo")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesMeetingOnZoomAsLaunchAction() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["3m", "meeting", "with", "Zo", "on", "zoom"])

    #expect(prompt.durationSeconds == 180)
    #expect(prompt.label == "meeting with Zo")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesNaturalLanguageEmailPreposition() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["12m", "send", "message", "to", "jack", "on", "email"])

    #expect(prompt.durationSeconds == 720)
    #expect(prompt.label == "send message to jack")
    #expect(prompt.action == .launchApplication(target: "email"))
}

@Test func parsesDurationFirstOpenAppForLabel() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["23m", "open", "zoom", "for", "call", "with", "team"])

    #expect(prompt.durationSeconds == 1380)
    #expect(prompt.label == "call with team")
    #expect(prompt.action == .launchApplication(target: "zoom"))
}

@Test func parsesDurationFirstOpenAppToLabel() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["5m", "launch", "mail", "to", "reply", "to", "Nina"])

    #expect(prompt.durationSeconds == 300)
    #expect(prompt.label == "reply to Nina")
    #expect(prompt.action == .launchApplication(target: "mail"))
}

@Test func keepsOpenQuestionsAsLabel() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["25", "open", "questions"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "open questions")
    #expect(prompt.action == nil)
}

@Test func keepsWorkOnUnknownThingAsLabel() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["25", "work", "on", "slides"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "work on slides")
    #expect(prompt.action == nil)
}

@Test func leavesLaunchWordInLabelWhenNoTargetFollows() throws {
    let prompt = try TimerPromptParser.parse(tokens: ["25", "product", "launch"])

    #expect(prompt.durationSeconds == 1500)
    #expect(prompt.label == "product launch")
    #expect(prompt.action == nil)
}
