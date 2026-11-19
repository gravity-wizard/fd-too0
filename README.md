# `FD_too0` • Joe SmoLLey 3D Spatial Deck (`A785` Xcode Edition)

**Gravity Wizards, Inc.** (`akapps` / `two3` / `Twisted23` Heritage) — Universal **SwiftUI + SceneKit + Metal + SpriteKit + AVAudioEngine** 3D Spatial Workspace for **macOS 14+, iOS 17+, and iPadOS 17+**, zero external dependencies (`< 2 MB` footprint).

---

## Four Playable 3D Decks in One Universal App

Switch instantaneously across all four **Joe SmoLLey** tables in the top Spatial Deck bar:

1. **🎲 `FLipPing 3D` — `Classic FD` & `FD_too0` (`1,023` Levels in True 3D)**
   - Hardware-accelerated **SceneKit PBR 3D Dice** showing **Top + South + East** simultaneously in Twisted23's signature **3D-in-2D Orthographic** camera (plus live **3D Perspective** and **Classic 2D** toggles).
   - Preserves all `1,023` deterministic SplitMix64 levels, `Rabbit 🐇 / TurtLe 🐢 / SnaiL 🐌` choreography speeds, Pastel HSB Chroma Surges, `180°` Twists, and `1A+2A` H-T-O Story-Score decoding.
2. **🃏 `AxLe Yahtzee` — Mysterious-Axis & Conjugate 4-Number Parlour**
   - **Mysterious-Axis Mode**: Metallic Sum-7 skewers (`[1–6]`, `[2–5]`, `[3–4]`) lock each die onto a 4-face equatorial ring with exact `1/4 = 25%` odds per face.
   - **Physical 4-Number Conjugate Cubes**: Real 6-face cubes carrying only 4 numbers (`Cube α {1,1,2,2,3,4}` + `Cube β {3,3,4,4,1,2}`) engineered so any conjugate pair yields exact `3/12 = 25%` uniform probability across `{1, 2, 3, 4}`.
   - **One-Eyed & Two-Eyed Jack Powers**: `Two-Eyed Jack (J♦)` acts as a **Wild** rank; `One-Eyed Jack (J♠)` awards an **AxLe-Breaker** token to shift or unlock a die's skewer mid-game!
3. **🪐 `HoLy SmoLLey` — Vacuum Gravity-Trains & Abyssal OTEC Odyssey**
   - Real differential-equation physics explorer & storied campaign hosted by **Joe SmoLLey**:
     - **HoLy Earth PREM Core Express (`89.9°S ↔ 89.9°N`)**: Iron-nickel core acceleration (`10.68 m/s²` at CMB) beats uniform-sphere SHM (`42.2 min` → **`38 min 10 sec`** at `9.82 km/s`) with near-zero polar Coriolis wall force!
     - **HoLy M00N Shackleton Vacuum Drop**: Natural hard-vacuum free-fall in `54.19 min` at `1.622 m/s²`.
     - **Submerged Ocean-Trench OTEC HyperLoop**: Closed-cycle Rankine power between warm `27.5°C` surface seawater and `4°C` upwelled abyssal water driving turbo-molecular vacuum pumps, maglev boost, and freshwater desalination.
     - **3-Die AxLe Valve Manifold**: Tumble 3D Axle-Locked airlock dice to prime and launch each mission!
4. **🛞 `z404 M00N Buggy` — `4WD Crawl` ↔ `2-Pip RWD Drift` Lab**
   - Inspired by [`twisted23.com/visito`](https://www.twisted23.com/visito) (`z404` Polar Rim Detour at `89.9°S`): drive a 3D Kapton-gold lunar rover around Shackleton Rim and the HoLy M00N portal!
   - Toggle live between **`4WD 4-Pip Crawl`** and **`2-Pip RWD Drift`** (rear `[2-5]` 2-pip overdrive + counter-steering free-caster front dice wheels + `1.68×` top speed + Kapton/ice regolith roostertails & low-G `1.62 m/s²` hops!).

---

## Three Live-Toggleable 3D Die Skins (Learned-Player `SO(3)` Geometry)

Tap the **`🎲 RH000 Pips` / `◇45° Twisted` / `🃏J FaceCards`** pill anytime:
- **`RH000 Pips`**: Sculpted 3D recessed casino pips with Western right-handed chirality (`1→2→3` CCW around $V_{123}$; `6` rails point toward `3 & 4`).
- **`45° Twisted Numerals` (`ang4v_o` Heritage)**: Every numeral is rotated `45°` so crowns on `{1, 2, 3}` point into shared vertex $V_{123}$ and `{4, 5, 6}` point into $V_{654}$ — giving **24 unique Top-face signatures (`6 faces × 4 corners`)** so Learned players read all 5 hidden faces at a glance!
- **`Royal FaceCards`**: `{A♠, K♥, Q♦, 10♣, J♠ One-Eyed, J♦ Two-Eyed}` with directional corner chevrons.

---

## Pull & Run in Xcode on MacBook Air / iPhone (`A785` Workflow)

```bash
git clone https://github.com/gravity-wizard/fd-too0.git
cd fd-too0
git fetch origin && git checkout feat/joe-smolley-3d-spatial-deck

# Option A: Open directly in Xcode 15 / 16+ (macOS & iOS Simulator) and press Cmd + R!
open Package.swift

# Option B: Run the full 24-state quaternion, Yahtzee, HoLy SmoLLey PREM/OTEC & Drift test suite
swift test

# Option C: Generate an App Store / TestFlight .xcodeproj via XcodeGen
xcodegen generate && open FD_too0.xcodeproj
```
