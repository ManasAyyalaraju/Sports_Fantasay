//
//  FontDebugHelper.swift
//  Sport_Tracker-Fantasy
//
//  Debug helper to list all available fonts
//

import UIKit

struct FontDebugHelper {
    static func printAllFonts() {
        print("=== ALL AVAILABLE FONTS ===")
        for family in UIFont.familyNames.sorted() {
            print("\nFamily: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
    }
    
    static func findFont(containing: String) {
        print("\n=== SEARCHING FOR FONTS CONTAINING '\(containing)' ===")
        for family in UIFont.familyNames.sorted() {
            if family.localizedCaseInsensitiveContains(containing) {
                print("Found family: \(family)")
                for name in UIFont.fontNames(forFamilyName: family) {
                    print("  - \(name)")
                }
            }
            for name in UIFont.fontNames(forFamilyName: family) {
                if name.localizedCaseInsensitiveContains(containing) {
                    print("Found font: \(name) (in family: \(family))")
                }
            }
        }
    }
}
