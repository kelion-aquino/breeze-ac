import ServiceManagement
import SwiftUI

struct PopoverView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ACStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if auth.state == .signedOut && !AppEnvironment.isDemo {
                connectPrompt
            } else if let device = store.selectedDevice, let state = store.selectedState {
                ControlPanel(device: device, state: state)
            } else {
                loadingOrError
            }
        }
        .padding(16)
        .frame(width: 368)
        .task { await store.refreshAll(requestingReport: true) }
    }

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            ACIllustration(isOn: false, isWindFree: false, setpoint: 24, accent: .secondary)
            Text("Connect your SmartThings account")
                .font(.headline)
            Text("You only sign in once. After that the app renews access on its own.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Connect") {
                openWindow(id: "login")
                NSApp.activate()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Button("Quit Breeze") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var loadingOrError: some View {
        VStack(spacing: 12) {
            if case .failed(let message) = store.activity {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                Button("Try again") { store.start() }
                    .buttonStyle(.glass)
            } else if store.activity == .loading || store.devices.isEmpty && store.lastUpdated == nil {
                ProgressView()
                Text("Looking for your devices…")
                    .foregroundStyle(.secondary)
            } else {
                Text("No air conditioners found in your account.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Control panel

private struct ControlPanel: View {
    @Environment(ACStore.self) private var store
    let device: ACDevice
    let state: ACState

    private var accent: Color { Labels.accent(mode: state.mode, isOn: state.isOn) }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 14) {
                header
                ACIllustration(isOn: state.isOn, isWindFree: state.isWindFree, setpoint: state.setpoint, accent: accent)
                    .padding(.top, 2)
                temperatureRow
                setpointSlider
                controlGrid
                    .opacity(state.isOn ? 1 : 0.6)
                footer
            }
        }
        .animation(.smooth(duration: 0.35), value: state)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            devicePicker
            Spacer(minLength: 4)
            roomReadings
            powerButton
        }
    }

    private var devicePicker: some View {
        Menu {
            Picker("Device", selection: Binding(
                get: { device.id },
                set: { store.selectedID = $0 }
            )) {
                ForEach(store.devices) { device in
                    Text(device.label).tag(device.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "air.conditioner.horizontal")
                Text(device.label)
                    .lineLimit(1)
                if store.devices.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var roomReadings: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let temperature = state.roomTemperature {
                Label("\(temperature, format: .number.precision(.fractionLength(0)))°C", systemImage: "thermometer.medium")
                    .font(.callout.weight(.semibold))
            }
            if let humidity = state.humidity {
                Label("\(humidity, format: .number.precision(.fractionLength(0)))%", systemImage: "humidity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .labelStyle(CompactLabelStyle())
        .monospacedDigit()
        .help("Room temperature and humidity")
    }

    private var powerButton: some View {
        Button {
            store.setPower(!state.isOn)
        } label: {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(state.isOn ? .white : .primary)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(state.isOn ? .regular.tint(accent).interactive() : .regular.interactive(), in: .circle)
        .help(state.isOn ? Text("Turn off") : Text("Turn on"))
        .keyboardShortcut(.space, modifiers: [])
    }

    // MARK: Temperature

    private var temperatureRow: some View {
        HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(state.setpoint)")
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(state.setpoint)))
                Text("°C")
                    .font(.title2.weight(.light))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if state.supportsWindFree {
                windFreeToggle
            }
        }
    }

    private var windFreeToggle: some View {
        Toggle(isOn: Binding(
            get: { state.isWindFree },
            set: { store.setOptionalMode($0 ? "windFree" : "off") }
        )) {
            Label("WindFree", systemImage: "aqi.low")
                .font(.callout.weight(.semibold))
        }
        .toggleStyle(.switch)
        .tint(accent)
        .controlSize(.small)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassEffect(state.isWindFree ? .regular.tint(accent.opacity(0.35)) : .regular, in: .capsule)
    }

    private var setpointSlider: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                stepButton("minus", delta: -1)
                Slider(
                    value: Binding(
                        get: { Double(state.setpoint) },
                        set: { store.setSetpoint(Int($0.rounded())) }
                    ),
                    in: Double(state.minSetpoint)...Double(state.maxSetpoint),
                    step: 1
                )
                .tint(accent)
                stepButton("plus", delta: 1)
            }
            HStack {
                Text("\(state.minSetpoint)°")
                Spacer()
                Text("\(state.maxSetpoint)°")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 46)
        }
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        Button {
            store.setSetpoint(state.setpoint + delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .keyboardShortcut(delta > 0 ? .upArrow : .downArrow, modifiers: [])
    }

    // MARK: Cards

    private var controlGrid: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                ControlCard(title: String(localized: "Mode"), options: state.supportedModes, selection: state.mode, accent: accent,
                            label: Labels.mode, icon: Labels.modeIcon, onSelect: store.setMode)
                ControlCard(title: String(localized: "Fan"), options: state.availableFanModes, selection: state.fanMode, accent: accent,
                            label: Labels.fan, icon: Labels.fanIcon, onSelect: store.setFanMode)
            }
            GridRow {
                ControlCard(title: String(localized: "Swing"), options: state.supportedOscillations, selection: state.oscillation, accent: accent,
                            label: Labels.oscillation, icon: Labels.oscillationIcon, onSelect: store.setOscillation)
                ControlCard(title: String(localized: "Special mode"), options: state.supportedOptionalModes, selection: state.optionalMode, accent: accent,
                            label: Labels.optionalMode, icon: Labels.optionalModeIcon, onSelect: store.setOptionalMode)
            }
        }
    }

    // MARK: Footer

    private var displayLightButton: some View {
        let isLit = store.isDisplayLightOn(device.id)
        return Button {
            store.setDisplayLight(!isLit)
        } label: {
            Image(systemName: isLit ? "lightbulb.fill" : "lightbulb.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isLit ? Color.yellow : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(isLit ? Text("Turn display light off") : Text("Turn display light on"))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            StatusIndicator(activity: store.activity, lastUpdated: store.lastUpdated)
            Spacer()
            if state.filterNeedsCleaning {
                Label("Clean filter", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .capsule)
                    .help("The filter is at \(state.filterUsage ?? 100)% usage — time to wash it.")
            }
            displayLightButton
            SettingsMenu(state: state)
        }
        .padding(.top, 2)
    }
}

// MARK: - Components

private struct ControlCard: View {
    let title: String
    let options: [String]
    let selection: String
    let accent: Color
    let label: (String) -> String
    let icon: (String) -> String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            Picker(title, selection: Binding(get: { selection }, set: { onSelect($0) })) {
                ForEach(options, id: \.self) { option in
                    Label(label(option), systemImage: icon(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: icon(selection))
                        .font(.title3)
                        .foregroundStyle(accent)
                        .contentTransition(.symbolEffect(.replace))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 10)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label(selection))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .contentShape(.rect(cornerRadius: 18))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }
}

private struct StatusIndicator: View {
    let activity: ACStore.Activity
    let lastUpdated: Date?

    var body: some View {
        switch activity {
        case .sending:
            Label { Text("Sending…") } icon: { ProgressView().controlSize(.mini) }
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Label("Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .help(message)
        default:
            Label("Connected", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(lastUpdated.map { Text("Updated at \($0.formatted(date: .omitted, time: .standard))") } ?? Text(verbatim: ""))
        }
    }
}

private struct SettingsMenu: View {
    @Environment(AuthManager.self) private var auth
    @Environment(ACStore.self) private var store
    let state: ACState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Menu {
            Button("Refresh now", systemImage: "arrow.clockwise") {
                Task { await store.refreshAll(requestingReport: true) }
            }
            .keyboardShortcut("r")
            if let autoClean = state.autoClean {
                Toggle("Auto Clean", systemImage: "sparkles", isOn: Binding(
                    get: { autoClean },
                    set: { store.setAutoClean($0) }
                ))
            }
            Divider()
            Toggle("Open at login", isOn: Binding(
                get: { launchAtLogin },
                set: { enable in
                    try? enable ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            ))
            Button("Disconnect SmartThings") { auth.signOut() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(.circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
