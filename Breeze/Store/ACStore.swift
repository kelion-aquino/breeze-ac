import Foundation
import Observation

@Observable
final class ACStore {
    enum Activity: Equatable {
        case idle, loading, sending
        case failed(String)
    }

    private(set) var devices: [ACDevice] = []
    private(set) var states: [String: ACState] = [:]
    private(set) var activity: Activity = .idle
    private(set) var lastUpdated: Date?
    // The API doesn't return the display light state, so we save the last choice.
    private(set) var displayLight: [String: Bool] =
        UserDefaults.standard.dictionary(forKey: "displayLight") as? [String: Bool] ?? [:] {
        didSet { UserDefaults.standard.set(displayLight, forKey: "displayLight") }
    }

    var selectedID: String? {
        didSet { UserDefaults.standard.set(selectedID, forKey: "selectedDeviceID") }
    }

    var selectedDevice: ACDevice? { devices.first { $0.id == selectedID } ?? devices.first }
    var selectedState: ACState? { selectedDevice.flatMap { states[$0.id] } }

    private let client: SmartThingsClient
    private let isDemo: Bool
    private var pollTask: Task<Void, Never>?
    private var setpointTask: Task<Void, Never>?
    private var followUpRefresh: Task<Void, Never>?

    init(client: SmartThingsClient, demo: Bool) {
        self.client = client
        self.isDemo = demo
        selectedID = UserDefaults.standard.string(forKey: "selectedDeviceID")

        if demo {
            devices = ACState.demo.map(\.device)
            states = Dictionary(uniqueKeysWithValues: ACState.demo.map { ($0.device.id, $0.state) })
            selectedID = devices.first?.id
            lastUpdated = .now
        }
    }

    // MARK: - Loading

    func start() {
        guard !isDemo else { return }
        pollTask?.cancel()
        pollTask = Task {
            await loadDevices()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await refreshAll(requestingReport: true)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        devices = []
        states = [:]
    }

    func loadDevices() async {
        activity = .loading
        do {
            devices = try await client.airConditioners()
            if selectedDevice?.id != selectedID { selectedID = devices.first?.id }
            await refreshAll(requestingReport: true)
        } catch {
            activity = .failed(error.localizedDescription)
        }
    }

    func refreshAll(requestingReport: Bool = false) async {
        guard !isDemo, !devices.isEmpty else { return }
        if requestingReport {
            await withTaskGroup(of: Void.self) { group in
                for device in devices {
                    group.addTask { [client] in try? await client.requestReport(from: device.id) }
                }
            }
            try? await Task.sleep(for: .seconds(1.2))
        }
        await withTaskGroup(of: (String, ACState?).self) { group in
            for device in devices {
                group.addTask { [client] in
                    (device.id, try? await client.state(of: device.id))
                }
            }
            for await (id, state) in group {
                if let state { states[id] = state }
            }
        }
        lastUpdated = .now
        if activity != .sending { activity = .idle }
    }

    // MARK: - Commands

    func setPower(_ on: Bool) {
        send(DeviceCommand(capability: "switch", command: on ? "on" : "off")) { $0.isOn = on }
    }

    func setMode(_ mode: String) {
        send(DeviceCommand(capability: "airConditionerMode", command: "setAirConditionerMode", arguments: [.string(mode)])) {
            $0.mode = mode
        }
    }

    func setFanMode(_ fanMode: String) {
        send(DeviceCommand(capability: "airConditionerFanMode", command: "setFanMode", arguments: [.string(fanMode)])) {
            $0.fanMode = fanMode
        }
    }

    func setOscillation(_ oscillation: String) {
        send(DeviceCommand(capability: "fanOscillationMode", command: "setFanOscillationMode", arguments: [.string(oscillation)])) {
            $0.oscillation = oscillation
        }
    }

    func setOptionalMode(_ optionalMode: String) {
        send(DeviceCommand(capability: "custom.airConditionerOptionalMode", command: "setAcOptionalMode", arguments: [.string(optionalMode)])) {
            $0.optionalMode = optionalMode
        }
    }

    func setAutoClean(_ on: Bool) {
        send(DeviceCommand(capability: "custom.autoCleaningMode", command: "setAutoCleaningMode", arguments: [.string(on ? "on" : "off")])) {
            $0.autoClean = on
        }
    }

    func isDisplayLightOn(_ deviceID: String) -> Bool { displayLight[deviceID] ?? true }

    // samsungce.airConditionerLighting is disabled on these models, so we use the OCF command.
    // It works the other way around: "Light_On" turns the display off.
    func setDisplayLight(_ on: Bool) {
        guard let id = selectedDevice?.id else { return }
        displayLight[id] = on
        let option = JSONValue.string(on ? "Light_Off" : "Light_On")
        let command = DeviceCommand(capability: "execute", command: "execute", arguments: [
            .string("mode/vs/0"),
            .object(["x.com.samsung.da.options": .array([option])]),
        ])
        Task { await perform([command], on: id) }
    }

    // Wait until the user stops moving the slider, then send one command.
    func setSetpoint(_ value: Int) {
        guard let id = selectedDevice?.id, var state = states[id] else { return }
        let clamped = min(max(value, state.minSetpoint), state.maxSetpoint)
        guard clamped != state.setpoint else { return }
        state.setpoint = clamped
        states[id] = state

        setpointTask?.cancel()
        setpointTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await perform([DeviceCommand(capability: "thermostatCoolingSetpoint", command: "setCoolingSetpoint", arguments: [.number(Double(clamped))])], on: id)
        }
    }

    private func send(_ command: DeviceCommand, optimistic update: (inout ACState) -> Void) {
        guard let id = selectedDevice?.id, var state = states[id] else { return }
        update(&state)
        states[id] = state
        Task { await perform([command], on: id) }
    }

    private func perform(_ commands: [DeviceCommand], on id: String) async {
        guard !isDemo else { return }
        activity = .sending
        do {
            try await client.send(commands, to: id)
            activity = .idle
        } catch {
            activity = .failed(error.localizedDescription)
        }
        followUpRefresh?.cancel()
        followUpRefresh = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? await client.requestReport(from: id)
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if let state = try? await client.state(of: id) { states[id] = state }
        }
    }
}
