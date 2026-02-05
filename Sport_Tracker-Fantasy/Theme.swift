//
//  Theme.swift
//  Sport_Tracker-Fantasy
//
//  Shared color and style constants for the NBA Fantasy app.
//

import SwiftUI

struct AppColors {
    // Primary colors
    static let primary = Color(hex: "FF6B35")
    static let secondary = Color(hex: "F7931E")
    
    // Background colors
    static let background = Color(hex: "0A0A0A")
    static let cardBackground = Color(hex: "1C1C1E")
    static let elevatedBackground = Color(hex: "2C2C2E")
    
    // Text colors
    static let text = Color.white
    static let secondaryText = Color(hex: "8E8E93")
    static let tertiaryText = Color(hex: "3A3A3C")
    
    // Accent colors
    static let accent = Color(hex: "FF6B35")
    static let gold = Color(hex: "FFD700")
    
    // Gradient
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
        startPoint: .leading,
        endPoint: .trailing
    )
}
