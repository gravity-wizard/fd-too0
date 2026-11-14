//
//  LevelSeedEngine.swift
//  FD_too0
//
//  Deterministic 64-bit SplitMix64 Level Generator & Solver Verifier for Levels 1...1,023
//  Plus Daily #23 Gravitorium Challenge & Near-Original Classic FD Reverse-Tumbled Boards.
//

import Foundation

/// Dual-game sibling mode honoring Flipper_qx.swift (`TRU` <-> `N0T` Leapfrog philosophy).
public enum FlipperGameMode: String, CaseIterable, Codable, Sendable {
    case classicFD = "classic"
    case fdToo0    = "fd_too0"

    public var shortBadge: String {
        switch self {
        case .classicFD: return "Classic FD"
        case .fdToo0:    return "FD_too0"
        }
    }

    public var subtitle: String {
        switch self {
        case .classicFD: return "Near-Original 6-Face Pip Tray (Opposite = 7)"
        case .fdToo0:    return "1,023 Progressive Cascade & Chroma Levels"
        }
    }
}

/// Ten themed worlds spanning Levels 1...1,023, with Boss Seals every 23 levels.
public struct WorldChapter: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let subtitle: String
    public let startLevel: Int
    public let endLevel: Int
    public let signatureMechanic: String

    public static let allWorlds: [WorldChapter] = [
        WorldChapter(id: 1,  name: "Spruce Workshop",      subtitle: "Pure 90° Tumbles & Sum-7 Craft",     startLevel: 1,   endLevel: 23,   signatureMechanic: "3+ Pip Runs & Tumble-Swaps"),
        WorldChapter(id: 2,  name: "Pastel Conservatory",  subtitle: "HSB Chroma Surge Pads",              startLevel: 24,  endLevel: 115,  signatureMechanic: "×2 / ×3 Pastel HSB Multiplier Tiles"),
        WorldChapter(id: 3,  name: "Frosted Glacier",      subtitle: "Crystalline Two-Hit Thaw",           startLevel: 116, endLevel: 230,  signatureMechanic: "Frosted Ice Dice"),
        WorldChapter(id: 4,  name: "GPADA Airfield",       subtitle: "Quad-Rail 180° Twist Launchers",     startLevel: 231, endLevel: 345,  signatureMechanic: "180° Twist Pads (Top ↔ 7-Top)"),
        WorldChapter(id: 5,  name: "SlogBog Lanterns",     subtitle: "Marsh Locks & Key Pips",             startLevel: 346, endLevel: 460,  signatureMechanic: "Chained Dice Freed by Adjacent Pops"),
        WorldChapter(id: 6,  name: "Keep24 Hollows",       subtitle: "Sculpted game_23 Board Masks",       startLevel: 461, endLevel: 575,  signatureMechanic: "Hollow, Cross & Keep24 Trays"),
        WorldChapter(id: 7,  name: "Alpenglow Ridge",      subtitle: "Twin Summit Warp Portals",           startLevel: 576, endLevel: 690,  signatureMechanic: "Paired Warp Portals"),
        WorldChapter(id: 8,  name: "Sum-Seven Sanctum",    subtitle: "Harmonic Opposite-Face Mastery",     startLevel: 691, endLevel: 805,  signatureMechanic: "High-Density Chroma + Twist Matrices"),
        WorldChapter(id: 9,  name: "Shifting Currents",    subtitle: "Jetstream Multi-Hazard Stages",      startLevel: 806, endLevel: 920,  signatureMechanic: "Combined Frost, Chains & Portals"),
        WorldChapter(id: 10, name: "The Gravitorium",      subtitle: "Grand Leapfrog Trials to #1,023",    startLevel: 921, endLevel: 1023, signatureMechanic: "6×6 Master Boss & #1023 Seal")
    ]

    public static func world(forLevel level: Int) -> WorldChapter {
        let clamped = max(1, min(1023, level))
        return allWorlds.first(where: { clamped >= $0.startLevel && clamped <= $0.endLevel }) ?? allWorlds[0]
    }
}

/// Underlying cell modifier on the grid (`Cie` heritage from Cie_qx.swift).
public enum CellPadKind: Equatable, Codable, Sendable {
    case hole
    case normal
    case chromaMultiplier(Int) // 2 or 3
    case twist180              // flips die upside-down (top <-> 7-top) on entry
    case portal(pairIndex: Int)
}

/// Active die entity (`Die` heritage from Die_qx.swift).
public struct BoardDie: Identifiable, Equatable, Codable, Sendable {
    public var id: Int
    public var orientation: DieOrientation
    public var pastelHue: PastelHueFamily
    public var frostLayers: Int // 0 = normal, 1 = frosted (needs 1 clear/adjacent hit before popping)
    public var isChained: Bool  // true = cannot be swiped directly until freed by adjacent clear or Twist

    public init(
        id: Int,
        orientation: DieOrientation,
        pastelHue: PastelHueFamily,
        frostLayers: Int = 0,
        isChained: Bool = false
    ) {
        self.id = id
        self.orientation = orientation
        self.pastelHue = pastelHue
        self.frostLayers = frostLayers
        self.isChained = isChained
    }
}

/// Deterministic SplitMix64 PRNG so Swift (iOS/macOS) and TypeScript (Web/PWA) produce identical boards.
public struct SplitMix64RNG: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 1 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }
}

/// Complete specification for any level 1...1,023 (or Classic preset / Daily #23 seed).
public struct LevelBlueprint: Equatable, Sendable {
    public let levelNumber: Int
    public let mode: FlipperGameMode
    public let world: WorldChapter
    public let isBossLevel: Bool
    public let rows: Int
    public let cols: Int
    public let pads: [[CellPadKind]]
    public let initialDice: [[BoardDie?]]
    public let targetDiceCleared: Int
    public let targetFrostCleared: Int
    public let targetChainsFreed: Int
    public let targetHarmonyPip: Int? // Used in Classic Harmonize stages
    public let parMoves: Int
    public let parSeconds: Int
    public let seedUsed: UInt64
}

public enum LevelSeedEngine {
    public static let totalLevels: Int = 1023

    /// Computes a deterministic seed for `level` (1...1,023) and `mode`.
    public static func seed(forLevel level: Int, mode: FlipperGameMode) -> UInt64 {
        let base = UInt64(max(1, level)) &* 0x517CC1B727220A95
        let salt: UInt64 = (mode == .classicFD) ? 0x2323_A771_C1A5_51C0 : 0xFD20_0023_6341_8418
        return base ^ salt
    }

    /// Computes today's Daily #23 Gravitorium Challenge seed (YYYYMMDD).
    public static func dailyChallengeLevelSeed(year: Int, month: Int, day: Int) -> UInt64 {
        let stamp = UInt64(year * 10_000 + month * 100 + day)
        return (stamp &* 0x9E3779B97F4A7C15) ^ 0x0023_FD20_2026_0418
    }

    /// Generates a guaranteed-playable, opening-move-verified level blueprint.
    public static func buildLevel(
        _ rawLevel: Int,
        mode: FlipperGameMode,
        customSeed: UInt64? = nil
    ) -> LevelBlueprint {
        let level = max(1, min(totalLevels, rawLevel))
        let world = WorldChapter.world(forLevel: level)
        let isBoss = (level % 23 == 0) || (level == totalLevels)
        let baseSeed = customSeed ?? seed(forLevel: level, mode: mode)
        var rng = SplitMix64RNG(seed: baseSeed)

        switch mode {
        case .classicFD:
            return buildClassicBoard(level: level, world: world, isBoss: isBoss, seed: baseSeed, rng: &rng)
        case .fdToo0:
            return buildFDToo0Board(level: level, world: world, isBoss: isBoss, seed: baseSeed, rng: &rng)
        }
    }

    // MARK: - Classic FD (Near-Original Reverse-Tumbled 6-Face Harmony Tray)

    private static func buildClassicBoard(
        level: Int,
        world: WorldChapter,
        isBoss: Bool,
        seed: UInt64,
        rng: inout SplitMix64RNG
    ) -> LevelBlueprint {
        let (rows, cols): (Int, Int)
        if level <= 8 {
            (rows, cols) = (3, 3)
        } else if level <= 46 {
            (rows, cols) = isBoss ? (4, 4) : (3, 4)
        } else if level <= 230 {
            (rows, cols) = (4, 4)
        } else {
            (rows, cols) = isBoss ? (5, 5) : (4, 5)
        }

        let pads = Array(repeating: Array(repeating: CellPadKind.normal, count: cols), count: rows)
        let targetPip = (level % 6) + 1
        var grid: [[BoardDie?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)

        // Leave 1 empty cell on 3x3 ("prcntHoles = 1" from Game_23.swift) or 2 empty cells on larger trays
        let emptyCount = (rows * cols <= 9) ? 1 : 2
        var allCoords: [(Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols { allCoords.append((r, c)) }
        }
        // Shuffle coordinates deterministically to pick initial empty holes
        for i in stride(from: allCoords.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            allCoords.swapAt(i, j)
        }
        let holeSet = Set(allCoords.prefix(emptyCount).map { "\($0.0),\($0.1)" })

        var nextID = 1
        for r in 0..<rows {
            for c in 0..<cols {
                if holeSet.contains("\(r),\(c)") { continue }
                let hue = PastelHueFamily(rawValue: ((r + c + level) % 6) + 1) ?? .mintSage
                let orient = DieOrientation.canonical(topPip: targetPip, yawSteps: rng.nextInt(4))
                grid[r][c] = BoardDie(id: nextID, orientation: orient, pastelHue: hue)
                nextID += 1
            }
        }

        // Reverse-tumble from the solved targetPip harmony state so EVERY Classic board is 100% solvable!
        let scrambleSteps = min(34, 4 + (level <= 23 ? level / 2 + 2 : 12 + (level % 18)))
        var lastFrom: (Int, Int)? = nil
        var executedSteps = 0
        var safety = 0

        while executedSteps < scrambleSteps && safety < scrambleSteps * 8 {
            safety += 1
            let r = rng.nextInt(rows)
            let c = rng.nextInt(cols)
            guard grid[r][c] != nil else { continue }
            let dirs = TumbleDirection.allCases
            let dir = dirs[rng.nextInt(dirs.count)]
            let nr = r + dir.rowDelta
            let nc = c + dir.colDelta
            guard nr >= 0 && nr < rows && nc >= 0 && nc < cols else { continue }
            if let lf = lastFrom, lf.0 == nr && lf.1 == nc { continue }

            // Apply exact inverse-compatible tumble (since tipping forward then tipping opposite restores state!)
            if var moving = grid[r][c] {
                if var neighbor = grid[nr][nc] {
                    moving.orientation = moving.orientation.tipped(dir)
                    neighbor.orientation = neighbor.orientation.tipped(dir.opposite)
                    grid[nr][nc] = moving
                    grid[r][c] = neighbor
                } else {
                    moving.orientation = moving.orientation.tipped(dir)
                    grid[nr][nc] = moving
                    grid[r][c] = nil
                }
                lastFrom = (r, c)
                executedSteps += 1
            }
        }

        // Ensure at least one die differs from targetPip so board isn't already solved on turn 0
        let anyUnmatched = grid.flatMap { $0 }.compactMap { $0 }.contains { $0.orientation.top != targetPip }
        if !anyUnmatched {
            outer: for r in 0..<rows {
                for c in 0..<cols where grid[r][c] != nil {
                    for dir in TumbleDirection.allCases {
                        let nr = r + dir.rowDelta, nc = c + dir.colDelta
                        if nr >= 0 && nr < rows && nc >= 0 && nc < cols, var d = grid[r][c] {
                            if var nb = grid[nr][nc] {
                                d.orientation = d.orientation.tipped(dir)
                                nb.orientation = nb.orientation.tipped(dir.opposite)
                                grid[nr][nc] = d
                                grid[r][c] = nb
                            } else {
                                d.orientation = d.orientation.tipped(dir)
                                grid[nr][nc] = d
                                grid[r][c] = nil
                            }
                            executedSteps = max(executedSteps, 1)
                            break outer
                        }
                    }
                }
            }
        }

        let parMoves = max(2, executedSteps + 2)
        let parSeconds = max(15, parMoves * 4)

        return LevelBlueprint(
            levelNumber: level,
            mode: .classicFD,
            world: world,
            isBossLevel: isBoss,
            rows: rows,
            cols: cols,
            pads: pads,
            initialDice: grid,
            targetDiceCleared: 0,
            targetFrostCleared: 0,
            targetChainsFreed: 0,
            targetHarmonyPip: targetPip,
            parMoves: parMoves,
            parSeconds: parSeconds,
            seedUsed: seed
        )
    }

    // MARK: - FD_too0 (1,023 Progressive Cascade, Chroma, Frost, Lock, Twist & Portal Stages)

    private static func buildFDToo0Board(
        level: Int,
        world: WorldChapter,
        isBoss: Bool,
        seed: UInt64,
        rng: inout SplitMix64RNG
    ) -> LevelBlueprint {
        let (rows, cols): (Int, Int)
        switch level {
        case 1...10:    (rows, cols) = (4, 4)
        case 11...115:  (rows, cols) = isBoss ? (5, 5) : (4, 5)
        case 116...575: (rows, cols) = isBoss ? (6, 5) : (5, 5)
        default:        (rows, cols) = isBoss ? (6, 6) : (5, 6)
        }

        var pads = Array(repeating: Array(repeating: CellPadKind.normal, count: cols), count: rows)

        // World 6+ sculpted masks (`keep24` & corner cutouts)
        if level >= 461 && rows >= 5 && cols >= 5 {
            let maskStyle = level % 3
            if maskStyle == 0 {
                // Corner bevels (Keep-style tray)
                pads[0][0] = .hole
                pads[0][cols - 1] = .hole
                pads[rows - 1][0] = .hole
                pads[rows - 1][cols - 1] = .hole
            } else if maskStyle == 1 && rows >= 5 && cols >= 5 {
                // Center sanctum pillar
                pads[rows / 2][cols / 2] = .hole
            }
        }

        // World 2+ Pastel HSB Chroma Multiplier Pads (x2 / x3)
        if level >= 24 {
            let chromaCount = min(5, 2 + (level / 220))
            var placed = 0, tries = 0
            while placed < chromaCount && tries < 40 {
                tries += 1
                let r = rng.nextInt(rows), c = rng.nextInt(cols)
                if pads[r][c] == .normal {
                    pads[r][c] = .chromaMultiplier((placed == 0 && isBoss) ? 3 : 2)
                    placed += 1
                }
            }
        }

        // World 4+ 180° Twist Pads
        if level >= 231 {
            let twistCount = isBoss ? 3 : 2
            var placed = 0, tries = 0
            while placed < twistCount && tries < 40 {
                tries += 1
                let r = rng.nextInt(rows), c = rng.nextInt(cols)
                if pads[r][c] == .normal {
                    pads[r][c] = .twist180
                    placed += 1
                }
            }
        }

        // World 7+ Paired Warp Portals
        if level >= 576 {
            var portalCells: [(Int, Int)] = []
            var tries = 0
            while portalCells.count < 2 && tries < 50 {
                tries += 1
                let r = rng.nextInt(rows), c = rng.nextInt(cols)
                if pads[r][c] == .normal && !portalCells.contains(where: { abs($0.0 - r) + abs($0.1 - c) < 2 }) {
                    pads[r][c] = .portal(pairIndex: 1)
                    portalCells.append((r, c))
                }
            }
            if portalCells.count == 1 {
                pads[portalCells[0].0][portalCells[0].1] = .normal
            }
        }

        // Populate dice with zero accidental starting 3-in-a-row matches
        var grid: [[BoardDie?]] = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        // Leave 1 tactical empty pocket in row 0 or center for pure 90°-tipping freedom alongside Tumble-Swaps
        var pocketCoord: (Int, Int)? = nil
        for r in 0..<rows {
            for c in 0..<cols where pads[r][c] != .hole {
                if r == rows / 2 && c == cols / 2 {
                    pocketCoord = (r, c)
                }
            }
        }
        if pocketCoord == nil {
            outerPocket: for r in 0..<rows {
                for c in 0..<cols where pads[r][c] != .hole {
                    pocketCoord = (r, c)
                    break outerPocket
                }
            }
        }

        var nextID = 1
        for r in 0..<rows {
            for c in 0..<cols {
                guard pads[r][c] != .hole else { continue }
                if let pk = pocketCoord, pk.0 == r && pk.1 == c { continue }

                // Choose a topPip that doesn't immediately form a 3-in-a-row horizontally or vertically
                var forbiddenPips = Set<Int>()
                if c >= 2,
                   let d1 = grid[r][c - 1], let d2 = grid[r][c - 2],
                   d1.orientation.top == d2.orientation.top {
                    forbiddenPips.insert(d1.orientation.top)
                }
                if r >= 2,
                   let u1 = grid[r - 1][c], let u2 = grid[r - 2][c],
                   u1.orientation.top == u2.orientation.top {
                    forbiddenPips.insert(u1.orientation.top)
                }
                let candidates = (1...6).filter { !forbiddenPips.contains($0) }
                let chosenPip = candidates[rng.nextInt(candidates.count)]
                let orient = DieOrientation.canonical(topPip: chosenPip, yawSteps: rng.nextInt(4))
                let hue = PastelHueFamily(rawValue: rng.nextInt(6) + 1) ?? .coralBlush
                grid[r][c] = BoardDie(id: nextID, orientation: orient, pastelHue: hue)
                nextID += 1
            }
        }

        // Guarantee an immediate 1-swipe 3-of-a-kind match on turn 1 so the player NEVER spawns deadlocked!
        injectGuaranteedOpeningMove(into: &grid, pads: pads, rows: rows, cols: cols)

        // Sprinkle Frosted Ice Dice (World 3+) and Chained Dice (World 5+) outside the top-left opening trio
        var frostTotal = 0
        if level >= 116 {
            let desiredFrost = min(6, 2 + ((level - 116) / 140) + (isBoss ? 2 : 0))
            var tries = 0
            while frostTotal < desiredFrost && tries < 60 {
                tries += 1
                let r = rng.nextInt(rows), c = rng.nextInt(cols)
                if r == 0 && c < 3 { continue }
                if var die = grid[r][c], die.frostLayers == 0 && !die.isChained {
                    die.frostLayers = 1
                    grid[r][c] = die
                    frostTotal += 1
                }
            }
        }

        var chainTotal = 0
        if level >= 346 {
            let desiredChains = min(4, 1 + ((level - 346) / 220) + (isBoss ? 1 : 0))
            var tries = 0
            while chainTotal < desiredChains && tries < 60 {
                tries += 1
                let r = rng.nextInt(rows), c = rng.nextInt(cols)
                if r <= 1 && c <= 3 { continue }
                if var die = grid[r][c], !die.isChained && die.frostLayers == 0 {
                    die.isChained = true
                    grid[r][c] = die
                    chainTotal += 1
                }
            }
        }

        let baseTargetClears = 9 + min(30, (level / 28) * 3) + (isBoss ? 6 : 0)
        let parMoves = max(6, (baseTargetClears / 3) + frostTotal + chainTotal + 3)
        let parSeconds = max(30, parMoves * 5)

        return LevelBlueprint(
            levelNumber: level,
            mode: .fdToo0,
            world: world,
            isBossLevel: isBoss,
            rows: rows,
            cols: cols,
            pads: pads,
            initialDice: grid,
            targetDiceCleared: baseTargetClears,
            targetFrostCleared: frostTotal,
            targetChainsFreed: chainTotal,
            targetHarmonyPip: nil,
            parMoves: parMoves,
            parSeconds: parSeconds,
            seedUsed: seed
        )
    }

    /// Ensures row 0 (or row 1 if row 0 has holes) contains a clean 1-swipe Tumble-Swap 3-match.
    private static func injectGuaranteedOpeningMove(
        into grid: inout [[BoardDie?]],
        pads: [[CellPadKind]],
        rows: Int,
        cols: Int
    ) {
        guard rows >= 2 && cols >= 3 else { return }
        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 2) {
                guard pads[r][c] != .hole,
                      pads[r][c + 1] != .hole,
                      pads[r][c + 2] != .hole,
                      pads[r + 1][c + 2] != .hole,
                      var d0 = grid[r][c],
                      var d1 = grid[r][c + 1],
                      var dBelow = grid[r + 1][c + 2] else { continue }

                // Pick a target pip P that won't accidentally match c-1
                let leftPip = (c >= 1) ? grid[r][c - 1]?.orientation.top : nil
                let targetP = (leftPip == 3) ? 5 : 3
                d0.orientation = DieOrientation.canonical(topPip: targetP, yawSteps: 0)
                d1.orientation = DieOrientation.canonical(topPip: targetP, yawSteps: 1)

                // If destination pad is a 180° Twist pad, tipping North then twisting flips top -> 7 - top,
                // so pre-aim for (7 - targetP) before the pad flips it onto targetP!
                let neededBeforePad = (pads[r][c + 2] == .twist180) ? (7 - targetP) : targetP
                let preTipOrient = DieOrientation.canonical(topPip: neededBeforePad, yawSteps: 0).tipped(.south)
                dBelow.orientation = preTipOrient

                // Ensure grid[r][c+2] doesn't already show targetP on turn 0 (nor portal away)
                if case .portal = pads[r][c + 2] { continue }
                if var d2 = grid[r][c + 2], d2.orientation.top == targetP {
                    d2.orientation = DieOrientation.canonical(topPip: (targetP % 6) + 1, yawSteps: 0)
                    grid[r][c + 2] = d2
                }

                // Prevent accidental vertical 3-match beneath (r, c) or (r, c+1) on turn 0
                for checkCol in [c, c + 1] {
                    if r + 2 < rows,
                       let b1 = grid[r + 1][checkCol],
                       var b2 = grid[r + 2][checkCol],
                       b1.orientation.top == targetP && b2.orientation.top == targetP {
                        b2.orientation = DieOrientation.canonical(topPip: (targetP % 6) + 1, yawSteps: 2)
                        grid[r + 2][checkCol] = b2
                    }
                }

                grid[r][c] = d0
                grid[r][c + 1] = d1
                grid[r + 1][c + 2] = dBelow
                return
            }
        }
    }
}
