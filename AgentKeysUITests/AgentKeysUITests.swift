import XCTest

/// Release gate: the deck renders custom hardware-style controls, so this
/// verifies they are real, hittable accessibility elements — not just pixels.
final class AgentKeysUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingExposesInteractiveButtons() throws {
        let app = launch(onboarded: false)

        let getStarted = app.buttons["onboarding-get-started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10), "Get Started button must be exposed to accessibility")
        XCTAssertTrue(getStarted.isHittable)
        XCTAssertTrue(app.buttons["onboarding-connect-mac"].exists)

        getStarted.tap()
        XCTAssertTrue(app.buttons["deck-mode-knob"].waitForExistence(timeout: 10), "Deck must appear after onboarding")
    }

    @MainActor
    func testDeckExposesInteractiveControls() throws {
        let app = launch(onboarded: true)

        let knob = app.buttons["deck-mode-knob"]
        XCTAssertTrue(knob.waitForExistence(timeout: 10), "Mode knob must be exposed to accessibility")
        XCTAssertTrue(knob.isHittable)

        for identifier in [
            "deck-control-stick",
            "deck-connection-chip",
            "deck-settings",
            "deck-key-stop",
            "deck-key-approve",
            "deck-key-reject",
            "deck-key-branch",
            "deck-key-new",
            "deck-push-to-talk",
            "deck-send-prompt",
        ] {
            XCTAssertTrue(app.buttons[identifier].exists, "\(identifier) must be exposed to accessibility")
        }

        XCTAssertTrue(app.textFields["deck-prompt-field"].exists, "Prompt field must be exposed to accessibility")

        let agentKeys = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deck-agent-key-'"))
        XCTAssertGreaterThan(agentKeys.count, 0, "Agent channel keys must be exposed to accessibility")
        XCTAssertTrue(agentKeys.firstMatch.isHittable)

        // Selecting a channel must actually work through the accessibility layer.
        agentKeys.firstMatch.tap()
    }

    @MainActor
    private func launch(onboarded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", onboarded ? "YES" : "NO"]
        app.launch()
        return app
    }
}
