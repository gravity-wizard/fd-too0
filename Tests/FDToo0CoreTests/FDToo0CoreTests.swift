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
}
