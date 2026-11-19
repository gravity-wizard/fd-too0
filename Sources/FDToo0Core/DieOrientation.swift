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

    /// 120-degree corner-vertex rotation around the front-upper-right `[East, Top, South]` body diagonal!
    /// Cycles the 3 camera-visible faces (`East → Top → South → East`) — proving 3D dice rotate around
    /// corner diagonals as well as face axles (`spunCorner120()^3 == identity`).
    public func spunCorner120() -> DieOrientation {
        return DieOrientation(top: east, north: 7 - top, east: 7 - north)
    }

    /// Inverse 240-degree (`-120°`) corner-vertex rotation (`South → Top → East → South`).
    public func spunCorner240() -> DieOrientation {
        return spunCorner120().spunCorner120()
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

// MARK: - Cross-Platform 3D Math, Axle-Lock Skewers & Visual Skins (A785 Spatial Core)

/// Visual skin applied to every 3D die across Flipping Dice, AxLe Yahtzee, HoLy SmoLLey, and M00N Buggy.
public enum DieVisualSkin: String, CaseIterable, Codable, Sendable, Identifiable {
    case modeledPips       = "pips"
    case twisted45Numerals = "twisted45"
    case royalFaceCards    = "faceCards"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .modeledPips:       return "RH000 Pips"
        case .twisted45Numerals: return "45° Twist"
        case .royalFaceCards:    return "FaceCards"
        }
    }

    public var badgeGlyph: String {
        switch self {
        case .modeledPips:       return "🎲"
        case .twisted45Numerals: return "◇45°"
        case .royalFaceCards:    return "🃏J"
        }
    }
}

/// Camera projection toggle honoring Twisted23's 3D-in-2D orthographic view, 3D perspective, and classic 2D Dice Trainer.
public enum CameraProjectionStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case orthographic3DIn2D = "ortho3d"
    case perspective3D      = "persp3d"
    case flat2D             = "flat2d"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .orthographic3DIn2D: return "3D Ortho"
        case .perspective3D:      return "3D Persp"
        case .flat2D:             return "2D Trainer"
        }
    }
}

/// Optional Sum-7 skewer pinning two opposite faces so the die rotates strictly around its 4-face ring.
public enum AxleLockAxis: String, CaseIterable, Codable, Sendable, Identifiable {
    case free24 = "free24"
    case pin16  = "pin16"
    case pin25  = "pin25"
    case pin34  = "pin34"

    public var id: String { rawValue }

    public var displayTitle: String {
        switch self {
        case .free24: return "Unlocked (24-State)"
        case .pin16:  return "AxLe [1–6] → {2,3,5,4}"
        case .pin25:  return "AxLe [2–5] → {1,3,6,4}"
        case .pin34:  return "AxLe [3–4] → {1,2,6,5}"
        }
    }

    public var shortTag: String {
        switch self {
        case .free24: return "Free-24"
        case .pin16:  return "AxLe [1-6]"
        case .pin25:  return "AxLe [2-5]"
        case .pin34:  return "AxLe [3-4]"
        }
    }

    public var pinnedPair: (Int, Int)? {
        switch self {
        case .free24: return nil
        case .pin16:  return (1, 6)
        case .pin25:  return (2, 5)
        case .pin34:  return (3, 4)
        }
    }

    /// Returns the 4 faces on the active rolling ring when locked, or all 6 faces when unlocked.
    public var rollableFaces: [Int] {
        switch self {
        case .free24: return [1, 2, 3, 4, 5, 6]
        case .pin16:  return [2, 3, 5, 4]
        case .pin25:  return [1, 3, 6, 4]
        case .pin34:  return [1, 2, 6, 5]
        }
    }

    public var nextCycled: AxleLockAxis {
        let all = Self.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

/// Lightweight Sendable 3D vector (+X = East, +Y = Top, +Z = South, -Z = North).
public struct Vec3: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var length: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public var normalized: Vec3 {
        let len = length
        guard len > 1e-9 else { return Vec3(0, 1, 0) }
        return Vec3(x / len, y / len, z / len)
    }

    public func dot(_ other: Vec3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: Vec3) -> Vec3 {
        Vec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    public static func + (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    public static func - (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    public static func * (lhs: Vec3, rhs: Double) -> Vec3 {
        Vec3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}

/// Unit quaternion representing exact SO(3) 3D die rotations for SceneKit / Metal.
public struct Quat: Equatable, Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public static let identity = Quat(x: 0, y: 0, z: 0, w: 1)

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public var normalized: Quat {
        let len = (x * x + y * y + z * z + w * w).squareRoot()
        guard len > 1e-9 else { return .identity }
        return Quat(x: x / len, y: y / len, z: z / len, w: w / len)
    }

    public static func axisAngle(axis: Vec3, radians: Double) -> Quat {
        let n = axis.normalized
        let half = radians * 0.5
        let s = sin(half)
        return Quat(x: n.x * s, y: n.y * s, z: n.z * s, w: cos(half)).normalized
    }

    public static func * (a: Quat, b: Quat) -> Quat {
        Quat(
            x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
            w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
        ).normalized
    }

    public func rotate(_ v: Vec3) -> Vec3 {
        let qv = Quat(x: v.x, y: v.y, z: v.z, w: 0)
        let conj = Quat(x: -x, y: -y, z: -z, w: w)
        let r = self * qv * conj
        return Vec3(r.x, r.y, r.z)
    }

    public static func slerp(_ q0: Quat, _ q1: Quat, t: Double) -> Quat {
        let clamped = max(0.0, min(1.0, t))
        var dot = q0.x * q1.x + q0.y * q1.y + q0.z * q1.z + q0.w * q1.w
        var end = q1
        if dot < 0 {
            dot = -dot
            end = Quat(x: -q1.x, y: -q1.y, z: -q1.z, w: -q1.w)
        }
        if dot > 0.9995 {
            return Quat(
                x: q0.x + clamped * (end.x - q0.x),
                y: q0.y + clamped * (end.y - q0.y),
                z: q0.z + clamped * (end.z - q0.z),
                w: q0.w + clamped * (end.w - q0.w)
            ).normalized
        }
        let theta0 = acos(dot)
        let theta = theta0 * clamped
        let sinTheta = sin(theta)
        let sinTheta0 = sin(theta0)
        let s0 = cos(theta) - dot * sinTheta / sinTheta0
        let s1 = sinTheta / sinTheta0
        return Quat(
            x: s0 * q0.x + s1 * end.x,
            y: s0 * q0.y + s1 * end.y,
            z: s0 * q0.z + s1 * end.z,
            w: s0 * q0.w + s1 * end.w
        ).normalized
    }
}

extension DieOrientation {
    /// Compact two-digit Twisted23 Top-Front (`TF`) coordinate (`top * 10 + south`).
    public var tfCode: Int {
        top * 10 + south
    }

    /// World-space unit normal (+X=East, +Y=Top, +Z=South, -Z=North) for any pip `1...6`.
    public func worldNormal(forPip pip: Int) -> Vec3 {
        if pip == top    { return Vec3( 0,  1,  0) }
        if pip == bottom { return Vec3( 0, -1,  0) }
        if pip == north  { return Vec3( 0,  0, -1) }
        if pip == south  { return Vec3( 0,  0,  1) }
        if pip == east   { return Vec3( 1,  0,  0) }
        return Vec3(-1, 0, 0)
    }

    /// World rotation axis around which a 90° cardinal tip occurs.
    public static func worldRollAxis(for direction: TumbleDirection) -> Vec3 {
        switch direction {
        case .north: return Vec3(-1, 0,  0)
        case .south: return Vec3( 1, 0,  0)
        case .east:  return Vec3( 0, 0, -1)
        case .west:  return Vec3( 0, 0,  1)
        }
    }

    /// Returns true if tipping in `direction` is legal under `axleLock` (either free24, or the pinned axle aligns with the roll axis).
    public func canTip(_ direction: TumbleDirection, axleLock: AxleLockAxis) -> Bool {
        guard let pair = axleLock.pinnedPair else { return true }
        // A cardinal tip keeps East/West fixed when tipping North/South, and keeps North/South fixed when tipping East/West.
        switch direction {
        case .north, .south:
            return east == pair.0 || east == pair.1
        case .east, .west:
            return north == pair.0 || north == pair.1
        }
    }

    /// Closed-form O(1) Shepperd mapping from `DieOrientation` to its exact SO(3) unit quaternion
    /// in canonical RH000 local coordinates (+X = Pip 3, +Y = Pip 1, +Z = Pip 2).
    public var unitQuaternion: Quat {
        let c0 = worldNormal(forPip: 3) // local +X
        let c1 = worldNormal(forPip: 1) // local +Y
        let c2 = worldNormal(forPip: 2) // local +Z

        let r00 = c0.x, r10 = c0.y, r20 = c0.z
        let r01 = c1.x, r11 = c1.y, r21 = c1.z
        let r02 = c2.x, r12 = c2.y, r22 = c2.z

        let tr = r00 + r11 + r22
        let qx, qy, qz, qw: Double
        if tr > 0.0 {
            let s = (tr + 1.0).squareRoot() * 2.0
            qw = 0.25 * s
            qx = (r21 - r12) / s
            qy = (r02 - r20) / s
            qz = (r10 - r01) / s
        } else if r00 > r11 && r00 > r22 {
            let s = (1.0 + r00 - r11 - r22).squareRoot() * 2.0
            qw = (r21 - r12) / s
            qx = 0.25 * s
            qy = (r01 + r10) / s
            qz = (r02 + r20) / s
        } else if r11 > r22 {
            let s = (1.0 + r11 - r00 - r22).squareRoot() * 2.0
            qw = (r02 - r20) / s
            qx = (r01 + r10) / s
            qy = 0.25 * s
            qz = (r12 + r21) / s
        } else {
            let s = (1.0 + r22 - r00 - r11).squareRoot() * 2.0
            qw = (r10 - r01) / s
            qx = (r02 + r20) / s
            qy = (r12 + r21) / s
            qz = 0.25 * s
        }
        return Quat(x: qx, y: qy, z: qz, w: qw).normalized
    }

    /// All 24 chiral SO(3) states of a Western Right-Handed Casino Die.
    public static var all24Orientations: [DieOrientation] {
        var list: [DieOrientation] = []
        list.reserveCapacity(24)
        for pip in 1...6 {
            for yaw in 0..<4 {
                list.append(.canonical(topPip: pip, yawSteps: yaw))
            }
        }
        return list
    }
}
