//
//  Theme.swift
//  Sport_Tracker-Fantasy
//
//  Shared color and style constants for the NBA Fantasy app.
//

import SwiftUI

struct AppColors {
    // Primary colors (flipped: blue primary, teal secondary)
    static let primary = Color(hex: "0073EF")
    static let secondary = Color(hex: "00EFEB")
    
    // Background colors
    static let background = Color(hex: "0A0A0A")
    static let cardBackground = Color(hex: "1C1C1E")
    static let elevatedBackground = Color(hex: "2C2C2E")
    
    // Text colors
    static let text = Color.white
    static let secondaryText = Color(hex: "8E8E93")
    static let tertiaryText = Color(hex: "3A3A3C")
    
    // Accent colors (white)
    static let accent = Color.white
    static let gold = Color(hex: "FFD700")
    
    // Gradient (primary then secondary)
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "0073EF"), Color(hex: "00EFEB")],
        startPoint: .leading,
        endPoint: .trailing
    )
}
