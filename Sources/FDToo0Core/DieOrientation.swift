//
//  DieOrientation.swift
//  FD_too0 (Flipping Dice Classic + FD_too0 1,023-Level Evolution)
//
//  Honoring Game_23.swift & Die_qx.swift (G / akapps, 2019–2026)
//  Exact 24-state SO(3) physical 6-face die rotation group where opposite faces ALWAYS sum to 7.
//

import Foundation

/// Cardinal tumble directions matching ULDR from legacy Game_23.swift.
public enum TumbleDirection: String, CaseIterable, Codable, Sendable {
    case north = "N"
    case east  = "E"
    case south = "S"
    case west  = "W"

    public var opposite: TumbleDirection {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east:  return .west
        case .west:  return .east
        }
    }

    public var rowDelta: Int {
        switch self {
        case .north: return -1
        case .south: return 1
        case .east, .west: return 0
        }
    }

    public var colDelta: Int {
        switch self {
        case .east:  return 1
        case .west:  return -1
        case .north, .south: return 0
        }
    }

    public var arrowGlyph: String {
        switch self {
        case .north: return "↑"
        case .east:  return "→"
        case .south: return "↓"
        case .west:  return "←"
        }
    }
}

/// Exact 3D orientation of a standard 6-face pip die where opposite faces always sum to 7:
/// `top + bottom == 7`, `north + south == 7`, `east + west == 7`.
public struct DieOrientation: Equatable, Hashable, Codable, Sendable {
    public var top: Int
    public var north: Int
    public var east: Int

    public var bottom: Int { 7 - top }
    public var south: Int  { 7 - north }
    public var west: Int   { 7 - east }

    public init(top: Int = 1, north: Int = 2, east: Int = 3) {
        precondition((1...6).contains(top) && (1...6).contains(north) && (1...6).contains(east))
        precondition(top != north && top + north != 7 && top != east && top + east != 7 && north != east && north + east != 7)
        self.top = top
        self.north = north
        self.east = east
    }

    /// Canonical upright orientation for any desired top pip (1...6).
    public static func canonical(topPip: Int, yawSteps: Int = 0) -> DieOrientation {
        let base: DieOrientation
        switch ((topPip - 1) % 6 + 6) % 6 + 1 {
        case 1: base = DieOrientation(top: 1, north: 2, east: 3)
        case 2: base = DieOrientation(top: 2, north: 6, east: 3)
        case 3: base = DieOrientation(top: 3, north: 2, east: 6)
        case 4: base = DieOrientation(top: 4, north: 2, east: 1)
        case 5: base = DieOrientation(top: 5, north: 1, east: 3)
        default: base = DieOrientation(top: 6, north: 5, east: 3)
        }
        var rotated = base
        let turns = ((yawSteps % 4) + 4) % 4
        for _ in 0..<turns {
            rotated = rotated.spunClockwise()
        }
        return rotated
    }

    /// 90-degree physical tumble in a cardinal direction across the board tray.
    /// - Tipping North: Top rolls onto North; South (7 - north) rolls up onto Top.
    /// - Tipping South: North rolls onto Top; Top rolls onto South.
    /// - Tipping East:  West (7 - east) rolls onto Top; Top rolls onto East.
    /// - Tipping West:  East rolls onto Top; Top rolls onto West.
    public func tipped(_ direction: TumbleDirection) -> DieOrientation {
        switch direction {
        case .north:
            return DieOrientation(top: 7 - north, north: top, east: east)
        case .south:
            return DieOrientation(top: north, north: 7 - top, east: east)
        case .east:
            return DieOrientation(top: 7 - east, north: north, east: top)
        case .west:
            return DieOrientation(top: east, north: north, east: 7 - top)
        }
    }

    /// 180-degree Twist (`twistDice` heritage from Game_23.swift) — flips `top` to `7 - top` while preserving parity.
    public func twisted180() -> DieOrientation {
        // Equivalent to two consecutive 90° tips north (or east + yaw): swaps top <-> bottom and east <-> west
        return DieOrientation(top: 7 - top, north: north, east: 7 - east)
    }

    /// 90-degree clockwise yaw spin on the flat tray without changing the top pip.
    public func spunClockwise() -> DieOrientation {
        return DieOrientation(top: top, north: 7 - east, east: north)
    }

    /// Preview what pip will land on Top if the player swipes in `direction`.
    public func nextTopPip(whenTipped direction: TumbleDirection) -> Int {
        tipped(direction).top
    }

    /// Validates the opposite-faces-sum-to-7 invariant.
    public var hasValidSumSevenInvariant: Bool {
        let faces = Set([top, bottom, north, south, east, west])
        return faces == Set(1...6)
            && (top + bottom == 7)
            && (north + south == 7)
            && (east + west == 7)
    }
}
