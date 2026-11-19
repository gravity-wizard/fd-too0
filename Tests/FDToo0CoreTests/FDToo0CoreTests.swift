import XCTest
@testable import FDToo0Core

final class FDToo0CoreTests: XCTestCase {
    func testOppositeFacesAlwaysSumToSevenAcrossAllTumbles() {
        for startPip in 1...6 {
            for yaw in 0..<4 {
                var die = DieOrientation.canonical(topPip: startPip, yawSteps: yaw)
                XCTAssertTrue(die.hasValidSumSevenInvariant)

                for dir in TumbleDirection.allCases {
                    let tipped = die.tipped(dir)
                    XCTAssertTrue(tipped.hasValidSumSevenInvariant)
                    // Tipping forward then tipping in the opposite direction restores exact orientation!
                    let restored = tipped.tipped(dir.opposite)
                    XCTAssertEqual(restored, die)
                }

                let twisted = die.twisted180()
                XCTAssertEqual(twisted.top, 7 - die.top)
                XCTAssertTrue(twisted.hasValidSumSevenInvariant)
                XCTAssertEqual(twisted.twisted180(), die)
                die = twisted
            }
        }
    }

    func testAll1023LevelsGenerateDeterministicallyWithOpeningMove() {
        for level in 1...LevelSeedEngine.totalLevels {
            let bp = LevelSeedEngine.buildLevel(level, mode: .fdToo0)
            XCTAssertEqual(bp.levelNumber, level)
            XCTAssertEqual(bp.isBossLevel, (level % 23 == 0) || (level == 1023))

            let engine = GameEngine23(initialMode: .fdToo0, startLevel: level)
            XCTAssertNotNil(engine.computeBestHint(), "Level \(level) must have a guaranteed turn-1 3+ match swipe")
        }
    }

    func testClassicReverseTumbledLevelsGenerateCleanly() {
        for sampleLevel in [1, 7, 23, 100, 500, 1023] {
            let bp = LevelSeedEngine.buildLevel(sampleLevel, mode: .classicFD)
            XCTAssertNotNil(bp.targetHarmonyPip)
            let allDice = bp.initialDice.flatMap { $0 }.compactMap { $0 }
            XCTAssertFalse(allDice.isEmpty)
            XCTAssertTrue(allDice.allSatisfy { $0.orientation.hasValidSumSevenInvariant })
        }
    }

    func testPaceSpeedsAndMultiPhaseWaveChoreography() {
        let syncEngine = GameEngine23(initialMode: .fdToo0, startLevel: 1)
        let phasedEngine = GameEngine23(initialMode: .fdToo0, startLevel: 1)

        syncEngine.paceSpeed = .rabbit
        XCTAssertEqual(syncEngine.paceSpeed.stylizedLabel, "Rabbit 🐇")
        let rabbitPar = syncEngine.effectiveParSeconds

        syncEngine.paceSpeed = .turtle
        XCTAssertEqual(syncEngine.paceSpeed.stylizedLabel, "TurtLe 🐢")
        XCTAssertEqual(syncEngine.effectiveParSeconds, rabbitPar * 2)

        syncEngine.paceSpeed = .snail
        XCTAssertEqual(syncEngine.paceSpeed.stylizedLabel, "SnaiL 🐌")
        XCTAssertEqual(syncEngine.effectiveParSeconds, rabbitPar * 4)

        guard let hint = syncEngine.computeBestHint() else {
            XCTFail("Expected opening hint on level 1")
            return
        }

        XCTAssertTrue(syncEngine.swipeDie(at: hint.from, direction: hint.direction))
        XCTAssertTrue(phasedEngine.beginSwipeTumbleOnly(at: hint.from, direction: hint.direction))
        XCTAssertFalse(phasedEngine.previewNextMatchWave().isEmpty)

        var wave = 1
        while !phasedEngine.previewNextMatchWave().isEmpty && wave <= 20 {
            _ = phasedEngine.commitSingleCascadeWave(waveIndex: wave)
            wave += 1
        }
        phasedEngine.finalizeTurnAfterWaves()

        XCTAssertEqual(phasedEngine.score, syncEngine.score)
        XCTAssertEqual(phasedEngine.diceCleared, syncEngine.diceCleared)
    }

    func testStoryScoreHTOLedgerAndDecode() {
        let engine = GameEngine23(initialMode: .fdToo0, startLevel: 1)
        let mk = { (pip: Int) -> BoardDie in
            BoardDie(id: 1, orientation: .canonical(topPip: pip, yawSteps: 0), pastelHue: .mintSage)
        }

        // Straight 6 on 6x6 -> 41,100
        var g6: [[BoardDie?]] = Array(repeating: Array(repeating: nil, count: 6), count: 6)
        for c in 0..<6 { g6[0][c] = mk(6) }
        let ev6 = engine.evaluateStoryMatches(in: g6)
        XCTAssertEqual(ev6.count, 1)
        XCTAssertEqual(ev6.first?.thousandsBase, 41_000)
        XCTAssertEqual(ev6.first?.storyTail, 100)

        // L-5 intersection -> 10,001 (Pentad, ODD!)
        var gL5: [[BoardDie?]] = Array(repeating: Array(repeating: nil, count: 4), count: 4)
        gL5[0][0] = mk(5); gL5[0][1] = mk(5); gL5[0][2] = mk(5); gL5[1][0] = mk(5); gL5[2][0] = mk(5)
        let evL5 = engine.evaluateStoryMatches(in: gL5)
        XCTAssertEqual(evL5.count, 1)
        XCTAssertEqual((evL5.first?.thousandsBase ?? 0) + (evL5.first?.storyTail ?? 0), 10_001)

        // Decode 64,121 -> [121] = 1x Hexad + 2x Quad + 1x Pentad (ODD!) + 1x Trio
        let decoded = GameEngine23.decodeScoreStory(64_121)
        XCTAssertEqual(decoded.htoString, "121")
        XCTAssertEqual(decoded.hexadsFromHundreds, 1)
        XCTAssertEqual(decoded.quadsFromTens, 2)
        XCTAssertEqual(decoded.pentadsFromOnes, 1)
        XCTAssertTrue(decoded.isOddPentadSignature)
    }

    func testCasinoDieChiralitySixRailsAndPocketPreservation() {
        // Western RH000 chirality: 6 yaw=0 has vertical rails [0,2,3,5,6,8] pointing at 3 & 4 (N/S),
        // while 6 yaw=1 has horizontal rails [0,1,2,6,7,8] pointing at 3 & 4 (E/W).
        let sixVertical = DieOrientation.canonical(topPip: 6, yawSteps: 0)
        XCTAssertEqual(sixVertical.sixRailsVertical, true)
        XCTAssertEqual(sixVertical.topFacePipSlots, [0, 2, 3, 5, 6, 8])
        XCTAssertTrue([3, 4].contains(sixVertical.tipped(.south).top))

        let sixHorizontal = DieOrientation.canonical(topPip: 6, yawSteps: 1)
        XCTAssertEqual(sixHorizontal.sixRailsVertical, false)
        XCTAssertEqual(sixHorizontal.topFacePipSlots, [0, 1, 2, 6, 7, 8])
        XCTAssertTrue([2, 5].contains(sixHorizontal.tipped(.south).top))

        // Verify all 24 canonical states are distinct
        var allStates = Set<DieOrientation>()
        for pip in 1...6 {
            for yaw in 0..<4 {
                allStates.insert(.canonical(topPip: pip, yawSteps: yaw))
            }
        }
        XCTAssertEqual(allStates.count, 24)

        // Verify cascade preserves 1 tactical breathing pocket on 6x5 board
        let engine = GameEngine23(initialMode: .fdToo0, startLevel: 120)
        if let hint = engine.computeBestHint() {
            XCTAssertTrue(engine.swipeDie(at: hint.from, direction: hint.direction))
            let empties = engine.grid.flatMap { $0 }.filter { $0 == nil }.count
            XCTAssertGreaterThanOrEqual(empties, 1)
        }
    }

    func testAll24StatesHaveUnique45DegreeTwistedSignaturesAndExactQuaternions() {
        let all24 = DieOrientation.all24Orientations
        XCTAssertEqual(all24.count, 24)

        var signatures = Set<LearnedDieSignature>()
        for orient in all24 {
            let sig = LearnedGeometryOracle.signature(for: orient)
            signatures.insert(sig)

            // Verify Shepperd O(1) unitQuaternion maps local (+Y=1, +Z=2, +X=3) to exact world normals!
            let q = orient.unitQuaternion
            let w1 = q.rotate(Vec3(0, 1, 0))
            let w2 = q.rotate(Vec3(0, 0, 1))
            let w3 = q.rotate(Vec3(1, 0, 0))

            let e1 = orient.worldNormal(forPip: 1)
            let e2 = orient.worldNormal(forPip: 2)
            let e3 = orient.worldNormal(forPip: 3)

            XCTAssertLessThan((w1 - e1).length, 1e-6)
            XCTAssertLessThan((w2 - e2).length, 1e-6)
            XCTAssertLessThan((w3 - e3).length, 1e-6)
        }
        // Theorem: 6 faces x 4 corner quadrants = 24 unique Top-face appearances!
        XCTAssertEqual(signatures.count, 24)
    }

    func testAxleLockSkewersAndConjugateFourNumberYahtzee() {
        // 1. Conjugate duplicate-face 6-sided cubes {1,1,2,2,3,4} + {3,3,4,4,1,2} -> exact 0.25 per number
        let probs = AxleYahtzeeEngine.conjugatePairPoolProbabilities()
        for num in 1...4 {
            XCTAssertEqual(probs[num] ?? 0.0, 0.25, accuracy: 1e-9)
        }

        // 2. Mysterious-Axis [1-6] locks East/West to 1/6 and cycles {2,3,5,4} cleanly on North/South tips
        var locked = AxleYahtzeeEngine.alignedInitialOrientation(for: .pin16, step: 0)
        XCTAssertFalse(locked.canTip(.east, axleLock: .pin16))
        XCTAssertTrue(locked.canTip(.north, axleLock: .pin16))

        var visitedTops = Set<Int>()
        for _ in 0..<4 {
            visitedTops.insert(locked.top)
            locked = locked.tipped(.north)
        }
        XCTAssertEqual(visitedTops, Set([2, 3, 4, 5]))
        XCTAssertNil(LearnedGeometryOracle.shortestFlipPath(from: locked, toTargetTop: 6, axleLock: .pin16))
        XCTAssertNotNil(LearnedGeometryOracle.shortestFlipPath(from: locked, toTargetTop: 5, axleLock: .pin16))

        // 3. Two-Eyed Jack (Pip 4) acts as Wild toward AxLe Yahtzee 5-of-a-Kind!
        let pts = AxleYahtzeeEngine.evaluatePatternCategory(.axleYahtzee50, values: [2, 2, 2, 4, 4], wildValue: 4)
        XCTAssertEqual(pts, 50)
    }

    func testHolySmolleyPREMTransitCoriolisAndOTECSurplus() {
        let uniformEarth = HolySmolleySimulator.simulateTransit(model: .earthUniformChord, chordDepthFraction: 1.0, vacuumPressurePa: 0.01)
        let premEarth = HolySmolleySimulator.simulateTransit(model: .earthPolarPREM, chordDepthFraction: 1.0, vacuumPressurePa: 0.01)
        let moonDrop = HolySmolleySimulator.simulateTransit(model: .holyMoonZ404, chordDepthFraction: 1.0, vacuumPressurePa: 0.0)
        let eqEarth = HolySmolleySimulator.simulateTransit(model: .earthEquatorial, chordDepthFraction: 1.0, vacuumPressurePa: 0.01)

        // Uniform Earth ~42.2 min vs PREM Earth ~38.2 min vs Moon ~54.2 min
        XCTAssertEqual(uniformEarth.transitMinutes, 42.2, accuracy: 0.5)
        XCTAssertEqual(premEarth.transitMinutes, 38.2, accuracy: 0.5)
        XCTAssertLessThan(premEarth.transitMinutes, uniformEarth.transitMinutes - 3.0)
        XCTAssertEqual(moonDrop.transitMinutes, 54.2, accuracy: 0.5)

        // Polar z404 (89.9°S) has ~500x lower Coriolis wall force than Equatorial core drop!
        XCTAssertLessThan(premEarth.peakCoriolisNewtonsPerKg, 0.01)
        XCTAssertGreaterThan(eqEarth.peakCoriolisNewtonsPerKg, 0.90)

        // OTEC Rankine plant produces positive net megawatts & desalinated freshwater at ΔT = 23.5°C
        let otec = HolySmolleySimulator.evaluateOTEC(OTECPlantConfig(warmSurfaceTempC: 27.5, coldAbyssalTempC: 4.0))
        XCTAssertGreaterThan(otec.netSurplusMW, 2.0)
        XCTAssertGreaterThan(otec.desalinatedFreshwaterLitersPerSec, 100.0)
    }

    func testMoonBuggy2PipRWDDriftExceeds4WDCrawlSpeedAndSlipAngle() {
        let crawlBuggy = MoonBuggyArenaEngine()
        crawlBuggy.driveMode = .crawl4WD
        crawlBuggy.throttleInput = 1.0
        crawlBuggy.steeringInput = 0.75

        let driftBuggy = MoonBuggyArenaEngine()
        driftBuggy.driveMode = .drift2PipRWD
        driftBuggy.throttleInput = 1.0
        driftBuggy.steeringInput = 0.75

        for _ in 0..<240 {
            crawlBuggy.step(dt: 1.0 / 60.0)
            driftBuggy.step(dt: 1.0 / 60.0)
        }

        XCTAssertGreaterThan(driftBuggy.groundSpeed, crawlBuggy.groundSpeed * 1.45)
        XCTAssertGreaterThan(driftBuggy.slipAngleDegrees, crawlBuggy.slipAngleDegrees * 2.0)
        XCTAssertGreaterThan(driftBuggy.roostertailIntensity, crawlBuggy.roostertailIntensity)
    }
}
