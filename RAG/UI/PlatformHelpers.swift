//
//  ContentView.swift
//  RAG
//
//  Created by Eric Collom on 12/8/25.
//

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import SwiftUI

// MARK: - Platform-specific color helpers
var systemBackground: Color {
    #if canImport(UIKit)
    return Color(UIColor.systemBackground)
    #elseif canImport(AppKit)
    return Color(NSColor.controlBackgroundColor)
    #else
    return Color.white
    #endif
}

var systemGray6: Color {
    #if canImport(UIKit)
    return Color(UIColor.systemGray6)
    #elseif canImport(AppKit)
    return Color(NSColor.controlColor)
    #else
    return Color.gray.opacity(0.1)
    #endif
}

// MARK: - Platform-specific pasteboard utilities
func copyToPasteboard(_ text: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = text
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #else
    // No-op for unsupported platforms
    #endif
}
