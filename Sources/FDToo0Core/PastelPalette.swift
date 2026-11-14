//
//  PastelPalette.swift
//  FD_too0
//
//  Curated Pastel HSB Dice & Surface Theme Tokens for Dark Mode, Light Mode & Spruce WoodGrain.
//

import Foundation

/// Visual appearance modes supporting system-automatic, explicit Dark, explicit Light, and akapps Spruce Wood.
public enum BoardAppearanceMode: String, CaseIterable, Codable, Sendable {
    case dark     = "dark"
    case light    = "light"
    case spruce   = "spruce"

    public var displayName: String {
        switch self {
        case .dark:   return "Obsidian Dark"
        case .light:  return "Birch Light"
        case .spruce: return "Spruce Wood"
        }
    }
}

/// Six harmonious Pastel HSB die body families (strictly zero harsh purple on dark!).
public enum PastelHueFamily: Int, CaseIterable, Codable, Sendable {
    case coralBlush      = 1
    case apricotPeach    = 2
    case buttercreamSun  = 3
    case mintSage        = 4
    case glacierSky      = 5
    case roseQuartz      = 6

    public var title: String {
        switch self {
        case .coralBlush:     return "Coral Blush"
        case .apricotPeach:   return "Apricot Peach"
        case .buttercreamSun: return "Buttercream Gold"
        case .mintSage:       return "Mint Sage"
        case .glacierSky:     return "Glacier Sky"
        case .roseQuartz:     return "Rose Quartz"
        }
    }

    /// RGB (0...1) fill & pip contrast values calibrated independently for Dark and Light/Wood surfaces.
    public func rgbTokens(for mode: BoardAppearanceMode) -> PastelDieRGB {
        switch (self, mode) {
        // DARK MODE: Luminous matte-porcelain pastels over deep walnut-obsidian tray, deep espresso recessed pips
        case (.coralBlush, .dark):
            return PastelDieRGB(body: (0.95, 0.67, 0.63), bevel: (0.99, 0.80, 0.77), shadow: (0.69, 0.41, 0.38), pip: (0.17, 0.10, 0.09))
        case (.apricotPeach, .dark):
            return PastelDieRGB(body: (0.96, 0.76, 0.58), bevel: (1.00, 0.86, 0.73), shadow: (0.72, 0.50, 0.33), pip: (0.18, 0.11, 0.07))
        case (.buttercreamSun, .dark):
            return PastelDieRGB(body: (0.95, 0.87, 0.59), bevel: (0.99, 0.94, 0.75), shadow: (0.71, 0.61, 0.33), pip: (0.17, 0.14, 0.06))
        case (.mintSage, .dark):
            return PastelDieRGB(body: (0.68, 0.88, 0.78), bevel: (0.82, 0.95, 0.88), shadow: (0.42, 0.64, 0.53), pip: (0.08, 0.17, 0.13))
        case (.glacierSky, .dark):
            return PastelDieRGB(body: (0.67, 0.84, 0.94), bevel: (0.82, 0.92, 0.98), shadow: (0.41, 0.59, 0.71), pip: (0.08, 0.15, 0.21))
        case (.roseQuartz, .dark):
            return PastelDieRGB(body: (0.93, 0.70, 0.78), bevel: (0.98, 0.83, 0.88), shadow: (0.67, 0.43, 0.52), pip: (0.19, 0.09, 0.13))

        // LIGHT & SPRUCE MODES: Richer ceramic pastels over warm alabaster/birch or spruce wood grain
        case (.coralBlush, .light), (.coralBlush, .spruce):
            return PastelDieRGB(body: (0.96, 0.72, 0.68), bevel: (1.00, 0.86, 0.83), shadow: (0.76, 0.48, 0.44), pip: (0.20, 0.11, 0.10))
        case (.apricotPeach, .light), (.apricotPeach, .spruce):
            return PastelDieRGB(body: (0.97, 0.80, 0.63), bevel: (1.00, 0.90, 0.79), shadow: (0.78, 0.56, 0.38), pip: (0.21, 0.13, 0.08))
        case (.buttercreamSun, .light), (.buttercreamSun, .spruce):
            return PastelDieRGB(body: (0.96, 0.89, 0.64), bevel: (1.00, 0.96, 0.81), shadow: (0.76, 0.67, 0.38), pip: (0.20, 0.16, 0.07))
        case (.mintSage, .light), (.mintSage, .spruce):
            return PastelDieRGB(body: (0.71, 0.90, 0.80), bevel: (0.86, 0.97, 0.91), shadow: (0.46, 0.68, 0.57), pip: (0.09, 0.19, 0.14))
        case (.glacierSky, .light), (.glacierSky, .spruce):
            return PastelDieRGB(body: (0.70, 0.86, 0.96), bevel: (0.85, 0.94, 1.00), shadow: (0.45, 0.63, 0.76), pip: (0.09, 0.16, 0.23))
        case (.roseQuartz, .light), (.roseQuartz, .spruce):
            return PastelDieRGB(body: (0.95, 0.74, 0.81), bevel: (0.99, 0.87, 0.91), shadow: (0.73, 0.49, 0.57), pip: (0.21, 0.10, 0.15))
        }
    }
}

public struct PastelDieRGB: Sendable {
    public let body: (Double, Double, Double)
    public let bevel: (Double, Double, Double)
    public let shadow: (Double, Double, Double)
    public let pip: (Double, Double, Double)
}
