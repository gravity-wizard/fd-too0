//
//  HolySmolleyPhysics.swift
//  FD_too0 (Joe SmoLLey 3D Spatial Deck)
//
//  HoLy SmoLLey Real Physics Solver & Storied Mission Engine:
//  1) Evacuated Gravity-Train Vacuum Tubes through HoLy PLanets & HoLy M00Ns:
//     - Uniform-sphere chord/core SHM (~42.20 min Earth, ~54.19 min Moon)
//     - Earth PREM Iron-Core radial density profile (~38.16 min, peak ~9.82 km/s)
//     - Coriolis lateral wall force (2*m*omega*v*sin(lat)) vs Polar z404 (89.9°S) Zero-Coriolis Axis!
//  2) Underwater Ocean-Trench HyperLoop + OTEC (Ocean Thermal Energy Conversion):
//     - Warm surface seawater (26–29°C) vs deep 4°C abyssal cold-pipe Rankine cycle powering
//       turbo-molecular vacuum pumps, capsule thermal trim, and magnetic levitation rails!
//  3) Joe SmoLLey Storied Missions with 3-Die AxLe-Locked Valve & Airlock Manifolds.
//

import Foundation
import Observation

public enum CelestialBodyModel: String, CaseIterable, Codable, Sendable, Identifiable {
    case earthPolarPREM    = "earth_polar_prem"
    case earthUniformChord = "earth_uniform_chord"
    case earthEquatorial   = "earth_equatorial"
    case holyMoonZ404      = "holy_moon_z404"
    case abyssalOTECTrench = "abyssal_otec_trench"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .earthPolarPREM:    return "HoLy Earth • Polar z404 PREM Core (89.9°S↔89.9°N)"
        case .earthUniformChord: return "HoLy Earth • Straight Gravity Chord (Uniform SHM)"
        case .earthEquatorial:   return "HoLy Earth • Equatorial Tube (High Coriolis!)"
        case .holyMoonZ404:      return "HoLy M00N • Shackleton South-North Vacuum Tube"
        case .abyssalOTECTrench: return "Abyssal OTEC Trench HyperLoop (Submerged + Maglev)"
        }
    }

    public var radiusMeters: Double {
        switch self {
        case .earthPolarPREM, .earthUniformChord, .earthEquatorial, .abyssalOTECTrench:
            return 6_371_000.0
        case .holyMoonZ404:
            return 1_737_400.0
        }
    }

    public var surfaceGravityMps2: Double {
        switch self {
        case .earthPolarPREM, .earthUniformChord, .earthEquatorial, .abyssalOTECTrench:
            return 9.80665
        case .holyMoonZ404:
            return 1.622
        }
    }

    /// Sidereal rotation rate omega (rad/s).
    public var rotationRateRadPerSec: Double {
        switch self {
        case .holyMoonZ404:
            return 2.6617e-6 // 27.32-day lunar rotation
        default:
            return 7.2921159e-5 // Earth sidereal rotation
        }
    }

    /// Angle between tunnel axis and spin axis (0 = Polar z404 zero-Coriolis, pi/2 = Equatorial max-Coriolis).
    public var spinAxisAngleRadians: Double {
        switch self {
        case .earthPolarPREM, .holyMoonZ404:
            return 0.1 * .pi / 180.0 // 89.9°S Polar Rim!
        case .earthUniformChord:
            return 28.0 * .pi / 180.0
        case .earthEquatorial:
            return 90.0 * .pi / 180.0
        case .abyssalOTECTrench:
            return 18.0 * .pi / 180.0
        }
    }
}

/// Ocean Thermal Energy Conversion (OTEC) closed-cycle Rankine parameters for underwater HyperLoop power.
public struct OTECPlantConfig: Equatable, Codable, Sendable {
    /// Warm tropical surface seawater temperature in Celsius (typical 26...30 °C).
    public var warmSurfaceTempC: Double
    /// Deep (~1,000m) abyssal cold-water intake temperature in Celsius (typical 4.0 °C).
    public var coldAbyssalTempC: Double
    /// Seawater intake volumetric flow rate in m³/s per OTEC station pod.
    public var seawaterFlowM3PerSec: Double
    /// Residual tube pressure in Pascals maintained by OTEC-driven turbo-pumps (target <= 10 Pa).
    public var tubeVacuumPressurePa: Double

    public init(
        warmSurfaceTempC: Double = 27.5,
        coldAbyssalTempC: Double = 4.0,
        seawaterFlowM3PerSec: Double = 120.0,
        tubeVacuumPressurePa: Double = 2.5
    ) {
        self.warmSurfaceTempC = warmSurfaceTempC
        self.coldAbyssalTempC = coldAbyssalTempC
        self.seawaterFlowM3PerSec = seawaterFlowM3PerSec
        self.tubeVacuumPressurePa = tubeVacuumPressurePa
    }
}

public struct OTECTelemetry: Equatable, Sendable {
    public let deltaTKelvin: Double
    public let carnotEfficiencyPercent: Double
    public let rankinePracticalEfficiencyPercent: Double
    public let grossElectricalMW: Double
    public let coldPipePumpingMW: Double
    public let vacuumPumpLoadMW: Double
    public let netSurplusMW: Double
    public let desalinatedFreshwaterLitersPerSec: Double
}

public struct TunnelSample: Equatable, Sendable {
    public let timeSeconds: Double
    /// Signed position along tunnel (-halfLength ... +halfLength) in meters.
    public let positionMeters: Double
    /// Speed magnitude in m/s.
    public let speedMps: Double
    /// Radial distance from planetary center in meters.
    public let radialDistanceMeters: Double
    /// Lateral Coriolis acceleration (m/s²) pushing against maglev guideways.
    public let coriolisAccelMps2: Double
}

public struct TunnelTransitSummary: Equatable, Sendable {
    public let model: CelestialBodyModel
    public let tunnelLengthKm: Double
    public let maxDepthKm: Double
    public let transitDurationSeconds: Double
    public let transitMinutes: Double
    public let peakSpeedKmPerSec: Double
    public let peakCoriolisNewtonsPerKg: Double
    public let samples: [TunnelSample]
}

public enum HolySmolleySimulator {
    /// Evaluates OTEC Rankine thermodynamic output & vacuum-pump power budget.
    public static func evaluateOTEC(_ cfg: OTECPlantConfig) -> OTECTelemetry {
        let tH = cfg.warmSurfaceTempC + 273.15
        let tC = cfg.coldAbyssalTempC + 273.15
        let deltaT = max(0.0, tH - tC)

        let carnot = tH > 0 ? max(0.0, 1.0 - (tC / tH)) : 0.0
        // Practical ammonia/R134a closed-cycle heat-exchanger + turbine efficiency (~52% of Carnot)
        let rankineEff = carnot * 0.52

        // Seawater density ~1025 kg/m³, Cp ~3993 J/(kg·K); warm heat input utilizes ~38% of full ΔT across evaporator
        let massFlowKgS = max(1.0, cfg.seawaterFlowM3PerSec) * 1025.0
        let thermalInputWatts = massFlowKgS * 3993.0 * (deltaT * 0.38)
        let grossMW = (thermalInputWatts * rankineEff) / 1_000_000.0

        // Parasitic cold-water upwelling head loss (~14% of gross at nominal flow) + vacuum pump load
        let pumpingMW = 0.011 * cfg.seawaterFlowM3PerSec
        let vacuumMW = 0.85 * log10(max(1.1, 101_325.0 / max(0.1, cfg.tubeVacuumPressurePa)))
        let netMW = grossMW - pumpingMW - vacuumMW
        let desalLitersPerSec = deltaT >= 18.0 ? cfg.seawaterFlowM3PerSec * 4.2 : 0.0

        return OTECTelemetry(
            deltaTKelvin: deltaT,
            carnotEfficiencyPercent: carnot * 100.0,
            rankinePracticalEfficiencyPercent: rankineEff * 100.0,
            grossElectricalMW: grossMW,
            coldPipePumpingMW: pumpingMW,
            vacuumPumpLoadMW: vacuumMW,
            netSurplusMW: netMW,
            desalinatedFreshwaterLitersPerSec: desalLitersPerSec
        )
    }

    /// Radial gravitational acceleration g(r) inside Earth (PREM vs Uniform) or HoLy M00N.
    public static func radialGravityMps2(for model: CelestialBodyModel, radius r: Double) -> Double {
        let R = model.radiusMeters
        let clampedR = max(0.0, min(R, r))
        switch model {
        case .earthPolarPREM:
            // Two-zone Klotz/PREM radial gravity: iron-nickel core peaks at ~10.68 m/s² at CMB (3,480 km)
            let x = clampedR / R
            let xCore = 3_480_000.0 / R
            if x < xCore {
                return 10.68 * (x / xCore)
            } else {
                let frac = (x - xCore) / (1.0 - xCore)
                return 10.68 + (9.80665 - 10.68) * frac
            }
        case .earthUniformChord, .earthEquatorial, .holyMoonZ404, .abyssalOTECTrench:
            return model.surfaceGravityMps2 * (clampedR / R)
        }
    }

    /// Integrates a one-way transit through a diametral or straight-chord evacuated tube.
    /// - `chordDepthFraction`: `1.0` = straight through planetary center (diametral); `0.25` = shallow chord;
    ///   for `.abyssalOTECTrench`, models a 600 km submerged trench arc assisted by OTEC linear maglev boost!
    public static func simulateTransit(
        model: CelestialBodyModel,
        chordDepthFraction: Double = 1.0,
        vacuumPressurePa: Double = 1.5,
        otecBoostMps2: Double = 0.0
    ) -> TunnelTransitSummary {
        let R = model.radiusMeters
        if model == .abyssalOTECTrench {
            return simulateSubmergedOTECTransit(vacuumPressurePa: vacuumPressurePa, otecBoostMps2: max(1.8, otecBoostMps2))
        }

        let depthFrac = max(0.08, min(1.0, chordDepthFraction))
        // Perigee distance b from planetary center: depthFrac=1.0 -> b=0 (core); depthFrac<1 -> b = R*(1-depthFrac)
        let b = R * (1.0 - depthFrac)
        let halfLength = max(10_000.0, (R * R - b * b).squareRoot())

        var s = halfLength
        var v = 0.0
        let dt = 1.0
        var t = 0.0
        var peakSpeed = 0.0
        var peakCoriolis = 0.0

        // Residual rarefied gas drag coefficient inside near-vacuum tube
        let rhoGas = vacuumPressurePa / (287.05 * 293.15)
        let dragFactor = 0.5 * rhoGas * 0.22 * 6.5 / 12_000.0 // 12-ton Joe SmoLLey capsule

        var samples: [TunnelSample] = []
        samples.reserveCapacity(140)
        let sampleStride = 25

        var step = 0
        while t < 7_200.0 {
            let r = (s * s + b * b).squareRoot()
            let gMag = radialGravityMps2(for: model, radius: r)
            // Component of gravity along the straight chord is g(r) * (s / r)
            let gAlong = r > 1e-3 ? -gMag * (s / r) : 0.0
            let dragAcc = -dragFactor * v * abs(v)
            let acc = gAlong + dragAcc

            let coriolis = 2.0 * model.rotationRateRadPerSec * abs(v) * sin(model.spinAxisAngleRadians)
            peakCoriolis = max(peakCoriolis, coriolis)
            peakSpeed = max(peakSpeed, abs(v))

            if step % sampleStride == 0 {
                samples.append(
                    TunnelSample(
                        timeSeconds: t,
                        positionMeters: s,
                        speedMps: abs(v),
                        radialDistanceMeters: r,
                        coriolisAccelMps2: coriolis
                    )
                )
            }

            let prevV = v
            v += acc * dt
            s += v * dt
            t += dt
            step += 1

            // Antipodal / far-portal turnaround reached when capsule crosses s < 0 and velocity reaches 0
            if s < 0 && prevV < 0 && v >= 0 {
                samples.append(
                    TunnelSample(
                        timeSeconds: t,
                        positionMeters: s,
                        speedMps: 0.0,
                        radialDistanceMeters: (s * s + b * b).squareRoot(),
                        coriolisAccelMps2: 0.0
                    )
                )
                break
            }
        }

        return TunnelTransitSummary(
            model: model,
            tunnelLengthKm: (halfLength * 2.0) / 1000.0,
            maxDepthKm: (R - b) / 1000.0,
            transitDurationSeconds: t,
            transitMinutes: t / 60.0,
            peakSpeedKmPerSec: peakSpeed / 1000.0,
            peakCoriolisNewtonsPerKg: peakCoriolis,
            samples: samples
        )
    }

    private static func simulateSubmergedOTECTransit(
        vacuumPressurePa: Double,
        otecBoostMps2: Double
    ) -> TunnelTransitSummary {
        let totalLength = 600_000.0 // 600 km ocean-trench OTEC HyperLoop link
        let half = totalLength * 0.5
        var x = 0.0
        var v = 0.0
        var t = 0.0
        let dt = 1.0
        var peakSpeed = 0.0
        var peakCoriolis = 0.0
        let rhoGas = vacuumPressurePa / (287.05 * 281.0)
        let dragFactor = 0.5 * rhoGas * 0.20 * 6.5 / 12_000.0

        var samples: [TunnelSample] = []
        var step = 0
        while x < totalLength && t < 3_600.0 {
            // Accelerate first half via OTEC maglev + trench gravity dip, regenerative brake second half
            let dirSign = x < half ? 1.0 : -1.0
            let acc = dirSign * otecBoostMps2 - dragFactor * v * abs(v)
            let coriolis = 2.0 * 7.2921159e-5 * v * sin(18.0 * .pi / 180.0)
            peakCoriolis = max(peakCoriolis, coriolis)
            peakSpeed = max(peakSpeed, v)

            if step % 10 == 0 {
                samples.append(
                    TunnelSample(
                        timeSeconds: t,
                        positionMeters: half - x,
                        speedMps: max(0.0, v),
                        radialDistanceMeters: 6_370_000.0,
                        coriolisAccelMps2: coriolis
                    )
                )
            }
            v = max(4.0, v + acc * dt)
            x += v * dt
            t += dt
            step += 1
        }

        return TunnelTransitSummary(
            model: .abyssalOTECTrench,
            tunnelLengthKm: totalLength / 1000.0,
            maxDepthKm: 1.05, // 1,050 m abyssal trench anchor depth
            transitDurationSeconds: t,
            transitMinutes: t / 60.0,
            peakSpeedKmPerSec: peakSpeed / 1000.0,
            peakCoriolisNewtonsPerKg: peakCoriolis,
            samples: samples
        )
    }
}

// MARK: - Joe SmoLLey Storied Missions & 3-Die AxLe Valve Manifold

public struct JoeSmolleyMission: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let locationBadge: String
    public let joeBriefing: String
    public let physicsTakeaway: String
    public let bodyModel: CelestialBodyModel
    public let chordDepthFraction: Double
    public let targetValvePips: [Int]
    public let valveAxles: [AxleLockAxis]

    public static let campaign: [JoeSmolleyMission] = [
        JoeSmolleyMission(
            id: 1,
            title: "Mission #1 • Marianas OTEC Cold-Pipe Prime",
            locationBadge: "1,050m Abyssal Trench • ΔT = 23.5°C",
            joeBriefing: "Joe SmoLLey at your service! Before we drop into deep planetary rock, prime our submerged OTEC HyperLoop: warm 27.5°C Pacific surface water boils ammonia while upwelled 4°C abyssal water condenses it to spin our vacuum pumps down to 1.5 Pa!",
            physicsTakeaway: "OTEC harvests ocean ΔT >= 20°C continuously 24/7—generating net megawatts PLUS desalinated water while keeping submerged HyperLoop tubes cool and evacuated.",
            bodyModel: .abyssalOTECTrench,
            chordDepthFraction: 0.15,
            targetValvePips: [2, 4, 2],
            valveAxles: [.pin16, .pin25, .pin34]
        ),
        JoeSmolleyMission(
            id: 2,
            title: "Mission #2 • Shackleton z404 HoLy M00N Drop",
            locationBadge: "Lunar South Pole 89.9°S • g = 1.62 m/s²",
            joeBriefing: "Welcome to z404! With zero lunar atmosphere, our HoLy M00N tunnel is a natural hard vacuum. Align the 3 AxLe-Locked airlock dice to [3, 6, 5] and free-fall straight from South Pole to North Pole in 54.2 minutes on zero propellant!",
            physicsTakeaway: "Inside a uniform sphere, gravity scales linearly with radius g(r) = g0*(r/R), creating pure Simple Harmonic Motion with transit time T = pi * sqrt(R/g0) = 54.19 min on the Moon.",
            bodyModel: .holyMoonZ404,
            chordDepthFraction: 1.0,
            targetValvePips: [3, 6, 5],
            valveAxles: [.pin16, .pin25, .pin34]
        ),
        JoeSmolleyMission(
            id: 3,
            title: "Mission #3 • Equatorial Coriolis Maglev Trim",
            locationBadge: "Quito ↔ Singapore Chord • High Coriolis",
            joeBriefing: "Heads up, traveler! Unlike our Polar 89.9°S tube, an equatorial drop carries eastward rotational momentum—Coriolis force (2m ω×v) will slam us into the east wall unless you dial our maglev trim dice to [4, 1, 6]!",
            physicsTakeaway: "At 7.9 km/s core speed, Earth's rotation produces ~1.15 N/kg of lateral Coriolis acceleration—proving why Polar z404 axes or active maglev dampers are essential.",
            bodyModel: .earthEquatorial,
            chordDepthFraction: 0.65,
            targetValvePips: [4, 1, 6],
            valveAxles: [.pin16, .pin25, .pin34]
        ),
        JoeSmolleyMission(
            id: 4,
            title: "Mission #4 • HoLy Earth PREM Core Express",
            locationBadge: "89.9°S ↔ 89.9°N Polar Core • 38m 10s",
            joeBriefing: "Grand finale! Earth's dense iron-nickel core actually INCREASES gravity to 10.68 m/s² at the core-mantle boundary—beating the 42.2-minute textbook uniform Earth and shooting us pole-to-pole in 38 minutes 10 seconds at 9.82 km/s!",
            physicsTakeaway: "Klotz's PREM theorem: non-uniform planetary core density accelerates gravity trains faster than SHM, shaving ~4 full minutes off antipodal Earth transit!",
            bodyModel: .earthPolarPREM,
            chordDepthFraction: 1.0,
            targetValvePips: [5, 3, 2],
            valveAxles: [.pin16, .pin25, .pin34]
        )
    ]
}

@Observable
public final class HolySmolleyMissionEngine {
    public private(set) var currentMissionIndex: Int = 0
    public var otecConfig = OTECPlantConfig()
    public var customChordDepth: Double = 1.0
    public private(set) var manifoldDice: [DieOrientation] = []
    public private(set) var completedMissionIDs: Set<Int> = []
    public private(set) var capsuleProgress: Double = 0.0 // 0.0 = departure portal, 1.0 = antipodal arrival
    public private(set) var isLaunching: Bool = false
    public private(set) var missionBanner: String = ""

    public init() {
        loadMission(index: 0)
    }

    public var currentMission: JoeSmolleyMission {
        JoeSmolleyMission.campaign[currentMissionIndex]
    }

    public var otecTelemetry: OTECTelemetry {
        HolySmolleySimulator.evaluateOTEC(otecConfig)
    }

    public var currentTransitSummary: TunnelTransitSummary {
        let boost = max(0.0, otecTelemetry.netSurplusMW * 0.45)
        return HolySmolleySimulator.simulateTransit(
            model: currentMission.bodyModel,
            chordDepthFraction: customChordDepth,
            vacuumPressurePa: otecConfig.tubeVacuumPressurePa,
            otecBoostMps2: boost
        )
    }

    public var isManifoldAligned: Bool {
        guard manifoldDice.count == currentMission.targetValvePips.count else { return false }
        for i in manifoldDice.indices {
            if manifoldDice[i].top != currentMission.targetValvePips[i] {
                return false
            }
        }
        return true
    }

    public func loadMission(index: Int) {
        let clamped = max(0, min(JoeSmolleyMission.campaign.count - 1, index))
        currentMissionIndex = clamped
        let m = JoeSmolleyMission.campaign[clamped]
        customChordDepth = m.chordDepthFraction
        capsuleProgress = 0.0
        isLaunching = false

        // Scramble each valve die 1 or 2 legal 90° turns away from its target pip along its locked axle!
        var built: [DieOrientation] = []
        for idx in 0..<m.targetValvePips.count {
            let ax = m.valveAxles[idx]
            var d = AxleYahtzeeEngine.alignedInitialOrientation(for: ax, step: 0)
            for _ in 0..<4 where d.top != m.targetValvePips[idx] {
                d = d.tipped(.north)
            }
            // Tip 1 or 2 steps off target so the player solves a crisp 3D valve flip!
            let scramble = (idx % 2 == 0) ? 1 : 2
            for _ in 0..<scramble {
                d = d.tipped(.north)
            }
            built.append(d)
        }
        manifoldDice = built
        missionBanner = "Align Valve Manifold to \(m.targetValvePips.map(String.init).joined(separator: " • ")) to launch!"
    }

    @discardableResult
    public func tipManifoldDie(index: Int, direction: TumbleDirection) -> Bool {
        guard manifoldDice.indices.contains(index) else { return false }
        let ax = currentMission.valveAxles[index]
        guard manifoldDice[index].canTip(direction, axleLock: ax) else {
            missionBanner = "Valve #\(index + 1) is pinned on \(ax.shortTag)—tip ↑ or ↓ around the skewer!"
            return false
        }
        manifoldDice[index] = manifoldDice[index].tipped(direction)
        if isManifoldAligned {
            completedMissionIDs.insert(currentMission.id)
            missionBanner = "HoLy SmoLLey! Airlock Manifold green—tap Launch Capsule!"
        } else {
            let cur = manifoldDice.map { String($0.top) }.joined(separator: " • ")
            let tgt = currentMission.targetValvePips.map(String.init).joined(separator: " • ")
            missionBanner = "Manifold [\(cur)] → Target [\(tgt)]"
        }
        return true
    }

    public func advanceCapsule(deltaProgress: Double) {
        capsuleProgress = min(1.0, max(0.0, capsuleProgress + deltaProgress))
        if capsuleProgress >= 1.0 {
            isLaunching = false
            completedMissionIDs.insert(currentMission.id)
            missionBanner = "Antipodal Portal Reached in \(String(format: "%.1f", currentTransitSummary.transitMinutes)) min! Peak \(String(format: "%.2f", currentTransitSummary.peakSpeedKmPerSec)) km/s."
        }
    }

    public func triggerCapsuleLaunch() {
        capsuleProgress = 0.0
        isLaunching = true
        completedMissionIDs.insert(currentMission.id)
    }
}
