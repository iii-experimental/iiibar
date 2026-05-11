import SwiftUI

enum BrandColors {
    static let black = Color(hex: "#000000")
    static let dark = Color(hex: "#1d1d1d")
    static let medium = Color(hex: "#848484")
    static let light = Color(hex: "#f4f4f4")
    static let accent = Color(hex: "#f3f724")
    static let accentLight = Color(hex: "#2f7fff")
    static let info = Color(hex: "#42e7e7")
    static let warn = Color(hex: "#f3943d")
    static let alert = Color(hex: "#e52e61")
    static let success = Color(hex: "#1ce669")
}

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

func statusColor(_ state: String) -> Color {
    switch state {
    case "healthy", "running":
        return BrandColors.success
    case "degraded", "warning":
        return BrandColors.warn
    case "unreachable", "stopped", "error":
        return BrandColors.alert
    default:
        return BrandColors.medium
    }
}
