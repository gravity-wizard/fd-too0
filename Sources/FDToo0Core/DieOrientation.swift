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

    /// Canonical Western Right-Handed Casino Die (RH000) orientation for any desired top pip (1...6):
    /// - Opposite faces sum to 7 (1-6, 2-5, 3-4).
    /// - Right-handed chirality ("Look for the V"): with 1 on Top, 2 on South (front-left) and 3 on East (front-right),
    ///   1 -> 2 -> 3 runs counter-clockwise around their shared vertex.
    /// - Pip 6 yaw=0 has 3 & 4 at North/South (vertical ⋮⋮ rails pointing toward 3 & 4);
    ///   yaw=1 has 3 & 4 at East/West (horizontal ⋯ rails pointing toward 3 & 4).
    public static func canonical(topPip: Int, yawSteps: Int = 0) -> DieOrientation {
        let base: DieOrientation
        switch ((topPip - 1) % 6 + 6) % 6 + 1 {
        case 1: base = DieOrientation(top: 1, north: 5, east: 3)
        case 2: base = DieOrientation(top: 2, north: 4, east: 1)
        case 3: base = DieOrientation(top: 3, north: 1, east: 5)
        case 4: base = DieOrientation(top: 4, north: 5, east: 1)
        case 5: base = DieOrientation(top: 5, north: 6, east: 3)
        default: base = DieOrientation(top: 6, north: 3, east: 5)
        }
        var rotated = base
        let turns = ((yawSteps % 4) + 4) % 4
        for _ in 0..<turns {
            rotated = rotated.spunClockwise()
        }
        return rotated
    }

    /// Projects the rigid 3D engraved pips of a physical Western Casino Die (RH000)
    /// onto the Top face's 3×3 slot grid (0...8).
    public var topFacePipSlots: Set<Int> {
        switch top {
        case 1: return [4]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        default: break
        }

        var normals: [Int: (Int, Int, Int)] = [:]
        normals[top] = (0, 0, 1)
        normals[bottom] = (0, 0, -1)
        normals[north] = (0, -1, 0)
        normals[south] = (0, 1, 0)
        normals[east] = (1, 0, 0)
        normals[west] = (-1, 0, 0)

        func toTopSlot(_ dx: Int, _ dy: Int) -> Int {
            (dy + 1) * 3 + (dx + 1)
        }

        guard let n1 = normals[1], let n2 = normals[2], let n3 = normals[3] else {
            return [0, 2, 3, 5, 6, 8]
        }
        let n4 = (-n3.0, -n3.1, -n3.2)
        let n5 = (-n2.0, -n2.1, -n2.2)
        let n6 = (-n1.0, -n1.1, -n1.2)

        if top == 2 {
            return [
                toTopSlot(n1.0 + n4.0, n1.1 + n4.1),
                toTopSlot(n6.0 + n3.0, n6.1 + n3.1)
            ]
        }
        if top == 3 {
            return [
                toTopSlot(n6.0 + n2.0, n6.1 + n2.1),
                4,
                toTopSlot(n1.0 + n5.0, n1.1 + n5.1)
            ]
        }
        // top == 6: 4 corners + 2 middle pips on 2 & 5 edges so the two 3-pip rails point toward 3 & 4!
        return [
            0, 2, 6, 8,
            toTopSlot(n2.0, n2.1),
            toTopSlot(n5.0, n5.1)
        ]
    }

    public var sixRailsVertical: Bool? {
        guard top == 6 else { return nil }
        return topFacePipSlots.contains(3)
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
