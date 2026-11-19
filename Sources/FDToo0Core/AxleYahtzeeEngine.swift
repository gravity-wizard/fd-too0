//
//  AxleYahtzeeEngine.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  AxLe-Locked & FaceCard Yahtzee Parlour Engine:
//  1) Mysterious-Axis Mode: Real 1..6 dice rotate around a hidden/visible Sum-7 skewer
//     ([1-6], [2-5], or [3-4]), giving exact 1/4 = 25% uniform odds over the 4-face ring!
//  2) Physical Duplicate-Face 4-Number Mode: Real 6-face cubes carrying only 4 numbers
//     via conjugate opposite-face duplicates ({1,1,2,2,3,4} + {3,3,4,4,1,2}) so across
//     any conjugate pair every number {1,2,3,4} has exact 3/12 = 1/4 uniform probability!
//  3) Royal FaceCard Rules: Two-Eyed Jack (Pip 4 / J♦) = Wild rank; One-Eyed Jack (Pip 3 / J♠)
//     awards an Axle-Breaker charge to cycle or unlock any die's mysterious axis!
//

import Foundation
import Observation

public enum AxleYahtzeeProbabilityMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case mysteriousAxis           = "mysterious_axis"
    case conjugateDuplicate4Faces = "conjugate_4num"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .mysteriousAxis:
            return "Mysterious Axis (4-Ring Skewer)"
        case .conjugateDuplicate4Faces:
            return "Physical 4-Number Cubes (Conjugate 6-Face)"
        }
    }

    public var mathCaption: String {
        switch self {
        case .mysteriousAxis:
            return "Each die spins strictly around its [1-6], [2-5], or [3-4] skewer → 4 faces at exact 25% each."
        case .conjugateDuplicate4Faces:
            return "Cube α {1,1,2,2,3,4} + Cube β {3,3,4,4,1,2} → exact 3/12 = 25% per number across pairs!"
        }
    }
}

/// Physical 6-face duplicate-pair cube archetype carrying 4 numbers (`1...4`).
public enum ConjugateCubeArchetype: String, Codable, Sendable {
    /// Opposite faces [1,6]->1, [2,5]->2, 3->3, 4->4 => multiset {1, 1, 2, 2, 3, 4}
    case alpha12Doubled = "α {1,1,2,2,3,4}"
    /// Opposite faces [1,6]->3, [2,5]->4, 3->1, 4->2 => multiset {3, 3, 4, 4, 1, 2}
    case beta34Doubled  = "β {3,3,4,4,1,2}"

    public func mappedFourNumber(forRawPip pip: Int) -> Int {
        switch self {
        case .alpha12Doubled:
            switch pip {
            case 1, 6: return 1
            case 2, 5: return 2
            case 3:    return 3
            default:   return 4
            }
        case .beta34Doubled:
            switch pip {
            case 1, 6: return 3
            case 2, 5: return 4
            case 3:    return 1
            default:   return 2
            }
        }
    }

    /// Exact face multiset of 6 faces for probability verification.
    public var sixFaceValues: [Int] {
        (1...6).map { mappedFourNumber(forRawPip: $0) }
    }
}

public struct YahtzeeDieSlot: Identifiable, Equatable, Sendable {
    public let id: Int
    public var orientation: DieOrientation
    public var axleLock: AxleLockAxis
    public var archetype: ConjugateCubeArchetype
    public var isHeld: Bool
    public var pastelHue: PastelHueFamily

    public init(
        id: Int,
        orientation: DieOrientation,
        axleLock: AxleLockAxis,
        archetype: ConjugateCubeArchetype,
        isHeld: Bool = false,
        pastelHue: PastelHueFamily
    ) {
        self.id = id
        self.orientation = orientation
        self.axleLock = axleLock
        self.archetype = archetype
        self.isHeld = isHeld
        self.pastelHue = pastelHue
    }

    /// Effective rolled value (`1..6` in Mysterious-Axis mode, or `1..4` in Physical 4-Number mode).
    public func effectiveValue(in mode: AxleYahtzeeProbabilityMode) -> Int {
        switch mode {
        case .mysteriousAxis:
            return orientation.top
        case .conjugateDuplicate4Faces:
            return archetype.mappedFourNumber(forRawPip: orientation.top)
        }
    }
}

public enum AxleYahtzeeCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case onesOrAces     = "Ones / Aces (1 • A♠)"
    case twosOrQueens   = "Twos / Queens (2 • Q♦)"
    case threesOr1EJ    = "Threes / 1-Eye J (3 • J♠)"
    case foursOr2EJ     = "Fours / 2-Eye J (4 • J♦)"
    case threeOfAKind   = "Three of a Kind"
    case fourOfAKind    = "Four of a Kind"
    case fullHouse      = "Full House (25)"
    case fourRingRun    = "4-Number Ring Straight (35)"
    case axleYahtzee50  = "AxLe Yahtzee! 5-Kind (50)"
    case chanceSum      = "Chance (All 5 Sum)"

    public var id: String { rawValue }
}

@Observable
public final class AxleYahtzeeEngine {
    public var probabilityMode: AxleYahtzeeProbabilityMode = .mysteriousAxis {
        didSet { startNewGame() }
    }
    public var jackPowersEnabled: Bool = true
    public private(set) var dice: [YahtzeeDieSlot] = []
    public private(set) var rollsRemaining: Int = 3
    public private(set) var tacticalNudgesRemaining: Int = 1
    public private(set) var axleBreakerTokens: Int = 1
    public private(set) var lockedScores: [AxleYahtzeeCategory: Int] = [:]
    public private(set) var statusBanner: String = "Tap Roll Cup! Mysterious Skewers lock each die onto a 4-face ring."

    private var rng = SplitMix64RNG(seed: 0xA785_2323_7A47_2EE0)

    public init() {
        startNewGame()
    }

    public var totalScore: Int {
        lockedScores.values.reduce(0, +)
    }

    public var isGameComplete: Bool {
        lockedScores.count == AxleYahtzeeCategory.allCases.count
    }

    public var effectiveValues: [Int] {
        dice.map { $0.effectiveValue(in: probabilityMode) }
    }

    public func startNewGame(seed: UInt64? = nil) {
        if let seed {
            rng = SplitMix64RNG(seed: seed)
        }
        lockedScores.removeAll()
        rollsRemaining = 3
        tacticalNudgesRemaining = 1
        axleBreakerTokens = 1

        let defaultAxles: [AxleLockAxis] = [.pin16, .pin25, .pin34, .pin16, .pin25]
        let archetypes: [ConjugateCubeArchetype] = [.alpha12Doubled, .beta34Doubled, .alpha12Doubled, .beta34Doubled, .alpha12Doubled]
        let hues: [PastelHueFamily] = [.coralBlush, .apricotPeach, .buttercreamSun, .mintSage, .glacierSky]

        var built: [YahtzeeDieSlot] = []
        for idx in 0..<5 {
            let ax = (probabilityMode == .mysteriousAxis) ? defaultAxles[idx] : .free24
            let orient = Self.alignedInitialOrientation(for: ax, step: idx)
            built.append(
                YahtzeeDieSlot(
                    id: idx,
                    orientation: orient,
                    axleLock: ax,
                    archetype: archetypes[idx],
                    isHeld: false,
                    pastelHue: hues[idx]
                )
            )
        }
        dice = built
        statusBanner = probabilityMode.mathCaption
    }

    /// Places the pinned pair onto East/West so North/South tips spin cleanly around the 4-face ring!
    public static func alignedInitialOrientation(for axle: AxleLockAxis, step: Int = 0) -> DieOrientation {
        var base: DieOrientation
        switch axle {
        case .free24:
            base = .canonical(topPip: (step % 6) + 1, yawSteps: step % 4)
        case .pin16:
            // Put 1 on East, 6 on West -> North/South rolls cycle {2, 3, 5, 4}!
            base = DieOrientation(top: 2, north: 3, east: 1)
        case .pin25:
            // Put 2 on East, 5 on West -> North/South rolls cycle {1, 4, 6, 3}!
            base = DieOrientation(top: 1, north: 4, east: 2)
        case .pin34:
            // Put 3 on East, 4 on West -> North/South rolls cycle {1, 5, 6, 2}!
            base = DieOrientation(top: 1, north: 5, east: 3)
        }
        for _ in 0..<(step % 4) {
            base = base.tipped(.north)
        }
        return base
    }

    public func toggleHold(dieIndex: Int) {
        guard dice.indices.contains(dieIndex), rollsRemaining < 3 else { return }
        dice[dieIndex].isHeld.toggle()
    }

    /// Uses a One-Eyed Jack Axle-Breaker token to cycle or unlock a die's mysterious skewer!
    @discardableResult
    public func cycleDieAxle(dieIndex: Int) -> Bool {
        guard dice.indices.contains(dieIndex), axleBreakerTokens > 0 else { return false }
        axleBreakerTokens -= 1
        let nextAxle = dice[dieIndex].axleLock.nextCycled
        dice[dieIndex].axleLock = nextAxle
        dice[dieIndex].orientation = Self.alignedInitialOrientation(for: nextAxle, step: rng.nextInt(4))
        statusBanner = "One-Eyed Jack Breaker! Die #\(dieIndex + 1) shifted to \(nextAxle.shortTag)."
        return true
    }

    /// Learned-Player Tactical 90° Flip along a legal roll direction (1 per turn).
    @discardableResult
    public func nudgeDie(dieIndex: Int, direction: TumbleDirection) -> Bool {
        guard dice.indices.contains(dieIndex),
              tacticalNudgesRemaining > 0,
              rollsRemaining < 3 else { return false }
        let cur = dice[dieIndex]
        guard cur.orientation.canTip(direction, axleLock: cur.axleLock) else {
            statusBanner = "Blocked by \(cur.axleLock.shortTag)! Tip perpendicular to the skewer or use a 1-Eyed Jack."
            return false
        }
        tacticalNudgesRemaining -= 1
        dice[dieIndex].orientation = cur.orientation.tipped(direction)
        let newVal = dice[dieIndex].effectiveValue(in: probabilityMode)
        statusBanner = "Learned Flip \(direction.arrowGlyph) on Die #\(dieIndex + 1) → Top is now \(newVal)!"
        return true
    }

    /// Rolls all unheld dice according to either Mysterious-Axis 4-ring physics or Physical 6-face cubes.
    @discardableResult
    public func rollUnheldDice() -> Bool {
        guard rollsRemaining > 0, !isGameComplete else { return false }
        rollsRemaining -= 1

        var oneEyedJacksRolled = 0
        for idx in dice.indices where !dice[idx].isHeld {
            switch probabilityMode {
            case .mysteriousAxis:
                let ax = dice[idx].axleLock
                if ax == .free24 {
                    let pip = rng.nextInt(6) + 1
                    let yaw = rng.nextInt(4)
                    dice[idx].orientation = .canonical(topPip: pip, yawSteps: yaw)
                } else {
                    // Spin 1..4 random 90° steps strictly around the locked skewer -> exact 1/4 uniform per ring face!
                    var o = Self.alignedInitialOrientation(for: ax, step: 0)
                    let quarterTurns = rng.nextInt(4)
                    for _ in 0..<quarterTurns {
                        o = o.tipped(.north)
                    }
                    // Optional 180° yaw flip of skewer polarity (+East <-> +West) preserves exact 4-face ring!
                    if rng.nextInt(2) == 1 {
                        o = o.spunClockwise().spunClockwise()
                    }
                    dice[idx].orientation = o
                }
            case .conjugateDuplicate4Faces:
                let pip = rng.nextInt(6) + 1
                let yaw = rng.nextInt(4)
                dice[idx].orientation = .canonical(topPip: pip, yawSteps: yaw)
            }

            if jackPowersEnabled && dice[idx].orientation.top == 3 {
                oneEyedJacksRolled += 1
            }
        }

        if oneEyedJacksRolled > 0 {
            axleBreakerTokens = min(4, axleBreakerTokens + oneEyedJacksRolled)
            statusBanner = "Rolled \(oneEyedJacksRolled) One-Eyed Jack (J♠)! +\(oneEyedJacksRolled) AxLe-Breaker Token (\(rollsRemaining) rolls left)."
        } else {
            statusBanner = "Rolls left: \(rollsRemaining) • Hold matching ranks or use your Learned 90° Nudge!"
        }
        return true
    }

    /// Evaluates the score of `category` for the current 5 dice, honoring Two-Eyed Jack (`4` / `J♦`) wilds when enabled in Mysterious-Axis FaceCard play.
    public func potentialScore(for category: AxleYahtzeeCategory) -> Int {
        let vals = effectiveValues
        let wildActive = jackPowersEnabled && (probabilityMode == .mysteriousAxis)
        let wildValue = 4 // Pip 4 = Two-Eyed Jack (J♦)

        switch category {
        case .onesOrAces:
            return vals.filter { $0 == 1 || (wildActive && $0 == wildValue) }.count * 1
        case .twosOrQueens:
            return vals.filter { $0 == 2 || (wildActive && $0 == wildValue) }.count * 2
        case .threesOr1EJ:
            return vals.filter { $0 == 3 || (wildActive && $0 == wildValue) }.count * 3
        case .foursOr2EJ:
            return vals.filter { $0 == 4 }.count * 4
        case .chanceSum:
            return vals.reduce(0, +)
        case .threeOfAKind, .fourOfAKind, .axleYahtzee50, .fullHouse, .fourRingRun:
            return Self.evaluatePatternCategory(category, values: vals, wildValue: wildActive ? wildValue : nil)
        }
    }

    public static func evaluatePatternCategory(
        _ category: AxleYahtzeeCategory,
        values: [Int],
        wildValue: Int?
    ) -> Int {
        let sumAll = values.reduce(0, +)
        let wildCount = wildValue != nil ? values.filter { $0 == wildValue }.count : 0
        var counts: [Int: Int] = [:]
        for v in values where v != wildValue {
            counts[v, default: 0] += 1
        }
        let maxNatural = counts.values.max() ?? 0
        let bestKind = min(5, maxNatural + wildCount)

        switch category {
        case .threeOfAKind:
            return bestKind >= 3 ? sumAll : 0
        case .fourOfAKind:
            return bestKind >= 4 ? sumAll : 0
        case .axleYahtzee50:
            return bestKind >= 5 ? 50 : 0
        case .fullHouse:
            if bestKind == 5 { return 25 }
            let sortedCounts = counts.values.sorted(by: >)
            if sortedCounts.count <= 2 && (sortedCounts.reduce(0, +) + wildCount == 5) {
                let first = sortedCounts.first ?? 0
                let second = sortedCounts.dropFirst().first ?? 0
                if first + second + wildCount == 5 && first <= 3 && second <= 3 {
                    return 25
                }
            }
            return 0
        case .fourRingRun:
            // Any 4 distinct sequential numbers ({1,2,3,4}, {2,3,4,5}, {3,4,5,6}) or full 4-ring coverage {1,2,5,6}/{1,3,4,6}
            let distinctNonWild = Set(counts.keys)
            let windows: [Set<Int>] = [
                [1, 2, 3, 4],
                [2, 3, 4, 5],
                [3, 4, 5, 6],
                [1, 3, 4, 6],
                [1, 2, 5, 6]
            ]
            for win in windows {
                let matched = win.intersection(distinctNonWild).count
                if matched + wildCount >= 4 {
                    return 35
                }
            }
            return 0
        default:
            return 0
        }
    }

    @discardableResult
    public func commitScore(in category: AxleYahtzeeCategory) -> Bool {
        guard lockedScores[category] == nil, rollsRemaining < 3 else { return false }
        let pts = potentialScore(for: category)
        lockedScores[category] = pts

        for idx in dice.indices {
            dice[idx].isHeld = false
        }
        rollsRemaining = 3
        tacticalNudgesRemaining = 1

        if isGameComplete {
            statusBanner = "Parlour Sheet Complete! Final Score: \(totalScore) pts."
        } else {
            statusBanner = "Scored \(pts) pts in \(category.rawValue)! Tap Roll Cup for next frame."
        }
        return true
    }

    /// Exact mathematical verification that across a Conjugate `(α, β)` 6-face duplicate-pair set,
    /// every single number `{1, 2, 3, 4}` has exact uniform pool probability `0.25` (3/12).
    public static func conjugatePairPoolProbabilities() -> [Int: Double] {
        let alpha = ConjugateCubeArchetype.alpha12Doubled.sixFaceValues
        let beta = ConjugateCubeArchetype.beta34Doubled.sixFaceValues
        let combined = alpha + beta // 12 total equally-likely faces across the 2-die pair
        var probs: [Int: Double] = [:]
        for num in 1...4 {
            let hits = combined.filter { $0 == num }.count
            probs[num] = Double(hits) / Double(combined.count)
        }
        return probs
    }

    /// Recommends the best open category for Learned players.
    public var recommendedOpenCategory: (category: AxleYahtzeeCategory, points: Int)? {
        var best: (AxleYahtzeeCategory, Int)? = nil
        for cat in AxleYahtzeeCategory.allCases where lockedScores[cat] == nil {
            let pts = potentialScore(for: cat)
            if best == nil || pts > best!.1 {
                best = (cat, pts)
            }
        }
        return best
    }
}
