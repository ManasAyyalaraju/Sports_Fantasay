//
//  FontHelper.swift
//  Sport_Tracker-Fantasy
//
//  Custom font helper for Clash Display and Instrument Sans.
//

import SwiftUI
import UIKit
import CoreText

extension Font {
    /// Clash Display Variable font
    static func clashDisplay(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Register font if not already registered
        FontHelper.registerFontIfNeeded(name: "ClashDisplay-Variable", fileExtension: "ttf")
        
        // Try multiple possible font names
        let possibleNames = [
            "ClashDisplayVariable-Regular",
            "Clash Display Variable",
            "ClashDisplay-Variable",
            "ClashDisplayVariable"
        ]
        
        for name in possibleNames {
            if let font = UIFont(name: name, size: size) {
                return Font(font)
            }
        }
        
        // Debug: Print available fonts on first call
        #if DEBUG
        if !UserDefaults.standard.bool(forKey: "fontsDebugged") {
            FontHelper.debugFonts()
            UserDefaults.standard.set(true, forKey: "fontsDebugged")
        }
        #endif
        
        // Fallback to system font
        return .system(size: size, weight: weight)
    }
    
    /// Instrument Sans font
    static func instrumentSans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Register font if not already registered
        FontHelper.registerFontIfNeeded(name: "InstrumentSans", fileExtension: "ttf")
        
        // Try multiple possible font names
        let possibleNames = [
            "Instrument Sans",
            "InstrumentSans-Regular",
            "InstrumentSans",
            "Instrument Sans Regular"
        ]
        
        for name in possibleNames {
            if let font = UIFont(name: name, size: size) {
                return Font(font)
            }
        }
        
        // Fallback to system font
        return .system(size: size, weight: weight)
    }
}

struct FontHelper {
    private static var registeredFonts: Set<String> = []
    
    /// Register a font from the bundle if not already registered
    static func registerFontIfNeeded(name: String, fileExtension: String) {
        let fontKey = "\(name).\(fileExtension)"
        guard !registeredFonts.contains(fontKey) else { return }
        
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Fonts") else {
            #if DEBUG
            print("⚠️ Font not found in bundle: \(fontKey)")
            #endif
            return
        }
        
        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
            #if DEBUG
            print("⚠️ Could not create data provider for: \(fontKey)")
            #endif
            return
        }
        
        guard let font = CGFont(fontDataProvider) else {
            #if DEBUG
            print("⚠️ Could not create font from: \(fontKey)")
            #endif
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            registeredFonts.insert(fontKey)
            #if DEBUG
            print("✅ Successfully registered font: \(fontKey)")
            #endif
        } else {
            #if DEBUG
            if let error = error?.takeRetainedValue() {
                print("⚠️ Failed to register font \(fontKey): \(error)")
            }
            #endif
        }
    }
    
    static func debugFonts() {
        print("🔍 DEBUGGING FONTS...")
        print("\n=== Searching for Clash Display ===")
        var foundClash = false
        for family in UIFont.familyNames.sorted() {
            if family.localizedCaseInsensitiveContains("clash") {
                foundClash = true
                print("✅ Found family: \(family)")
                for name in UIFont.fontNames(forFamilyName: family) {
                    print("   - \(name)")
                }
            }
        }
        if !foundClash {
            print("❌ Clash Display font NOT FOUND")
        }
        
        print("\n=== Searching for Instrument Sans ===")
        var foundInstrument = false
        for family in UIFont.familyNames.sorted() {
            if family.localizedCaseInsensitiveContains("instrument") {
                foundInstrument = true
                print("✅ Found family: \(family)")
                for name in UIFont.fontNames(forFamilyName: family) {
                    print("   - \(name)")
                }
            }
        }
        if !foundInstrument {
            print("❌ Instrument Sans font NOT FOUND")
        }
        
        print("\n=== All custom fonts ===")
        let systemFonts = Set(["Helvetica", "Times", "Courier", "Arial", "Georgia", "Verdana", "Trebuchet MS", "Palatino", "Optima", "Menlo", "Monaco", "Courier New", "Helvetica Neue", "Avenir", "Avenir Next", "Didot", "American Typewriter", "Baskerville", "Geneva", "Gill Sans", "San Francisco", "SF Pro", "SF Pro Display", "SF Pro Text", "SF Mono", "New York"])
        
        var customCount = 0
        for family in UIFont.familyNames.sorted() {
            if !systemFonts.contains(family) {
                customCount += 1
                print("📦 Custom family: \(family)")
                for name in UIFont.fontNames(forFamilyName: family) {
                    print("   - \(name)")
                }
            }
        }
        if customCount == 0 {
            print("❌ No custom fonts found!")
        }
        
        print("\n=== Checking font files in bundle ===")
        if let fontPaths = Bundle.main.paths(forResourcesOfType: "ttf", inDirectory: "Fonts") {
            print("Found \(fontPaths.count) TTF files:")
            for path in fontPaths {
                print("   - \(path)")
            }
        } else {
            print("❌ No TTF files found in Fonts directory")
        }
    }
}
