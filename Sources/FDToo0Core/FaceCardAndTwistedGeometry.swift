//
//  FaceCardAndTwistedGeometry.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  Learned-Player 24-State SO(3) Cube Geometry:
//  1) Twisted 45° (`4v` from Cie_qx.swift) Numerals whose crowns point into the shared
//     chirality vertices V_123 (+1,+1,+1) and V_654 (-1,-1,-1) so ALL 24 SO(3) states
//     produce 24 distinct (topPip, cornerQuadrant) signatures readable from Top alone!
//  2) Royal 6-Face FaceCard Dice {A♠, K♥, Q♦, 10♣, J♠ One-Eyed, J♦ Two-Eyed} where
//     Two-Eyed Jack is Wild and One-Eyed Jack is an Axle-Lock / Unlock Breaker.
//

import Foundation

/// Top-level Joe SmoLLey Spatial Deck navigation tabs.
public enum SpatialDeckTab: String, CaseIterable, Codable, Sendable, Identifiable {
    case flippingDice3D = "flipping_dice"
    case axleYahtzee    = "axle_yahtzee"
    case holySmolley    = "holy_smolley"
    case moonBuggyZ404  = "moon_buggy"

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .flippingDice3D: return "FLipPing 3D"
        case .axleYahtzee:    return "AxLe Yahtzee"
        case .holySmolley:    return "HoLy SmoLLey"
        case .moonBuggyZ404:  return "M00N Buggy"
        }
    }

    public var iconGlyph: String {
        switch self {
        case .flippingDice3D: return "🎲"
        case .axleYahtzee:    return "🃏"
        case .holySmolley:    return "🪐"
        case .moonBuggyZ404:  return "🛞"
        }
    }
}

/// The 4 upper corners of a Top die square into which a 45°-rotated Twisted Numeral points.
public enum CornerQuadrant: String, CaseIterable, Codable, Sendable, Hashable {
    case northEast = "NE" // (+X, -Z) -> 45° clockwise from North
    case southEast = "SE" // (+X, +Z) -> 135° clockwise from North
    case southWest = "SW" // (-X, +Z) -> 225° clockwise from North
    case northWest = "NW" // (-X, -Z) -> 315° clockwise from North

    /// Rotation angle in degrees clockwise from 12-o'clock North (`ang4v_o` = 45° base).
    public var clockwiseDegreesFromNorth: Double {
        switch self {
        case .northEast: return 45.0
        case .southEast: return 135.0
        case .southWest: return 225.0
        case .northWest: return 315.0
        }
    }

    public var arrowGlyph: String {
        switch self {
        case .northEast: return "↗"
        case .southEast: return "↘"
        case .southWest: return "↙"
        case .northWest: return "↖"
        }
    }

    /// Names the two adjacent board edges meeting at this corner.
    public var adjacentDirections: (TumbleDirection, TumbleDirection) {
        switch self {
        case .northEast: return (.north, .east)
        case .southEast: return (.south, .east)
        case .southWest: return (.south, .west)
        case .northWest: return (.north, .west)
        }
    }
}

/// Royal 6-Face FaceCard mapping onto standard Sum-7 RH000 pips (`1..6`):
/// - `[1-6]` Sum-7 Royal Axis: `1 -> A♠ (Ace of Spades)`, `6 -> K♥ (King of Hearts)`
/// - `[2-5]` Sum-7 Court Axis: `2 -> Q♦ (Queen of Diamonds)`, `5 -> 10♣ (Ten of Clubs)`
/// - `[3-4]` Sum-7 Dual-Jack Axis: `3 -> J♠ (One-Eyed Jack: Lock/Unlock Breaker)`, `4 -> J♦ (Two-Eyed Jack: Wild)`
public enum FaceCardFace: Int, CaseIterable, Codable, Sendable, Identifiable {
    case aceSpades          = 1
    case queenDiamonds      = 2
    case oneEyedJackSpades  = 3
    case twoEyedJackDiamond = 4
    case tenClubs           = 5
    case kingHearts         = 6

    public var id: Int { rawValue }

    public init(pip: Int) {
        self = FaceCardFace(rawValue: ((pip - 1) % 6 + 6) % 6 + 1) ?? .aceSpades
    }

    public var compactCode: String {
        switch self {
        case .aceSpades:          return "A♠"
        case .queenDiamonds:      return "Q♦"
        case .oneEyedJackSpades:  return "J♠👁"
        case .twoEyedJackDiamond: return "J♦👁👁"
        case .tenClubs:           return "10♣"
        case .kingHearts:         return "K♥"
        }
    }

    public var rankLabel: String {
        switch self {
        case .aceSpades:          return "A"
        case .queenDiamonds:      return "Q"
        case .oneEyedJackSpades:  return "J•1"
        case .twoEyedJackDiamond: return "J•2"
        case .tenClubs:           return "10"
        case .kingHearts:         return "K"
        }
    }

    public var suitSymbol: String {
        switch self {
        case .aceSpades, .oneEyedJackSpades:   return "♠"
        case .queenDiamonds, .twoEyedJackDiamond: return "♦"
        case .tenClubs:                        return "♣"
        case .kingHearts:                      return "♥"
        }
    }

    public var isRedSuit: Bool {
        switch self {
        case .queenDiamonds, .twoEyedJackDiamond, .kingHearts:
            return true
        case .aceSpades, .oneEyedJackSpades, .tenClubs:
            return false
        }
    }

    public var isOneEyedJack: Bool { self == .oneEyedJackSpades }
    public var isTwoEyedJack: Bool { self == .twoEyedJackDiamond }

    public var tacticalNote: String {
        switch self {
        case .aceSpades:          return "High Ace (Opposite K♥)"
        case .queenDiamonds:      return "Diamond Queen (Opposite 10♣)"
        case .oneEyedJackSpades:  return "One-Eyed Jack • Breaks or Cycles AxLe Lock!"
        case .twoEyedJackDiamond: return "Two-Eyed Jack • Wild Rank Substitute!"
        case .tenClubs:           return "Club Ten (Opposite Q♦)"
        case .kingHearts:         return "Heart King (Opposite A♠)"
        }
    }
}

/// Complete 1-glance Learned-Player signature for any of the 24 chiral SO(3) orientations.
public struct LearnedDieSignature: Equatable, Hashable, Sendable {
    public let topPip: Int
    public let cornerQuadrant: CornerQuadrant

    public var faceCard: FaceCardFace {
        FaceCardFace(pip: topPip)
    }

    public var displayBadge: String {
        "\(topPip)\(cornerQuadrant.arrowGlyph)"
    }

    public var faceCardBadge: String {
        "\(faceCard.compactCode)\(cornerQuadrant.arrowGlyph)"
    }
}

public enum LearnedGeometryOracle {
    /// Local chirality vertex: (+1,+1,+1) where {1,2,3} meet, or (-1,-1,-1) where {4,5,6} meet.
    public static func localChiralityVertex(forPip pip: Int) -> Vec3 {
        (pip <= 3) ? Vec3(1, 1, 1) : Vec3(-1, -1, -1)
    }

    /// Computes the exact corner quadrant (`NE`, `SE`, `SW`, `NW`) into which the 45°-tilted numeral
    /// (or FaceCard crown) points when `orientation` is viewed from above (+Y).
    /// Theorem: Across all 24 SO(3) states, `(topPip, twisted45Corner)` takes 24 unique values!
    public static func twisted45Corner(for orientation: DieOrientation) -> CornerQuadrant {
        let q = orientation.unitQuaternion
        let vLocal = localChiralityVertex(forPip: orientation.top)
        let vWorld = q.rotate(vLocal)
        // vWorld.y is guaranteed +1.0; vWorld.x in {-1, +1} (W/E); vWorld.z in {-1, +1} (N/S).
        let isEast = vWorld.x >= 0.0
        let isSouth = vWorld.z >= 0.0
        switch (isSouth, isEast) {
        case (false, true):  return .northEast
        case (true,  true):  return .southEast
        case (true,  false): return .southWest
        case (false, false): return .northWest
        }
    }

    public static func signature(for orientation: DieOrientation) -> LearnedDieSignature {
        LearnedDieSignature(
            topPip: orientation.top,
            cornerQuadrant: twisted45Corner(for: orientation)
        )
    }

    /// Formats a face token according to the active `DieVisualSkin`.
    public static func label(forPip pip: Int, skin: DieVisualSkin) -> String {
        switch skin {
        case .modeledPips:
            return "\(pip)"
        case .twisted45Numerals:
            return "\(pip)◇"
        case .royalFaceCards:
            return FaceCardFace(pip: pip).compactCode
        }
    }

    /// Shortest cardinal flip sequence (`BFS` over legal 90° tips) bringing `targetTopPip` onto Top
    /// while respecting an optional `AxleLockAxis`. Returns `nil` if unreachable under the locked axle.
    public static func shortestFlipPath(
        from start: DieOrientation,
        toTargetTop targetTopPip: Int,
        axleLock: AxleLockAxis = .free24
    ) -> [TumbleDirection]? {
        guard (1...6).contains(targetTopPip) else { return nil }
        if start.top == targetTopPip { return [] }

        var visited: Set<DieOrientation> = [start]
        var queue: [(DieOrientation, [TumbleDirection])] = [(start, [])]
        var head = 0

        while head < queue.count {
            let (cur, path) = queue[head]
            head += 1

            for dir in TumbleDirection.allCases {
                guard cur.canTip(dir, axleLock: axleLock) else { continue }
                let nxt = cur.tipped(dir)
                if nxt.top == targetTopPip {
                    return path + [dir]
                }
                if !visited.contains(nxt) {
                    visited.insert(nxt)
                    queue.append((nxt, path + [dir]))
                }
            }
        }
        return nil
    }
}
