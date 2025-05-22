//
//  IconSource.swift
//  Mariner Studio
//
//  Shared enum for handling both SF Symbols and custom images across the app
//

import SwiftUI

/// Enum to define how icons should be displayed throughout the app
/// Supports both SF Symbols and custom images from the asset catalog
enum IconSource {
    case system(String, Color? = nil)  // SF Symbol with name and optional color
    case custom(String, Color? = nil)  // Custom image from asset catalog with name and optional color
}
