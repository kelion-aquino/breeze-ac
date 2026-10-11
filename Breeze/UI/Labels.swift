import SwiftUI

enum Labels {
    static func mode(_ value: String) -> String {
        switch value {
        case "auto": String(localized: "Auto")
        case "cool": String(localized: "Cool")
        case "dry": String(localized: "Dry")
        case "wind": String(localized: "Fan only")
        case "heat": String(localized: "Heat")
        default: value.capitalized
        }
    }

    static func modeIcon(_ value: String) -> String {
        switch value {
        case "auto": "arrow.triangle.2.circlepath"
        case "cool": "snowflake"
        case "dry": "drop"
        case "wind": "wind"
        case "heat": "sun.max"
        default: "questionmark"
        }
    }

    static func fan(_ value: String) -> String {
        switch value {
        case "auto": String(localized: "Auto")
        case "low": String(localized: "Low")
        case "medium": String(localized: "Medium")
        case "high": String(localized: "High")
        case "turbo": String(localized: "Turbo")
        default: value.capitalized
        }
    }

    static func fanIcon(_ value: String) -> String {
        switch value {
        case "auto": "fan"
        case "turbo": "hurricane"
        default: "fan.fill"
        }
    }

    static func oscillation(_ value: String) -> String {
        switch value {
        case "fixed": String(localized: "Fixed")
        case "vertical": String(localized: "Vertical")
        case "horizontal": String(localized: "Horizontal")
        case "all": String(localized: "All")
        default: value.capitalized
        }
    }

    static func oscillationIcon(_ value: String) -> String {
        switch value {
        case "vertical": "arrow.up.and.down"
        case "horizontal": "arrow.left.and.right"
        case "all": "arrow.up.and.down.and.arrow.left.and.right"
        default: "pause"
        }
    }

    static func optionalMode(_ value: String) -> String {
        switch value {
        case "off": String(localized: "None")
        case "sleep": String(localized: "Sleep")
        case "quiet": String(localized: "Quiet")
        case "smart": String(localized: "Smart")
        case "speed": String(localized: "Speed")
        case "windFree": String(localized: "WindFree")
        case "windFreeSleep": String(localized: "WindFree Sleep")
        default: value.capitalized
        }
    }

    static func optionalModeIcon(_ value: String) -> String {
        switch value {
        case "sleep", "windFreeSleep": "moon.zzz"
        case "quiet": "speaker.wave.1"
        case "smart": "sparkles"
        case "speed": "bolt"
        case "windFree": "aqi.low"
        default: "circle.slash"
        }
    }

    static func accent(mode: String, isOn: Bool) -> Color {
        guard isOn else { return .secondary }
        return switch mode {
        case "heat": .orange
        case "dry": .teal
        case "wind": .mint
        case "auto": .green
        default: .cyan
        }
    }
}
