//
//  MoonBuggyDriftPhysics.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  z404 Lunar South Pole (89.9°S) M00N Buggy Physics Engine:
//  - `4WD Crawl`: All 4 AxLe-Locked 4-pip dice wheels driven for high-traction crater climbing.
//  - `2-Pip RWD Drift`: Rear 2 wheels lock into [2-5] / 2-Pip Overdrive while front 2 wheels
//    free-caster & counter-steer—unlocking 1.68× top speed, pendulum slip-angle drifts in
//    1.622 m/s² lunar gravity, crater-lip float jumps, and Kapton-gold regolith roostertails!
//

import Foundation
import Observation

public enum BuggyDriveMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case crawl4WD    = "4wd_crawl"
    case drift2PipRWD = "2pip_rwd_drift"

    public var id: String { rawValue }

    public var badgeTitle: String {
        switch self {
        case .crawl4WD:     return "4WD 4-Pip Crawl"
        case .drift2PipRWD: return "2-Pip RWD Drift 🪐"
        }
    }

    public var maxSpeedMps: Double {
        switch self {
        case .crawl4WD:     return 12.8
        case .drift2PipRWD: return 21.5 // 1.68× faster with 2-pip rear drive!
        }
    }

    public var rearAxleLock: AxleLockAxis {
        switch self {
        case .crawl4WD:     return .pin16
        case .drift2PipRWD: return .pin25 // Rear 2-pip drive wheels!
        }
    }

    public var frontAxleLock: AxleLockAxis {
        switch self {
        case .crawl4WD:     return .pin34
        case .drift2PipRWD: return .free24 // Free-castering front drift wheels!
        }
    }
}

public struct BuggyTelemetrySnapshot: Equatable, Sendable {
    public let positionX: Double
    public let positionZ: Double
    public let altitudeY: Double
    public let headingRadians: Double
    public let velocityHeadingRadians: Double
    public let speedMps: Double
    public let slipAngleDegrees: Double
    public let roostertailIntensity: Double
    public let rearWheelSpinRadians: Double
    public let frontWheelSpinRadians: Double
}

@Observable
public final class MoonBuggyArenaEngine {
    public static let lunarGravityMps2: Double = 1.622

    public var driveMode: BuggyDriveMode = .drift2PipRWD
    public var throttleInput: Double = 0.0   // -1.0 ... +1.0
    public var steeringInput: Double = 0.0   // -1.0 (left) ... +1.0 (right)

    public private(set) var posX: Double = 0.0
    public private(set) var posZ: Double = 16.0
    public private(set) var posY: Double = 0.0
    public private(set) var velY: Double = 0.0

    public private(set) var bodyHeading: Double = 0.0     // Chassis nose yaw (radians)
    public private(set) var velocityHeading: Double = 0.0 // Actual travel vector yaw (radians)
    public private(set) var groundSpeed: Double = 0.0

    public private(set) var rearWheelAngle: Double = 0.0
    public private(set) var frontWheelAngle: Double = 0.0
    public private(set) var driftScore: Int = 0
    public private(set) var gatesCleared: Int = 0
    public private(set) var statusReadout: String = "z404 Shackleton Rim • Engage 2-Pip RWD Drift for high-speed roostertails!"

    public init() {}

    /// Slip angle in degrees between chassis nose and actual regolith velocity vector.
    public var slipAngleDegrees: Double {
        guard groundSpeed > 0.6 else { return 0.0 }
        let diff = Self.wrapAngle(bodyHeading - velocityHeading)
        return abs(diff) * 180.0 / .pi
    }

    /// Regolith roostertail plume intensity (`0...1`) driven by rear 2-pip wheelspin + lateral slip!
    public var roostertailIntensity: Double {
        let speedFrac = min(1.0, groundSpeed / driveMode.maxSpeedMps)
        if driveMode == .drift2PipRWD {
            let slipBoost = min(1.0, slipAngleDegrees / 28.0)
            return min(1.0, speedFrac * 0.55 + slipBoost * 0.65)
        } else {
            return speedFrac * 0.22
        }
    }

    /// Procedural Shackleton Rim terrain elevation `y(x, z)` with a central HoLy M00N crater rim!
    public static func terrainHeight(x: Double, z: Double) -> Double {
        let r = (x * x + z * z).squareRoot()
        // Raised Shackleton crater ring around r = 18m, gentle bowl inside
        let rim = 1.35 * exp(-pow((r - 18.0) / 5.2, 2.0))
        let ripples = 0.18 * sin(x * 0.22) * cos(z * 0.22)
        return max(0.0, rim + ripples)
    }

    public func toggleDriveMode() {
        driveMode = (driveMode == .crawl4WD) ? .drift2PipRWD : .crawl4WD
        statusReadout = (driveMode == .drift2PipRWD)
            ? "2-Pip RWD Drift Engaged! Rear [2-5] overdrive + counter-steer slip unlocked."
            : "4WD 4-Pip Crawl Engaged! Maximum crater-wall grip."
    }

    public func triggerLunarCraterHop() {
        let ground = Self.terrainHeight(x: posX, z: posZ)
        guard posY <= ground + 0.15 else { return }
        // In 1.622 m/s² lunar gravity, a 3.4 m/s vertical hop floats for > 4 seconds!
        velY = 3.4
        statusReadout = "Lunar Low-G Hop! Floating at 1.62 m/s² over Shackleton Rim…"
    }

    public func resetToRim() {
        posX = 0.0
        posZ = 18.0
        posY = Self.terrainHeight(x: 0.0, z: 18.0)
        velY = 0.0
        bodyHeading = .pi * 0.5
        velocityHeading = .pi * 0.5
        groundSpeed = 0.0
        driftScore = 0
        gatesCleared = 0
        statusReadout = "Reset at 89.9°S z404 Flagged Rim."
    }

    /// Advances rover physics by `dt` seconds.
    public func step(dt: Double) {
        let clampedDt = max(0.001, min(0.05, dt))
        let maxV = driveMode.maxSpeedMps
        let accelRate = (driveMode == .drift2PipRWD) ? 9.6 : 6.2
        let rollingDrag = (driveMode == .drift2PipRWD) ? 0.55 : 1.15

        // Longitudinal acceleration
        if abs(throttleInput) > 0.02 {
            groundSpeed += throttleInput * accelRate * clampedDt
        } else {
            let sign = groundSpeed >= 0 ? 1.0 : -1.0
            groundSpeed = sign * max(0.0, abs(groundSpeed) - rollingDrag * 3.0 * clampedDt)
        }
        groundSpeed = max(-maxV * 0.45, min(maxV, groundSpeed))

        // Yaw & RWD slip-angle drift vs 4WD high-grip tracking
        let speedFactor = min(1.0, abs(groundSpeed) / 3.5)
        let yawRate = (driveMode == .drift2PipRWD) ? 2.45 : 1.55
        let directionSign = groundSpeed >= -0.05 ? 1.0 : -1.0
        bodyHeading = Self.wrapAngle(bodyHeading + steeringInput * yawRate * speedFactor * directionSign * clampedDt)

        // Lateral tire grip: 4WD snaps velocity vector quickly to chassis nose;
        // 2-Pip RWD Drift lags velocity vector behind chassis yaw -> exhilarating lunar drift!
        let lateralGrip = (driveMode == .drift2PipRWD) ? 2.35 : 9.50
        let angleDiff = Self.wrapAngle(bodyHeading - velocityHeading)
        velocityHeading = Self.wrapAngle(velocityHeading + angleDiff * min(1.0, lateralGrip * clampedDt))

        // Integrate world X/Z within 34m polar test arena
        posX += sin(velocityHeading) * groundSpeed * clampedDt
        posZ += cos(velocityHeading) * groundSpeed * clampedDt
        let radial = (posX * posX + posZ * posZ).squareRoot()
        if radial > 30.0 {
            let scale = 30.0 / radial
            posX *= scale
            posZ *= scale
            groundSpeed *= 0.82
        }

        // Vertical lunar 1.622 m/s² suspension & jump arc
        let floorY = Self.terrainHeight(x: posX, z: posZ)
        if posY > floorY || velY > 0.0 {
            velY -= Self.lunarGravityMps2 * clampedDt
            posY += velY * clampedDt
            if posY <= floorY {
                posY = floorY
                // Soft elastomer bounce
                velY = abs(velY) > 1.1 ? -velY * 0.28 : 0.0
            }
        } else {
            posY = floorY
        }

        // Wheel spin radians: Rear 2-pip wheels spin with extra drift wheelspin in RWD mode!
        let wheelRadius = 0.48
        let rwdOverSpin = (driveMode == .drift2PipRWD && throttleInput > 0.2) ? 1.38 : 1.0
        rearWheelAngle += (groundSpeed * rwdOverSpin / wheelRadius) * clampedDt
        frontWheelAngle += (groundSpeed / wheelRadius) * clampedDt

        // Award drift points when holding a > 10° slip angle at speed!
        if driveMode == .drift2PipRWD && slipAngleDegrees > 10.0 && abs(groundSpeed) > 6.0 {
            driftScore += Int((slipAngleDegrees * abs(groundSpeed) * clampedDt * 0.8).rounded())
        }
    }

    public var snapshot: BuggyTelemetrySnapshot {
        BuggyTelemetrySnapshot(
            positionX: posX,
            positionZ: posZ,
            altitudeY: posY,
            headingRadians: bodyHeading,
            velocityHeadingRadians: velocityHeading,
            speedMps: groundSpeed,
            slipAngleDegrees: slipAngleDegrees,
            roostertailIntensity: roostertailIntensity,
            rearWheelSpinRadians: rearWheelAngle,
            frontWheelSpinRadians: frontWheelAngle
        )
    }

    public static func wrapAngle(_ a: Double) -> Double {
        var r = (a + .pi).truncatingRemainder(dividingBy: 2.0 * .pi)
        if r < 0 { r += 2.0 * .pi }
        return r - .pi
    }
}
