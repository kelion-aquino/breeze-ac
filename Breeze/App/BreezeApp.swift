import SwiftUI

enum AppEnvironment {
    // `-demo` opens the panel in a normal window with sample data.
    static let isDemo = CommandLine.arguments.contains("-demo")
}

@main
struct BreezeApp: App {
    @State private var auth: AuthManager
    @State private var store: ACStore

    init() {
        let auth = AuthManager()
        let store = ACStore(client: SmartThingsClient(auth: auth), demo: AppEnvironment.isDemo)
        auth.onStateChange = { state in
            state == .signedIn ? store.start() : store.stop()
        }
        if auth.state == .signedIn { store.start() }
        _auth = State(initialValue: auth)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(auth)
                .environment(store)
        } label: {
            MenuBarLabel(state: store.selectedState)
        }
        .menuBarExtraStyle(.window)

        Window("Connect to SmartThings", id: "login") {
            LoginView()
                .environment(auth)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("Breeze", id: "demo") {
            PopoverView()
                .environment(auth)
                .environment(store)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(AppEnvironment.isDemo ? .presented : .suppressed)
    }
}

// The menu bar ignores images inside Text, so we draw the icon and the
// temperature into one template image.
private struct MenuBarLabel: View {
    let state: ACState?

    var body: some View {
        Image(nsImage: Self.render(temperature: state.flatMap { $0.isOn ? $0.setpoint : nil }))
    }

    private static func render(temperature: Int?) -> NSImage {
        let content = HStack(spacing: 4) {
            Image(systemName: temperature == nil ? "air.conditioner.horizontal" : "air.conditioner.horizontal.fill")
            if let temperature {
                Text("\(temperature)°").monospacedDigit()
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.black)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}
