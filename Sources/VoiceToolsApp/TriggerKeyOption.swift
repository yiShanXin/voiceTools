import Foundation

enum TriggerKeyOption: String, CaseIterable {
    case fnOnly = "fnOnly"
    case fnOrRightCommand = "fnOrRightCommand"
    case rightCommandOnly = "rightCommandOnly"

    var menuTitle: String {
        switch self {
        case .fnOnly:
            return "Fn"
        case .fnOrRightCommand:
            return "Fn or Right Command"
        case .rightCommandOnly:
            return "Right Command"
        }
    }

    var hintTitle: String {
        switch self {
        case .fnOnly:
            return "Hold Fn to Talk"
        case .fnOrRightCommand:
            return "Hold Fn/Right Command to Talk"
        case .rightCommandOnly:
            return "Hold Right Command to Talk"
        }
    }

    var includesFn: Bool {
        self == .fnOnly || self == .fnOrRightCommand
    }

    var includesRightCommand: Bool {
        self == .rightCommandOnly || self == .fnOrRightCommand
    }
}
