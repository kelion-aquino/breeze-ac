import Foundation

nonisolated struct ACDevice: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
}

// See docs/SMARTTHINGS.md for the capability mapping.
nonisolated struct ACState: Equatable, Sendable {
    var isOn = false
    var mode = "cool"
    var supportedModes: [String] = ["auto", "cool", "dry", "wind"]
    var fanMode = "auto"
    var supportedFanModes: [String] = ["auto", "low", "medium", "high", "turbo"]
    // Subset allowed in the current mode.
    var availableFanModes: [String] = ["auto", "low", "medium", "high", "turbo"]
    var oscillation = "fixed"
    var supportedOscillations: [String] = ["fixed", "vertical", "horizontal", "all"]
    var optionalMode = "off"
    var supportedOptionalModes: [String] = ["off", "sleep", "quiet", "smart", "speed", "windFree", "windFreeSleep"]
    var setpoint = 24
    var minSetpoint = 16
    var maxSetpoint = 30
    var roomTemperature: Double?
    var humidity: Double?
    var autoClean: Bool?
    var filterNeedsCleaning = false
    var filterUsage: Int?

    var isWindFree: Bool { optionalMode == "windFree" || optionalMode == "windFreeSleep" }
    var supportsWindFree: Bool { supportedOptionalModes.contains("windFree") }

    init() {}

    init(status: [String: JSONValue]) {
        func value(_ capability: String, _ attribute: String) -> JSONValue? {
            status[capability]?[attribute]?["value"]
        }
        func list(_ capability: String, _ attribute: String, fallback: [String]) -> [String] {
            let items = value(capability, attribute)?.strings ?? []
            return items.isEmpty ? fallback : items
        }

        isOn = value("switch", "switch")?.string == "on"
        mode = value("airConditionerMode", "airConditionerMode")?.string ?? mode
        supportedModes = list("airConditionerMode", "supportedAcModes", fallback: supportedModes)
        fanMode = value("airConditionerFanMode", "fanMode")?.string ?? fanMode
        supportedFanModes = list("airConditionerFanMode", "supportedAcFanModes", fallback: supportedFanModes)
        availableFanModes = list("airConditionerFanMode", "availableAcFanModes", fallback: supportedFanModes)
        oscillation = value("fanOscillationMode", "fanOscillationMode")?.string ?? oscillation
        supportedOscillations = list("fanOscillationMode", "supportedFanOscillationModes", fallback: supportedOscillations)
        optionalMode = value("custom.airConditionerOptionalMode", "acOptionalMode")?.string ?? optionalMode
        supportedOptionalModes = list("custom.airConditionerOptionalMode", "supportedAcOptionalMode", fallback: supportedOptionalModes)

        if let setpoint = value("thermostatCoolingSetpoint", "coolingSetpoint")?.double {
            self.setpoint = Int(setpoint.rounded())
        }
        if let range = value("thermostatCoolingSetpoint", "coolingSetpointRange") {
            minSetpoint = range["minimum"]?.double.map { Int($0) } ?? minSetpoint
            maxSetpoint = range["maximum"]?.double.map { Int($0) } ?? maxSetpoint
        }

        roomTemperature = value("temperatureMeasurement", "temperature")?.double
        humidity = value("relativeHumidityMeasurement", "humidity")?.double
        autoClean = value("custom.autoCleaningMode", "autoCleaningMode")?.string.map { $0 == "on" }
        filterNeedsCleaning = value("custom.dustFilter", "dustFilterStatus")?.string == "wash"
        filterUsage = value("custom.dustFilter", "dustFilterUsage")?.double.map { Int($0) }
    }
}

extension ACState {
    static let demo: [(device: ACDevice, state: ACState)] = {
        var office = ACState()
        office.isOn = true
        office.mode = "cool"
        office.supportedModes.append("heat")
        office.setpoint = 21
        office.roomTemperature = 23
        office.humidity = 42
        office.optionalMode = "windFree"
        office.oscillation = "vertical"
        office.autoClean = true
        office.filterNeedsCleaning = true
        office.filterUsage = 100

        var bedroom = ACState()
        bedroom.roomTemperature = 26
        bedroom.humidity = 51

        return [
            (ACDevice(id: "demo-office", label: "Living room"), office),
            (ACDevice(id: "demo-bedroom", label: "Bedroom"), bedroom),
        ]
    }()
}
