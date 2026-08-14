import SwiftUI

/// Shared navigation state, so something outside the SwiftUI tree — the menu bar — can
/// drive what the window shows.
///
/// The tool selection used to be `@State` private to `AppShellView`, which meant nothing
/// else could change it. A quick action has to: pick the tool, hand it the clipboard text,
/// and (for multi-mode tools) pick the right mode. All three live here.
final class AppState: ObservableObject {
    /// One instance, referenced by both the SwiftUI tree and `MenuBarController`. The menu
    /// bar isn't a view, so it can't receive an `@EnvironmentObject`.
    static let shared = AppState()

    @Published var selectedToolId: String = ToolRegistry.shared.all.first?.id ?? ""

    /// Text waiting to be dropped into the next tool view that appears. Consumed (set back
    /// to `nil`) by whichever `ToolView` picks it up, so it can't leak into a tool the user
    /// navigates to later by hand.
    @Published var pendingInput: String?

    /// Which mode the arriving tool should switch to, for tools with a mode pill.
    @Published var pendingModeIndex: Int?

    /// Bumped on every navigation request. `AppShellView` folds this into the content
    /// view's `.id(...)`, which forces SwiftUI to build a fresh tool view even when the
    /// same tool is already showing — that's what guarantees `onAppear` fires and the
    /// pending input actually gets picked up. Without it, running a quick action twice in a
    /// row for the same tool would silently do nothing the second time.
    @Published var navigationToken: Int = 0

    @Published var isSettingsPresented = false

    private init() {}

    /// Point the window at `toolId`, optionally prefilling its input and mode.
    func navigate(toToolID toolId: String, input: String? = nil, modeIndex: Int? = nil) {
        pendingInput = input
        pendingModeIndex = modeIndex
        selectedToolId = toolId
        navigationToken &+= 1
    }

    /// Called by a tool view once it has taken the pending values.
    func consumePendingInput() -> (input: String?, modeIndex: Int?) {
        let values = (pendingInput, pendingModeIndex)
        pendingInput = nil
        pendingModeIndex = nil
        return values
    }
}
