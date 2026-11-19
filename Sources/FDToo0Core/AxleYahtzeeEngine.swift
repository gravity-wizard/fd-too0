//
//  AxleYahtzeeEngine.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  ReguLar 1–6 + Full-3D AxLe & Corner-Vertex Yahtzee Parlour Engine:
//  1) ReguLar 1–6 Mode: Classic Standard 5-Dice Yahtzee (13 categories + +35 Upper Bonus at 63+).
//  2) AxLe 3D Mode: Full 24-state SO(3) dice that DO NOT only turn about axles — players can
//     roll freely in 3D, optionally pin [1-6]/[2-5]/[3-4] 4-face skewers, AND turn dice via
//     90° Edge Tumbles (↑↓←→), 120° Corner-Vertex Spins (◇ East→Top→South), 180° Sum-7 Twists (⟳),
//     and free 90° Felt Yaw spins (↻)!
//  3) Physical 4-Number Conjugate Mode: Cube α {1,1,2,2,3,4} + Cube β {3,3,4,4,1,2} -> exact 25% odds.
//  4) Built-in Coach Prompts, 5-Step Interactive Tutorial, and Bot Opponents (🐢 TurtLe & 🤖 Joe SmoLLey)!
//

import Foundation
import Observation

public enum AxleYahtzeeProbabilityMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case regularStandard          = "regular_1to6"
    case mysteriousAxis           = "mysterious_axis"
    case conjugateDuplicate4Faces = "conjugate_4num"

    public var id: String { rawValue }

    public var shortTabTitle: String {
        switch self {
        case .regularStandard:          return "🎲 ReguLar 1–6"
        case .mysteriousAxis:           return "⚡ AxLe 3D"
        case .conjugateDuplicate4Faces: return "◇ 4-Num Pair"
        }
    }

    public var title: String {
        switch self {
        case .regularStandard:
            return "Classic ReguLar Yahtzee (Standard 1–6 Dice)"
        case .mysteriousAxis:
            return "AxLe 3D Spatial Yahtzee (Edge 90° + Corner 120° + Twist 180° + Skewers)"
        case .conjugateDuplicate4Faces:
            return "Physical 4-Number Cubes (Conjugate 6-Face α/β)"
        }
    }

    public var mathCaption: String {
        switch self {
        case .regularStandard:
            return "Classic 5 standard 1–6 dice • 3 rolls per turn • Reach 63+ in 1s–6s for +35 Upper Bonus!"
        case .mysteriousAxis:
            return "Full 3D dice: Roll freely (1–6), pin optional [1-6]/[2-5]/[3-4] axles, or turn via ↑↓←→ 90°, ◇120° Corner & ⟳180° Twist!"
        case .conjugateDuplicate4Faces:
            return "Cube α {1,1,2,2,3,4} + Cube β {3,3,4,4,1,2} → exact 3/12 = 25% per number across pairs!"
        }
    }
}

/// Opponent roster for Solo practice or Head-to-Head Parlour play against Bots.
public enum YahtzeeOpponentMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case solo        = "solo"
    case vsTurtle    = "vs_turtle"
    case vsSmolley   = "vs_smolley"
    case parlourTrio = "parlour_trio"

    public var id: String { rawValue }

    public var pillLabel: String {
        switch self {
        case .solo:        return "👤 Solo"
        case .vsTurtle:    return "vs 🐢 TurtLe"
        case .vsSmolley:   return "vs 🤖 SmoLLey"
        case .parlourTrio: return "🏆 Trio (🐢+🤖)"
        }
    }
}

/// Interactive 5-step table tutorial teaching both Regular Yahtzee and Full-3D AxLe moves.
public enum YahtzeeTutorialStep: Int, CaseIterable, Codable, Sendable, Identifiable {
    case welcomeModes    = 0
    case rollAndHold     = 1
    case beyondAxles3D   = 2
    case optionalSkewers = 3
    case scoreAndBots    = 4

    public var id: Int { rawValue }

    public var stepBadge: String {
        "Lesson \(rawValue + 1) of \(Self.allCases.count)"
    }

    public var headline: String {
        switch self {
        case .welcomeModes:
            return "🎲 ReguLar 1–6 vs ⚡ AxLe 3D Dice"
        case .rollAndHold:
            return "🥤 Roll the Cup & Tap Dice to HOLD ★"
        case .beyondAxles3D:
            return "◇ Dice Don’t Only Turn About Axles!"
        case .optionalSkewers:
            return "📌 Optional AxLe Skewers ([1-6], [2-5], [3-4])"
        case .scoreAndBots:
            return "🏆 Score Rows, +35 Bonus & Bot Opponents"
        }
    }

    public var bodyText: String {
        switch self {
        case .welcomeModes:
            return "Pick [🎲 ReguLar 1–6] anytime for pure classic 13-category Yahtzee, or [⚡ AxLe 3D] to unlock 3D edge tumbles, 120° corner spins, 180° twists, and optional 4-ring skewers!"
        case .rollAndHold:
            return "You get up to 3 rolls per turn. Tap [Roll Cup], then tap any 3D die (or its card below) to toggle [HOLD ★] on matching numbers before rolling the rest."
        case .beyondAxles3D:
            return "In [⚡ AxLe 3D], select any die and try all 4 3D rotation families: [↑↓←→] 90° Edge Tumble, [◇ 120° Corner] (spins East→Top→South around the front-top-right vertex!), [⟳ 180° Twist] (flips Top↔7−Top), and free [↻ Yaw]!"
        case .optionalSkewers:
            return "Want 25% sniping odds on 4 faces? Tap [Pin AxLe] on the focused die to cycle Free 1–6 → [1-6] → [2-5] → [3-4]. Unpinned dice always tumble freely across all 6 faces!"
        case .scoreAndBots:
            return "Tap any open Scorecard row (yellow = Coach's top pick!) to lock points. Reach 63+ in 1s–6s for +35 Bonus, and switch Opponent to [vs 🐢 TurtLe] or [vs 🤖 SmoLLey] to race live Bots!"
        }
    }
}

/// Physical 6-face duplicate-pair cube archetype carrying 4 numbers (`1...4`).
public enum ConjugateCubeArchetype: String, Codable, Sendable {
    case alpha12Doubled = "α {1,1,2,2,3,4}"
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

    /// Effective rolled value (`1..6` in Regular & AxLe 3D modes, or `1..4` in Physical 4-Number mode).
    public func effectiveValue(in mode: AxleYahtzeeProbabilityMode) -> Int {
        switch mode {
        case .regularStandard, .mysteriousAxis:
            return orientation.top
        case .conjugateDuplicate4Faces:
            return archetype.mappedFourNumber(forRawPip: orientation.top)
        }
    }

    /// Real-world protruding pin-axle physics: if a 90° tip would stand the cube upright on its
    /// protruding rounded pin cap, gravity immediately vaults it 90° further onto the flat opposite face!
    public func settledOrientationAfterTip(_ direction: TumbleDirection) -> DieOrientation {
        let first = orientation.tipped(direction)
        if let pair = axleLock.pinnedPair, (first.top == pair.0 || first.top == pair.1) {
            return first.tipped(direction)
        }
        return first
    }

    /// Real-world protruding pin-axle physics for a 120° corner-vertex spin: if East carries a
    /// protruding pin cap, the cube cannot rest on that pin and rolls onto South (guaranteed flat!).
    public func settledOrientationAfterCorner120() -> DieOrientation {
        let first = orientation.spunCorner120()
        if let pair = axleLock.pinnedPair, (first.top == pair.0 || first.top == pair.1) {
            return first.spunCorner120()
        }
        return first
    }
}

public enum AxleYahtzeeCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    // Upper Section (1..6)
    case onesOrAces     = "Aces (1s)"
    case twosOrQueens   = "Twos (2s)"
    case threesOr1EJ    = "Threes (3s)"
    case foursOr2EJ     = "Fours (4s)"
    case fivesOrKings   = "Fives (5s)"
    case sixesOrTens    = "Sixes (6s)"

    // Lower Section
    case threeOfAKind   = "3 of a Kind"
    case fourOfAKind    = "4 of a Kind"
    case fullHouse      = "Full House (25)"
    case fourRingRun    = "Sm. Straight 4 (30)"
    case largeStraight5 = "Lg. Straight 5 (40)"
    case axleYahtzee50  = "Yahtzee! 5-Kind (50)"
    case chanceSum      = "Chance (Sum)"

    public var id: String { rawValue }

    public var isUpperSection: Bool {
        switch self {
        case .onesOrAces, .twosOrQueens, .threesOr1EJ, .foursOr2EJ, .fivesOrKings, .sixesOrTens:
            return true
        default:
            return false
        }
    }

    public var upperTargetFace: Int? {
        switch self {
        case .onesOrAces:   return 1
        case .twosOrQueens: return 2
        case .threesOr1EJ:  return 3
        case .foursOr2EJ:   return 4
        case .fivesOrKings: return 5
        case .sixesOrTens:  return 6
        default:            return nil
        }
    }

    public static func activeCategories(for mode: AxleYahtzeeProbabilityMode) -> [AxleYahtzeeCategory] {
        switch mode {
        case .regularStandard, .mysteriousAxis:
            return Self.allCases
        case .conjugateDuplicate4Faces:
            return Self.allCases.filter {
                $0 != .fivesOrKings && $0 != .sixesOrTens && $0 != .largeStraight5
            }
        }
    }
}

/// Represents a Bot Competitor (`🐢 TurtLe` or `🤖 Joe SmoLLey`) in Parlour play.
public struct YahtzeeBotCompetitor: Identifiable, Equatable, Sendable {
    public enum Personality: String, Codable, Sendable {
        case clubTurtle
        case grandmasterSmolley
    }

    public let id: String
    public let displayName: String
    public let emoji: String
    public let personality: Personality
    public var lockedScores: [AxleYahtzeeCategory: Int] = [:]
    public var lastTurnSummary: String = "Waiting for your opening frame…"

    public init(id: String, displayName: String, emoji: String, personality: Personality) {
        self.id = id
        self.displayName = displayName
        self.emoji = emoji
        self.personality = personality
    }

    public var upperSubtotal: Int {
        lockedScores.reduce(0) { acc, pair in
            pair.key.isUpperSection ? acc + pair.value : acc
        }
    }

    public func upperBonus(for mode: AxleYahtzeeProbabilityMode) -> Int {
        let threshold = (mode == .conjugateDuplicate4Faces) ? 30 : 63
        return upperSubtotal >= threshold ? 35 : 0
    }

    public func totalScore(for mode: AxleYahtzeeProbabilityMode) -> Int {
        lockedScores.values.reduce(0, +) + upperBonus(for: mode)
    }
}

@Observable
public final class AxleYahtzeeEngine {
    public var probabilityMode: AxleYahtzeeProbabilityMode = .mysteriousAxis {
        didSet {
            if oldValue != probabilityMode {
                startNewGame()
            }
        }
    }
    public var opponentMode: YahtzeeOpponentMode = .vsTurtle {
        didSet {
            if oldValue != opponentMode {
                startNewGame()
            }
        }
    }
    public var jackPowersEnabled: Bool = false

    public private(set) var dice: [YahtzeeDieSlot] = []
    public private(set) var rollsRemaining: Int = 3
    public private(set) var tacticalNudgesRemaining: Int = 1
    public private(set) var axleBreakerTokens: Int = 3
    public private(set) var lockedScores: [AxleYahtzeeCategory: Int] = [:]
    public private(set) var bots: [YahtzeeBotCompetitor] = []
    public private(set) var botTurnFeed: [String] = []
    public private(set) var statusBanner: String = "Tap Roll Cup! Choose ReguLar 1–6 or AxLe 3D anytime."

    // Interactive Tutorial State
    public var isTutorialActive: Bool = false
    public var tutorialStep: YahtzeeTutorialStep = .welcomeModes

    private var rng = SplitMix64RNG(seed: 0xA785_2323_7A47_2EE0)

    public init() {
        startNewGame()
    }

    public var activeCategories: [AxleYahtzeeCategory] {
        AxleYahtzeeCategory.activeCategories(for: probabilityMode)
    }

    public var upperBonusThreshold: Int {
        probabilityMode == .conjugateDuplicate4Faces ? 30 : 63
    }

    public var upperSubtotal: Int {
        lockedScores.reduce(0) { acc, pair in
            pair.key.isUpperSection ? acc + pair.value : acc
        }
    }

    public var upperBonus: Int {
        upperSubtotal >= upperBonusThreshold ? 35 : 0
    }

    public var totalScore: Int {
        lockedScores.values.reduce(0, +) + upperBonus
    }

    public var isGameComplete: Bool {
        let cats = activeCategories
        return cats.allSatisfy { lockedScores[$0] != nil }
    }

    public var effectiveValues: [Int] {
        dice.map { $0.effectiveValue(in: probabilityMode) }
    }

    // MARK: - Tutorial Controls

    public func startTutorial() {
        isTutorialActive = true
        tutorialStep = .welcomeModes
    }

    public func nextTutorialStep() {
        let all = YahtzeeTutorialStep.allCases
        if let idx = all.firstIndex(of: tutorialStep), idx + 1 < all.count {
            tutorialStep = all[idx + 1]
        } else {
            isTutorialActive = false
        }
    }

    public func previousTutorialStep() {
        let all = YahtzeeTutorialStep.allCases
        if let idx = all.firstIndex(of: tutorialStep), idx > 0 {
            tutorialStep = all[idx - 1]
        }
    }

    // MARK: - New Game Setup

    public func startNewGame(seed: UInt64? = nil) {
        if let seed {
            rng = SplitMix64RNG(seed: seed)
        }
        lockedScores.removeAll()
        botTurnFeed.removeAll()
        rollsRemaining = 3
        tacticalNudgesRemaining = (probabilityMode == .mysteriousAxis) ? 1 : 0
        axleBreakerTokens = (probabilityMode == .mysteriousAxis) ? 3 : 0

        // Setup Bots for selected opponent mode
        switch opponentMode {
        case .solo:
            bots = []
        case .vsTurtle:
            bots = [YahtzeeBotCompetitor(id: "turtle", displayName: "TurtLe Bot", emoji: "🐢", personality: .clubTurtle)]
        case .vsSmolley:
            bots = [YahtzeeBotCompetitor(id: "smolley", displayName: "Joe SmoLLey", emoji: "🤖", personality: .grandmasterSmolley)]
        case .parlourTrio:
            bots = [
                YahtzeeBotCompetitor(id: "turtle", displayName: "TurtLe Bot", emoji: "🐢", personality: .clubTurtle),
                YahtzeeBotCompetitor(id: "smolley", displayName: "Joe SmoLLey", emoji: "🤖", personality: .grandmasterSmolley)
            ]
        }

        // In AxLe 3D mode, start with 2 example skewers & 3 Free-24 dice so players immediately see
        // that dice roll freely in 3D AND can optionally pin/unpin skewers!
        let initialAxles: [AxleLockAxis] = [.free24, .pin16, .free24, .pin25, .free24]
        let archetypes: [ConjugateCubeArchetype] = [.alpha12Doubled, .beta34Doubled, .alpha12Doubled, .beta34Doubled, .alpha12Doubled]
        let hues: [PastelHueFamily] = [.coralBlush, .apricotPeach, .buttercreamSun, .mintSage, .glacierSky]

        var built: [YahtzeeDieSlot] = []
        for idx in 0..<5 {
            let ax: AxleLockAxis = (probabilityMode == .mysteriousAxis) ? initialAxles[idx] : .free24
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
            base = DieOrientation(top: 2, north: 3, east: 1)
        case .pin25:
            base = DieOrientation(top: 1, north: 4, east: 2)
        case .pin34:
            base = DieOrientation(top: 1, north: 5, east: 3)
        }
        for _ in 0..<(step % 4) {
            base = base.tipped(.north)
        }
        return base
    }

    public func toggleHold(dieIndex: Int) {
        guard dice.indices.contains(dieIndex), rollsRemaining < 3 else {
            statusBanner = "Roll the cup once first, then tap dice to HOLD ★!"
            return
        }
        dice[dieIndex].isHeld.toggle()
        let val = dice[dieIndex].effectiveValue(in: probabilityMode)
        statusBanner = dice[dieIndex].isHeld
            ? "Held Die #\(dieIndex + 1) (\(val)) ★"
            : "Unheld Die #\(dieIndex + 1) — ready to roll."
    }

    // MARK: - Full-3D Spatial Manipulations (Beyond Axles!)

    /// Cycles or unlocks a die's optional Sum-7 skewer (`Free-24 → [1-6] → [2-5] → [3-4]`).
    @discardableResult
    public func cycleDieAxle(dieIndex: Int) -> Bool {
        guard probabilityMode == .mysteriousAxis,
              dice.indices.contains(dieIndex),
              axleBreakerTokens > 0 else { return false }
        axleBreakerTokens -= 1
        let nextAxle = dice[dieIndex].axleLock.nextCycled
        dice[dieIndex].axleLock = nextAxle
        if nextAxle != .free24 {
            // Align skewer horizontally while keeping a clean ring face on top if needed
            if let pair = nextAxle.pinnedPair,
               dice[dieIndex].orientation.top == pair.0 || dice[dieIndex].orientation.top == pair.1 {
                dice[dieIndex].orientation = Self.alignedInitialOrientation(for: nextAxle, step: rng.nextInt(4))
            }
        }
        statusBanner = nextAxle == .free24
            ? "Die #\(dieIndex + 1) unlocked to Free 24-State 3D roll (all 6 faces)!"
            : "Die #\(dieIndex + 1) pinned to \(nextAxle.displayTitle) (25% per ring face)."
        return true
    }

    /// 90° Cardinal Edge Tumble (`↑ North`, `↓ South`, `← West`, `→ East`).
    /// Protruding pin-axles physically prevent landing with pinned numbers face-up/down:
    /// tipping onto a rounded pin cap vaults cleanly over onto the next flat ring face!
    @discardableResult
    public func nudgeDie(dieIndex: Int, direction: TumbleDirection) -> Bool {
        guard probabilityMode == .mysteriousAxis,
              dice.indices.contains(dieIndex),
              tacticalNudgesRemaining > 0,
              rollsRemaining < 3 else { return false }
        tacticalNudgesRemaining -= 1
        let rawTip = dice[dieIndex].orientation.tipped(direction)
        let settled = dice[dieIndex].settledOrientationAfterTip(direction)
        let vaulted = (settled != rawTip)
        dice[dieIndex].orientation = settled

        let newVal = dice[dieIndex].effectiveValue(in: probabilityMode)
        if vaulted {
            statusBanner = "Vaulted over protruding \(dice[dieIndex].axleLock.shortTag) pin cap (\(rawTip.top) can't rest face-up) → landed flat on \(newVal)!"
        } else {
            statusBanner = "90° Edge Tumble \(direction.arrowGlyph) on Die #\(dieIndex + 1) → Top is now \(newVal)!"
        }
        return true
    }

    /// 120° Corner-Vertex Spin (`◇`) around the front-upper-right `[East → Top → South]` diagonal!
    /// If East has a protruding pin-axle, gravity rolls past the pin cap onto South!
    @discardableResult
    public func spinDieCorner120(dieIndex: Int) -> Bool {
        guard probabilityMode == .mysteriousAxis,
              dice.indices.contains(dieIndex),
              tacticalNudgesRemaining > 0,
              rollsRemaining < 3 else { return false }
        tacticalNudgesRemaining -= 1
        let rawSpin = dice[dieIndex].orientation.spunCorner120()
        let settled = dice[dieIndex].settledOrientationAfterCorner120()
        let vaulted = (settled != rawSpin)
        dice[dieIndex].orientation = settled

        let newVal = dice[dieIndex].effectiveValue(in: probabilityMode)
        if vaulted {
            statusBanner = "◇ Corner Spin rolled off protruding \(dice[dieIndex].axleLock.shortTag) pin → settled flat on \(newVal)!"
        } else {
            statusBanner = "◇ 120° Corner-Vertex Spin on Die #\(dieIndex + 1) (East→Top→South) → Top is now \(newVal)!"
        }
        return true
    }

    /// 180° Sum-7 Opposite Twist (`⟳`) flipping `Top ↔ 7 - Top` (`1↔6`, `2↔5`, `3↔4`).
    @discardableResult
    public func twistDie180(dieIndex: Int) -> Bool {
        guard probabilityMode == .mysteriousAxis,
              dice.indices.contains(dieIndex),
              tacticalNudgesRemaining > 0,
              rollsRemaining < 3 else { return false }
        tacticalNudgesRemaining -= 1
        dice[dieIndex].orientation = dice[dieIndex].orientation.twisted180()
        let newVal = dice[dieIndex].effectiveValue(in: probabilityMode)
        statusBanner = "⟳ 180° Sum-7 Twist on Die #\(dieIndex + 1) → Flipped Top to \(newVal)!"
        return true
    }

    /// Free 90° Clockwise Felt Yaw (`↻`) — aligns side faces without changing Top or spending your move!
    @discardableResult
    public func yawDie90(dieIndex: Int) -> Bool {
        guard dice.indices.contains(dieIndex) else { return false }
        dice[dieIndex].orientation = dice[dieIndex].orientation.spunClockwise()
        let o = dice[dieIndex].orientation
        statusBanner = "↻ Yawed Die #\(dieIndex + 1) on felt (Top stays \(o.top); East=\(o.east), South=\(o.south))."
        return true
    }

    // MARK: - Rolling Cup

    @discardableResult
    public func rollUnheldDice() -> Bool {
        guard rollsRemaining > 0, !isGameComplete else { return false }
        rollsRemaining -= 1

        var oneEyedJacksRolled = 0
        for idx in dice.indices where !dice[idx].isHeld {
            switch probabilityMode {
            case .regularStandard, .conjugateDuplicate4Faces:
                let pip = rng.nextInt(6) + 1
                let yaw = rng.nextInt(4)
                dice[idx].orientation = .canonical(topPip: pip, yawSteps: yaw)

            case .mysteriousAxis:
                let ax = dice[idx].axleLock
                if ax == .free24 {
                    // Full 24-state SO(3) 3D roll across all 6 faces and all 4 yaws!
                    let pip = rng.nextInt(6) + 1
                    let yaw = rng.nextInt(4)
                    dice[idx].orientation = .canonical(topPip: pip, yawSteps: yaw)
                } else {
                    // Protruding pin-axles physically forbid resting on the 2 pinned faces:
                    // lands uniformly on the 4 flat ring faces (25% each) across all horizontal yaws!
                    var o = Self.alignedInitialOrientation(for: ax, step: 0)
                    let quarterTurns = rng.nextInt(4)
                    for _ in 0..<quarterTurns {
                        o = o.tipped(.north)
                    }
                    let yawSpins = rng.nextInt(4)
                    for _ in 0..<yawSpins {
                        o = o.spunClockwise()
                    }
                    dice[idx].orientation = o
                }
            }

            if jackPowersEnabled && probabilityMode == .mysteriousAxis && dice[idx].orientation.top == 3 {
                oneEyedJacksRolled += 1
            }
        }

        if oneEyedJacksRolled > 0 {
            tacticalNudgesRemaining = min(2, tacticalNudgesRemaining + 1)
            axleBreakerTokens = min(5, axleBreakerTokens + oneEyedJacksRolled)
            statusBanner = "Rolled \(oneEyedJacksRolled) One-Eyed Jack (J♠)! +1 Bonus 3D Move (\(rollsRemaining) rolls left)."
        } else {
            let valsStr = effectiveValues.map(String.init).joined(separator: ", ")
            statusBanner = "Rolled [\(valsStr)] • \(rollsRemaining) roll\(rollsRemaining == 1 ? "" : "s") left."
        }
        return true
    }

    // MARK: - Live Smart Coach Prompts

    public var coachPrompt: String {
        if isGameComplete {
            return outcomeSummaryBanner
        }
        if rollsRemaining == 3 {
            return "💡 Prompt: Tap [Roll Cup (3)] (or tap the 3D felt!) to shake all 5 dice for Frame #\(lockedScores.count + 1)."
        }

        // In AxLe 3D mode, check if a single 3D Tactical Move creates a high-scoring hand (>= 25 pts)!
        if probabilityMode == .mysteriousAxis && tacticalNudgesRemaining > 0 {
            if let tip = bestSingle3DMoveSuggestion(), tip.gain >= 12 {
                return "💡 3D Sighting: Select Die #\(tip.dieIndex + 1) and tap [\(tip.moveLabel)] → turns \(tip.fromPip)→\(tip.toPip) for \(tip.category.rawValue) (\(tip.newScore) pts)!"
            }
        }

        if rollsRemaining > 0 {
            let holdAdvice = recommendedHoldDescription()
            if let bestNow = recommendedOpenCategory, bestNow.points >= 25 {
                return "💡 Prompt: Strong hand! Lock [\(bestNow.category.rawValue) +\(bestNow.points)] now, OR \(holdAdvice) (\(rollsRemaining) roll\(rollsRemaining == 1 ? "" : "s") left)."
            }
            return "💡 Prompt: \(holdAdvice), then tap [Roll Cup (\(rollsRemaining))] — or score any open row below."
        } else {
            if let best = recommendedOpenCategory {
                return "💡 Prompt: 0 rolls left — tap [\(best.category.rawValue) +\(best.points)] (highlighted in yellow) to score your turn!"
            }
            return "💡 Prompt: Tap an open Scorecard row below to complete your turn."
        }
    }

    public var outcomeSummaryBanner: String {
        guard isGameComplete else { return statusBanner }
        let myTotal = totalScore
        if bots.isEmpty {
            return "🏁 Sheet Complete! Final Score: \(myTotal) pts (Upper Bonus: +\(upperBonus)). Tap [New Match] to play again!"
        }
        var contenders: [(String, Int)] = [("You", myTotal)]
        for b in bots {
            contenders.append(("\(b.emoji) \(b.displayName)", b.totalScore(for: probabilityMode)))
        }
        contenders.sort { $0.1 > $1.1 }
        let winner = contenders[0]
        let board = contenders.map { "\($0.0): \($0.1)" }.joined(separator: " • ")
        return "🏆 \(winner.0) Wins! (\(board))"
    }

    private func recommendedHoldDescription() -> String {
        let vals = effectiveValues
        var counts: [Int: Int] = [:]
        for v in vals { counts[v, default: 0] += 1 }
        if let bestPair = counts.max(by: { a, b in
            a.value != b.value ? a.value < b.value : a.key < b.key
        }), bestPair.value >= 2 {
            let slots = dice.enumerated().compactMap { $0.element.effectiveValue(in: probabilityMode) == bestPair.key ? "#\($0.offset + 1)" : nil }
            return "HOLD ★ your \(bestPair.value)× \(bestPair.key)s (Die \(slots.joined(separator: ", ")))"
        }
        // Check 3+ straight run
        let unique = Set(vals)
        for run in [[2, 3, 4, 5], [1, 2, 3, 4], [3, 4, 5, 6]] {
            let inter = unique.intersection(run)
            if inter.count >= 3 {
                let sorted = inter.sorted().map(String.init).joined(separator: "-")
                return "HOLD ★ straight run [\(sorted)]"
            }
        }
        if let highest = vals.max() {
            return "HOLD ★ your high \(highest)"
        }
        return "Tap matching dice to HOLD ★"
    }

    private struct TacticalMoveCandidate {
        let dieIndex: Int
        let moveLabel: String
        let fromPip: Int
        let toPip: Int
        let category: AxleYahtzeeCategory
        let newScore: Int
        let gain: Int
    }

    private func bestSingle3DMoveSuggestion() -> TacticalMoveCandidate? {
        let baselineBest = recommendedOpenCategory?.points ?? 0
        var best: TacticalMoveCandidate? = nil

        for idx in dice.indices {
            let slot = dice[idx]
            let fromVal = slot.effectiveValue(in: probabilityMode)
            let candidates: [(String, DieOrientation)] = [
                ("↑ 90°", slot.settledOrientationAfterTip(.north)),
                ("↓ 90°", slot.settledOrientationAfterTip(.south)),
                ("← 90°", slot.settledOrientationAfterTip(.west)),
                ("→ 90°", slot.settledOrientationAfterTip(.east)),
                ("◇ 120° Corner", slot.settledOrientationAfterCorner120()),
                ("⟳ 180° Twist", slot.orientation.twisted180())
            ]

            for (label, candOri) in candidates {
                var trialVals = effectiveValues
                trialVals[idx] = (probabilityMode == .conjugateDuplicate4Faces)
                    ? dice[idx].archetype.mappedFourNumber(forRawPip: candOri.top)
                    : candOri.top
                if trialVals[idx] == fromVal { continue }

                for cat in activeCategories where lockedScores[cat] == nil {
                    let pts = Self.score(category: cat, values: trialVals, mode: probabilityMode, jackWilds: jackPowersEnabled)
                    let gain = pts - baselineBest
                    if gain > (best?.gain ?? 0) {
                        best = TacticalMoveCandidate(
                            dieIndex: idx,
                            moveLabel: label,
                            fromPip: fromVal,
                            toPip: trialVals[idx],
                            category: cat,
                            newScore: pts,
                            gain: gain
                        )
                    }
                }
            }
        }
        return best
    }

    // MARK: - Category Scoring & Pattern Math

    public func potentialScore(for category: AxleYahtzeeCategory) -> Int {
        Self.score(
            category: category,
            values: effectiveValues,
            mode: probabilityMode,
            jackWilds: jackPowersEnabled
        )
    }

    public static func score(
        category: AxleYahtzeeCategory,
        values vals: [Int],
        mode: AxleYahtzeeProbabilityMode,
        jackWilds: Bool
    ) -> Int {
        let wildActive = jackWilds && (mode == .mysteriousAxis)
        let wildValue = 4 // Pip 4 = Two-Eyed Jack (J♦)

        if let target = category.upperTargetFace {
            if wildActive && target != wildValue {
                return vals.filter { $0 == target || $0 == wildValue }.count * target
            }
            return vals.filter { $0 == target }.count * target
        }

        if category == .chanceSum {
            return vals.reduce(0, +)
        }
        return evaluatePatternCategory(category, values: vals, wildValue: wildActive ? wildValue : nil)
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
            let distinctNonWild = Set(counts.keys)
            let windows: [Set<Int>] = [
                [1, 2, 3, 4],
                [2, 3, 4, 5],
                [3, 4, 5, 6]
            ]
            for win in windows {
                if win.intersection(distinctNonWild).count + wildCount >= 4 {
                    return 30
                }
            }
            return 0
        case .largeStraight5:
            let distinctNonWild = Set(counts.keys)
            let windows: [Set<Int>] = [
                [1, 2, 3, 4, 5],
                [2, 3, 4, 5, 6]
            ]
            for win in windows {
                if win.intersection(distinctNonWild).count + wildCount >= 5 {
                    return 40
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

        // Let active Bot Opponent(s) play their corresponding frame!
        var latestBotNotes: [String] = []
        for bIdx in bots.indices {
            let note = simulateBotTurn(botIndex: bIdx)
            if !note.isEmpty {
                latestBotNotes.append(note)
            }
        }
        botTurnFeed = latestBotNotes

        for idx in dice.indices {
            dice[idx].isHeld = false
        }
        rollsRemaining = 3
        tacticalNudgesRemaining = (probabilityMode == .mysteriousAxis) ? 1 : 0
        axleBreakerTokens = (probabilityMode == .mysteriousAxis) ? 3 : 0

        if isGameComplete {
            statusBanner = outcomeSummaryBanner
        } else if let firstBotNote = latestBotNotes.first {
            statusBanner = "You scored +\(pts) in \(category.rawValue) • \(firstBotNote)"
        } else {
            statusBanner = "Scored +\(pts) pts in \(category.rawValue)! Tap Roll Cup for next frame."
        }
        return true
    }

    // MARK: - Bot Opponent AI (`🐢 TurtLe` & `🤖 Joe SmoLLey`)

    private func simulateBotTurn(botIndex: Int) -> String {
        let cats = activeCategories.filter { bots[botIndex].lockedScores[$0] == nil }
        guard !cats.isEmpty else { return "" }
        let isPro = (bots[botIndex].personality == .grandmasterSmolley)
        let maxFace = (probabilityMode == .conjugateDuplicate4Faces) ? 4 : 6

        var botOrientations: [DieOrientation] = (0..<5).map { _ in
            .canonical(topPip: rng.nextInt(6) + 1, yawSteps: rng.nextInt(4))
        }
        let archetypes: [ConjugateCubeArchetype] = [.alpha12Doubled, .beta34Doubled, .alpha12Doubled, .beta34Doubled, .alpha12Doubled]

        func vals(for oris: [DieOrientation]) -> [Int] {
            oris.enumerated().map { i, o in
                probabilityMode == .conjugateDuplicate4Faces ? archetypes[i].mappedFourNumber(forRawPip: o.top) : o.top
            }
        }

        // Rolls 2 & 3: Bot selects smart holds
        for _ in 0..<2 {
            let currentVals = vals(for: botOrientations)
            let heldMask = chooseBotHolds(values: currentVals, openCategories: cats, maxFace: maxFace, isPro: isPro)
            if heldMask.allSatisfy({ $0 }) { break }
            for i in 0..<5 where !heldMask[i] {
                botOrientations[i] = .canonical(topPip: rng.nextInt(6) + 1, yawSteps: rng.nextInt(4))
            }
        }

        var finalVals = vals(for: botOrientations)
        var specialMoveTag = ""

        // In AxLe 3D mode, Joe SmoLLey Bot (and occasionally TurtLe Bot) uses a 3D Tumble / ◇120° Corner / ⟳180° Twist!
        if probabilityMode == .mysteriousAxis && (isPro || rng.nextInt(2) == 0) {
            let baseEval = chooseBestBotCategory(values: finalVals, openCategories: cats, bot: bots[botIndex], isPro: isPro)
            var bestUpgrade: (eval: Double, vals: [Int], tag: String)? = nil

            for i in 0..<5 {
                let o = botOrientations[i]
                let moves: [(String, DieOrientation)] = [
                    ("90° Tumble", o.tipped(.north)),
                    ("90° Tumble", o.tipped(.east)),
                    ("◇120° Corner", o.spunCorner120()),
                    ("⟳180° Twist", o.twisted180())
                ]
                for (mName, nextO) in moves {
                    var cand = finalVals
                    cand[i] = nextO.top
                    let candEval = chooseBestBotCategory(values: cand, openCategories: cats, bot: bots[botIndex], isPro: isPro)
                    if candEval.utility > baseEval.utility + 5.0 && candEval.utility > (bestUpgrade?.eval ?? -999) {
                        bestUpgrade = (candEval.utility, cand, " via \(mName)")
                    }
                }
            }
            if let up = bestUpgrade {
                finalVals = up.vals
                specialMoveTag = up.tag
            }
        }

        let pick = chooseBestBotCategory(values: finalVals, openCategories: cats, bot: bots[botIndex], isPro: isPro)
        bots[botIndex].lockedScores[pick.category] = pick.rawPoints
        let summary = "\(bots[botIndex].emoji) \(bots[botIndex].displayName): [\(finalVals.map(String.init).joined(separator: ","))] → \(pick.category.rawValue) (+\(pick.rawPoints))\(specialMoveTag)"
        bots[botIndex].lastTurnSummary = summary
        return summary
    }

    private func chooseBotHolds(
        values: [Int],
        openCategories: [AxleYahtzeeCategory],
        maxFace: Int,
        isPro: Bool
    ) -> [Bool] {
        var counts: [Int: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }

        // Pro bot checks 4-to-a-Large-Straight when Large Straight is still open
        if isPro && openCategories.contains(.largeStraight5) {
            for win: Set<Int> in [[1, 2, 3, 4, 5], [2, 3, 4, 5, 6]] {
                let present = win.intersection(values)
                if present.count >= 4 {
                    var used = Set<Int>()
                    return values.map { v in
                        if win.contains(v) && !used.contains(v) {
                            used.insert(v)
                            return true
                        }
                        return false
                    }
                }
            }
        }

        // Hold best multiplicity (preferring higher face values for Upper 63 bonus)
        if let target = (1...maxFace).max(by: { a, b in
            let ca = counts[a, default: 0]
            let cb = counts[b, default: 0]
            return ca != cb ? ca < cb : a < b
        }), (counts[target] ?? 0) >= 2 {
            return values.map { $0 == target }
        }

        // Otherwise hold highest single die >= 4
        if let topVal = values.max(), topVal >= max(3, maxFace - 2) {
            var heldOne = false
            return values.map { v in
                if v == topVal && !heldOne {
                    heldOne = true
                    return true
                }
                return false
            }
        }
        return [false, false, false, false, false]
    }

    private func chooseBestBotCategory(
        values: [Int],
        openCategories: [AxleYahtzeeCategory],
        bot: YahtzeeBotCompetitor,
        isPro: Bool
    ) -> (category: AxleYahtzeeCategory, rawPoints: Int, utility: Double) {
        var best: (AxleYahtzeeCategory, Int, Double)? = nil
        for cat in openCategories {
            let pts = Self.score(category: cat, values: values, mode: probabilityMode, jackWilds: jackPowersEnabled)
            var util = Double(pts)

            if isPro {
                if let face = cat.upperTargetFace {
                    let count = values.filter { $0 == face }.count
                    // Reward >= 3 of an upper rank (on pace for 63 -> +35 bonus!), penalize burning 5s/6s with <= 2
                    if count >= 3 {
                        util += Double(face) * 2.2
                    } else if face >= 4 {
                        util -= Double(face) * 2.5
                    }
                }
                if cat == .axleYahtzee50 && pts == 0 {
                    util -= 14.0
                }
                if cat == .chanceSum && openCategories.count > 4 && pts < 22 {
                    util -= 6.0
                }
            } else {
                // Friendly TurtLe Bot slightly prefers straightforward immediate points
                if cat == .axleYahtzee50 && pts == 0 {
                    util -= 6.0
                }
            }

            if best == nil || util > best!.2 {
                best = (cat, pts, util)
            }
        }
        let fallback = openCategories[0]
        return best ?? (fallback, 0, 0)
    }

    // MARK: - Probability Verification & Recommendations

    public static func conjugatePairPoolProbabilities() -> [Int: Double] {
        let alpha = ConjugateCubeArchetype.alpha12Doubled.sixFaceValues
        let beta = ConjugateCubeArchetype.beta34Doubled.sixFaceValues
        let combined = alpha + beta
        var probs: [Int: Double] = [:]
        for num in 1...4 {
            let hits = combined.filter { $0 == num }.count
            probs[num] = Double(hits) / Double(combined.count)
        }
        return probs
    }

    public var recommendedOpenCategory: (category: AxleYahtzeeCategory, points: Int)? {
        var best: (AxleYahtzeeCategory, Int)? = nil
        for cat in activeCategories where lockedScores[cat] == nil {
            let pts = potentialScore(for: cat)
            if best == nil || pts > best!.1 {
                best = (cat, pts)
            }
        }
        return best
    }
}
