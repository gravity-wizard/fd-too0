//
//  GameEngine23.swift
//  FD_too0
//
//  Observable Game State Machine honoring Game_23.swift & Flipper_qx.swift.
//  Supports live Flipper toggle (Classic FD <-> FD_too0), 90° Tumble & Tumble-Swap,
//  Chain Cascades, Pastel HSB Chroma Multipliers, Undo (h1moves), and 1-Move Solver Hints.
//

import Foundation
import Observation

public struct GridCoord: Equatable, Hashable, Codable, Sendable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }
}

public struct SuggestedHint: Equatable, Sendable {
    public let from: GridCoord
    public let direction: TumbleDirection
    public let rationale: String
}

public struct MoveSnapshot: Sendable {
    public let grid: [[BoardDie?]]
    public let moves: Int
    public let score: Int
    public let diceCleared: Int
    public let frostCleared: Int
    public let chainsFreed: Int
    public let twistCharges: Int
    public let bestChain: Int
}

@Observable
public final class GameEngine23 {
    public private(set) var mode: FlipperGameMode = .fdToo0
    public private(set) var currentLevel: Int = 1
    public private(set) var blueprint: LevelBlueprint
    public private(set) var grid: [[BoardDie?]]

    // ScoreSlat telemetry (Game_23.swift heritage)
    public private(set) var moves: Int = 0
    public private(set) var elapsedSeconds: Int = 0
    public private(set) var score: Int = 0
    public private(set) var diceCleared: Int = 0
    public private(set) var frostCleared: Int = 0
    public private(set) var chainsFreed: Int = 0
    public private(set) var currentChain: Int = 0
    public private(set) var bestChain: Int = 0
    public private(set) var twistCharges: Int = 1
    public private(set) var isWon: Bool = false
    public private(set) var lastBanner: String = "Swipe any die ↑ ↓ ← → to 90°-tumble (Opposite faces = 7)"
    public private(set) var activeHint: SuggestedHint? = nil

    public var selectedCoord: GridCoord? = nil
    public var twistArmed: Bool = false
    public var appearanceMode: BoardAppearanceMode = .dark

    // Persistent progression
    public private(set) var unlockedFDToo0Level: Int = 1
    public private(set) var starsByLevel: [Int: Int] = [:]

    private var h1moves: [MoveSnapshot] = []
    private var nextSpawnID: Int = 10_000
    private var spawnRNG: SplitMix64RNG

    public init(initialMode: FlipperGameMode = .fdToo0, startLevel: Int = 1) {
        let bp = LevelSeedEngine.buildLevel(startLevel, mode: initialMode)
        self.mode = initialMode
        self.currentLevel = startLevel
        self.blueprint = bp
        self.grid = bp.initialDice
        self.spawnRNG = SplitMix64RNG(seed: bp.seedUsed ^ 0xCAFE_BABE_0023_0418)
        loadProgress()
    }

    // MARK: - Live Flipper Toggle (`TRU <-> N0T` from Flipper_qx.swift)

    public func toggleFlipper() {
        let nextMode: FlipperGameMode = (mode == .fdToo0) ? .classicFD : .fdToo0
        load(level: currentLevel, mode: nextMode)
    }

    public func load(level: Int, mode newMode: FlipperGameMode? = nil, customSeed: UInt64? = nil) {
        let targetMode = newMode ?? mode
        let clamped = max(1, min(LevelSeedEngine.totalLevels, level))
        let bp = LevelSeedEngine.buildLevel(clamped, mode: targetMode, customSeed: customSeed)

        self.mode = targetMode
        self.currentLevel = clamped
        self.blueprint = bp
        self.grid = bp.initialDice
        self.moves = 0
        self.elapsedSeconds = 0
        self.score = 0
        self.diceCleared = 0
        self.frostCleared = 0
        self.chainsFreed = 0
        self.currentChain = 0
        self.bestChain = 0
        self.twistCharges = (targetMode == .fdToo0) ? 2 : 1
        self.isWon = false
        self.selectedCoord = nil
        self.twistArmed = false
        self.activeHint = nil
        self.h1moves.removeAll()
        self.spawnRNG = SplitMix64RNG(seed: bp.seedUsed ^ 0xCAFE_BABE_0023_0418)

        if targetMode == .classicFD, let targetPip = bp.targetHarmonyPip {
            self.lastBanner = "Classic FD #\(clamped): Tumble every die so all top faces show \(targetPip)!"
        } else {
            self.lastBanner = "\(bp.world.name) • Lv \(clamped): Clear \(bp.targetDiceCleared) dice via 3+ matching top pips!"
        }
    }

    public func tickSecond() {
        guard !isWon else { return }
        elapsedSeconds += 1
    }

    // MARK: - Undo (`h1moves`) & 180° Twist Charge

    public var canUndo: Bool { !h1moves.isEmpty && !isWon }

    public func undoLastMove() {
        guard let snap = h1moves.popLast() else { return }
        grid = snap.grid
        moves = snap.moves
        score = snap.score
        diceCleared = snap.diceCleared
        frostCleared = snap.frostCleared
        chainsFreed = snap.chainsFreed
        twistCharges = snap.twistCharges
        bestChain = snap.bestChain
        isWon = false
        activeHint = nil
        lastBanner = "Move undone (\(moves) moves)."
    }

    @discardableResult
    public func applyTwist180(at coord: GridCoord) -> Bool {
        guard !isWon, twistCharges > 0,
              isInside(coord),
              var die = grid[coord.row][coord.col] else { return false }

        pushUndoSnapshot()
        twistCharges -= 1
        twistArmed = false
        moves += 1
        if die.isChained {
            die.isChained = false
            chainsFreed += 1
        }
        die.orientation = die.orientation.twisted180()
        grid[coord.row][coord.col] = die
        lastBanner = "180° Twist! Top flipped to \(die.orientation.top) (Sum-7 pair)."

        if mode == .fdToo0 {
            resolveFDToo0Cascades()
        } else {
            evaluateClassicVictory()
        }
        return true
    }

    // MARK: - Core 90° Tumble & Tumble-Swap Execution

    @discardableResult
    public func swipeDie(at from: GridCoord, direction: TumbleDirection) -> Bool {
        guard !isWon, isInside(from),
              var movingDie = grid[from.row][from.col] else { return false }

        if movingDie.isChained {
            lastBanner = "Chained die! Clear an adjacent match or use a 180° Twist to free it."
            return false
        }

        let to = GridCoord(from.row + direction.rowDelta, from.col + direction.colDelta)
        guard isInside(to), blueprint.pads[to.row][to.col] != .hole else { return false }

        if let targetDie = grid[to.row][to.col], targetDie.isChained {
            lastBanner = "Target slot has a Chained die—clear adjacent dice first!"
            return false
        }

        pushUndoSnapshot()
        activeHint = nil
        selectedCoord = nil
        moves += 1

        // Perform 90-degree physical tip
        movingDie.orientation = movingDie.orientation.tipped(direction)

        if var neighbor = grid[to.row][to.col] {
            neighbor.orientation = neighbor.orientation.tipped(direction.opposite)
            applyPadEffects(to: &movingDie, at: to)
            applyPadEffects(to: &neighbor, at: from)
            grid[to.row][to.col] = movingDie
            grid[from.row][from.col] = neighbor
        } else {
            applyPadEffects(to: &movingDie, at: to)
            grid[to.row][to.col] = movingDie
            grid[from.row][from.col] = nil
        }

        // Handle Paired Warp Portals if `to` is a portal and partner slot is empty
        if case .portal(let pairID) = blueprint.pads[to.row][to.col],
           let exitCoord = findPartnerPortal(for: to, pairID: pairID),
           grid[exitCoord.row][exitCoord.col] == nil,
           let arrived = grid[to.row][to.col] {
            grid[exitCoord.row][exitCoord.col] = arrived
            grid[to.row][to.col] = nil
            lastBanner = "Warp Portal! Die tumbled across the ridge to (\(exitCoord.row + 1), \(exitCoord.col + 1))."
        }

        if mode == .classicFD {
            evaluateClassicVictory()
        } else {
            resolveFDToo0Cascades()
        }
        return true
    }

    // MARK: - Cascade & Chroma Resolution (`FD_too0`)

    private func resolveFDToo0Cascades() {
        var chainStep = 0
        var totalPoppedThisTurn = 0
        var triggeredChromaSurge = false

        while true {
            let matchGroups = findThreePlusPipMatches(in: grid)
            if matchGroups.isEmpty { break }

            chainStep += 1
            bestChain = max(bestChain, chainStep)

            var coordsToClear = Set<GridCoord>()
            var frostThawedCoords = Set<GridCoord>()
            var padMultiplier = 1

            for group in matchGroups {
                // Check if all dice in this 3+ run also share the SAME Pastel HSB body family -> Chroma Surge!
                let hues = Set(group.compactMap { grid[$0.row][$0.col]?.pastelHue })
                if hues.count == 1 {
                    triggeredChromaSurge = true
                    padMultiplier = max(padMultiplier, 3)
                }

                for coord in group {
                    if case .chromaMultiplier(let m) = blueprint.pads[coord.row][coord.col] {
                        padMultiplier = max(padMultiplier, m)
                    }
                    if let d = grid[coord.row][coord.col], d.frostLayers > 0 {
                        frostThawedCoords.insert(coord)
                    } else {
                        coordsToClear.insert(coord)
                    }
                }
            }

            // Free any Chained dice or Frost adjacent to cleared coordinates
            let allAffected = coordsToClear.union(frostThawedCoords)
            for coord in allAffected {
                for dir in TumbleDirection.allCases {
                    let adj = GridCoord(coord.row + dir.rowDelta, coord.col + dir.colDelta)
                    guard isInside(adj), var adjDie = grid[adj.row][adj.col] else { continue }
                    if adjDie.isChained {
                        adjDie.isChained = false
                        grid[adj.row][adj.col] = adjDie
                        chainsFreed += 1
                    }
                }
            }

            for coord in frostThawedCoords {
                if var d = grid[coord.row][coord.col] {
                    d.frostLayers = max(0, d.frostLayers - 1)
                    grid[coord.row][coord.col] = d
                    frostCleared += 1
                }
            }

            for coord in coordsToClear {
                grid[coord.row][coord.col] = nil
            }

            let clearedNow = coordsToClear.count + frostThawedCoords.count
            totalPoppedThisTurn += coordsToClear.count
            diceCleared += coordsToClear.count
            score += clearedNow * 100 * chainStep * padMultiplier

            if triggeredChromaSurge && chainStep == 1 {
                twistCharges = min(5, twistCharges + 1)
            }

            applyGravityAndRefill()
        }

        currentChain = chainStep
        if chainStep > 0 {
            let surgeNote = triggeredChromaSurge ? " ✦ PASTEL CHROMA SURGE (+1 Twist)!" : ""
            let chainNote = chainStep > 1 ? " • Chain ×\(chainStep)!" : ""
            lastBanner = "Cleared \(totalPoppedThisTurn) dice\(chainNote)\(surgeNote)"
        }

        // Check stage win goals
        if diceCleared >= blueprint.targetDiceCleared
            && frostCleared >= blueprint.targetFrostCleared
            && chainsFreed >= blueprint.targetChainsFreed {
            completeStageWin()
            return
        }

        // Live anti-deadlock guardian: if no 1-swipe match exists, harmonize one pair subtly or grant a Twist charge
        if computeBestHint() == nil && twistCharges == 0 {
            twistCharges = 1
            lastBanner = "Gravitorium Resonance granted +1 Twist Charge (180° flip)!"
        }
    }

    private func applyGravityAndRefill() {
        let rows = blueprint.rows
        let cols = blueprint.cols

        // Leave at most 1 breathing pocket if blueprint started with one
        for c in 0..<cols {
            var writeRow = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if blueprint.pads[r][c] == .hole {
                    if writeRow == r { writeRow -= 1 }
                    continue
                }
                if let die = grid[r][c] {
                    while writeRow >= 0 && blueprint.pads[writeRow][c] == .hole {
                        writeRow -= 1
                    }
                    if writeRow != r && writeRow >= 0 {
                        grid[writeRow][c] = die
                        grid[r][c] = nil
                    }
                    writeRow -= 1
                }
            }

            // Spawn fresh Pastel HSB dice in remaining top slots (keeping 1 center tactical pocket open if desired)
            while writeRow >= 0 {
                if blueprint.pads[writeRow][c] != .hole {
                    let isCenterPocket = (writeRow == 0 && c == cols / 2 && countEmptyPlayableSlots() <= 1)
                    if !isCenterPocket {
                        let pip = spawnRNG.nextInt(6) + 1
                        let yaw = spawnRNG.nextInt(4)
                        let hue = PastelHueFamily(rawValue: spawnRNG.nextInt(6) + 1) ?? .mintSage
                        nextSpawnID += 1
                        grid[writeRow][c] = BoardDie(
                            id: nextSpawnID,
                            orientation: .canonical(topPip: pip, yawSteps: yaw),
                            pastelHue: hue
                        )
                    }
                }
                writeRow -= 1
            }
        }
    }

    private func countEmptyPlayableSlots() -> Int {
        var empties = 0
        for r in 0..<blueprint.rows {
            for c in 0..<blueprint.cols where blueprint.pads[r][c] != .hole && grid[r][c] == nil {
                empties += 1
            }
        }
        return empties
    }

    // MARK: - Classic FD Victory Check

    private func evaluateClassicVictory() {
        guard let targetPip = blueprint.targetHarmonyPip else { return }
        let allDice = grid.flatMap { $0 }.compactMap { $0 }
        let matchedCount = allDice.filter { $0.orientation.top == targetPip }.count
        lastBanner = "Classic Harmony: \(matchedCount)/\(allDice.count) dice showing \(targetPip)."
        if matchedCount == allDice.count && !allDice.isEmpty {
            score = max(500, 2_500 - moves * 45)
            completeStageWin()
        }
    }

    private func completeStageWin() {
        isWon = true
        let stars = earnedStars
        if mode == .fdToo0 {
            let prev = starsByLevel[currentLevel] ?? 0
            starsByLevel[currentLevel] = max(prev, stars)
            if currentLevel >= unlockedFDToo0Level && currentLevel < LevelSeedEngine.totalLevels {
                unlockedFDToo0Level = currentLevel + 1
            }
            saveProgress()
        }
        lastBanner = "Stage #\(currentLevel) Cleared! \(String(repeating: "★", count: stars)) (\(moves) moves, \(elapsedSeconds)s)"
    }

    public var earnedStars: Int {
        if moves <= blueprint.parMoves && elapsedSeconds <= blueprint.parSeconds {
            return 3
        } else if moves <= Int(Double(blueprint.parMoves) * 1.45) {
            return 2
        }
        return 1
    }

    // MARK: - 1-Swipe Lookahead Hint Solver

    @discardableResult
    public func requestHint() -> SuggestedHint? {
        let hint = computeBestHint()
        activeHint = hint
        if let h = hint {
            lastBanner = "Hint: Swipe die at (\(h.from.row + 1), \(h.from.col + 1)) \(h.direction.arrowGlyph) — \(h.rationale)"
        } else {
            lastBanner = "Tip: Use a 180° Twist or tumble toward matching pips!"
        }
        return hint
    }

    public func computeBestHint() -> SuggestedHint? {
        let rows = blueprint.rows, cols = blueprint.cols
        var bestScore = -1
        var bestHint: SuggestedHint? = nil

        for r in 0..<rows {
            for c in 0..<cols {
                guard let die = grid[r][c], !die.isChained else { continue }
                for dir in TumbleDirection.allCases {
                    let nr = r + dir.rowDelta, nc = c + dir.colDelta
                    guard nr >= 0 && nr < rows && nc >= 0 && nc < cols,
                          blueprint.pads[nr][nc] != .hole else { continue }
                    if let nb = grid[nr][nc], nb.isChained { continue }

                    var sim = grid
                    var moved = die
                    moved.orientation = moved.orientation.tipped(dir)
                    if var nb = sim[nr][nc] {
                        nb.orientation = nb.orientation.tipped(dir.opposite)
                        applyPadEffects(to: &moved, at: GridCoord(nr, nc))
                        applyPadEffects(to: &nb, at: GridCoord(r, c))
                        sim[nr][nc] = moved
                        sim[r][c] = nb
                    } else {
                        applyPadEffects(to: &moved, at: GridCoord(nr, nc))
                        sim[nr][nc] = moved
                        sim[r][c] = nil
                    }

                    if mode == .classicFD, let target = blueprint.targetHarmonyPip {
                        let gain = sim.flatMap { $0 }.compactMap { $0 }.filter { $0.orientation.top == target }.count
                        if gain > bestScore {
                            bestScore = gain
                            bestHint = SuggestedHint(from: GridCoord(r, c), direction: dir, rationale: "aligns top pip \(target)")
                        }
                    } else {
                        let groups = findThreePlusPipMatches(in: sim)
                        let matchedCells = groups.reduce(0) { $0 + $1.count }
                        if matchedCells > 0 && matchedCells > bestScore {
                            bestScore = matchedCells
                            bestHint = SuggestedHint(
                                from: GridCoord(r, c),
                                direction: dir,
                                rationale: "triggers a \(matchedCells)-die match!"
                            )
                        }
                    }
                }
            }
        }
        return bestHint
    }

    // MARK: - Helpers & Persistence

    public func findThreePlusPipMatches(in board: [[BoardDie?]]) -> [[GridCoord]] {
        let rows = board.count
        guard let cols = board.first?.count else { return [] }
        var groups: [[GridCoord]] = []

        // Horizontal runs
        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let d = board[r][c] else { c += 1; continue }
                let pip = d.orientation.top
                var run = [GridCoord(r, c)]
                var k = c + 1
                while k < cols, let next = board[r][k], next.orientation.top == pip {
                    run.append(GridCoord(r, k))
                    k += 1
                }
                if run.count >= 3 { groups.append(run) }
                c = k
            }
        }

        // Vertical runs
        for c in 0..<cols {
            var r = 0
            while r < rows {
                guard let d = board[r][c] else { r += 1; continue }
                let pip = d.orientation.top
                var run = [GridCoord(r, c)]
                var k = r + 1
                while k < rows, let next = board[k][c], next.orientation.top == pip {
                    run.append(GridCoord(k, c))
                    k += 1
                }
                if run.count >= 3 { groups.append(run) }
                r = k
            }
        }

        return groups
    }

    private func applyPadEffects(to die: inout BoardDie, at coord: GridCoord) {
        if case .twist180 = blueprint.pads[coord.row][coord.col] {
            die.orientation = die.orientation.twisted180()
        }
    }

    private func findPartnerPortal(for coord: GridCoord, pairID: Int) -> GridCoord? {
        for r in 0..<blueprint.rows {
            for c in 0..<blueprint.cols {
                if (r != coord.row || c != coord.col),
                   case .portal(let pid) = blueprint.pads[r][c],
                   pid == pairID {
                    return GridCoord(r, c)
                }
            }
        }
        return nil
    }

    private func isInside(_ coord: GridCoord) -> Bool {
        coord.row >= 0 && coord.row < blueprint.rows && coord.col >= 0 && coord.col < blueprint.cols
    }

    private func pushUndoSnapshot() {
        if h1moves.count >= 25 { h1moves.removeFirst() }
        h1moves.append(
            MoveSnapshot(
                grid: grid,
                moves: moves,
                score: score,
                diceCleared: diceCleared,
                frostCleared: frostCleared,
                chainsFreed: chainsFreed,
                twistCharges: twistCharges,
                bestChain: bestChain
            )
        )
    }

    private func saveProgress() {
        let defaults = UserDefaults.standard
        defaults.set(unlockedFDToo0Level, forKey: "gw.fdtoo0.unlockedLevel")
        if let data = try? JSONEncoder().encode(starsByLevel) {
            defaults.set(data, forKey: "gw.fdtoo0.starsByLevel")
        }
    }

    private func loadProgress() {
        let defaults = UserDefaults.standard
        let savedUnlocked = defaults.integer(forKey: "gw.fdtoo0.unlockedLevel")
        if savedUnlocked >= 1 { unlockedFDToo0Level = savedUnlocked }
        if let data = defaults.data(forKey: "gw.fdtoo0.starsByLevel"),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            starsByLevel = decoded
        }
    }
}
