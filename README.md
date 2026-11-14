# Flipping Dice & `FD_too0` (`1,023` Levels)

**Gravity Wizards, Inc.** (`akapps` / `two3` Heritage) — Universal **SwiftUI + SpriteKit + CoreHaptics + AVAudioEngine** puzzle game for **iOS 17+, iPadOS 17+, and macOS 14+**, paired with an instant-play 60fps iPhone Web/PWA twin at **`https://gravitywizards.com/fd-too0`** (and inside **`GwCrm` Spy Lab** at `https://gravitywizards.com/crm?tab=spy`).

---

## "Choose Both" — Live `Flipper` Dual-Mode Architecture

Honoring [`Game_23.swift`](https://github.com/gravity-wizard/twst23) and `Flipper_qx.swift` (`TRU ↔ N0T`), tap the **`⇄ Classic FD / FD_too0`** pill at any time to switch seamlessly between:

1. **Near-Original `Flipping Dice` (`Classic FD`)**
   - Pure finite tray puzzle with real 3D 6-face pip dice where **opposite faces always sum to `7`** (`1↔6`, `2↔5`, `3↔4`).
   - Every stage is constructed via deterministic reverse-tumbling from a solved Harmony formation so **100% of boards are guaranteed solvable** within Move & Time Par.
2. **`FD_too0` — Progressive, Addictive, Challenging (`Levels 1 – 1,023` + Daily `#23` Seed)**
   - Fuses 90° physical pip-tumbling & Tumble-Swaps with **3+ matching top-pip clears, gravity cascades, and Chain Multipliers (`×2`, `×3`, `×4+`)**.
   - **Pastel HSB Chroma Surge**: Matching 3+ dice that also share the same Pastel body hue triggers a **×3 Chroma Surge** and awards **`+1` 180° Twist Charge** (`top ↔ 7 - top`).
   - **10 Escalating Worlds (`#1` → `#1,023`)** with **Boss Boards every 23 levels (`#23, #46, #69 ... #1,012, #1,023`)**:
     1. *Spruce Workshop* (`Lv 1–23`) — Pure 90° Tumbles & Sum-7 Craft
     2. *Pastel Conservatory* (`Lv 24–115`) — `×2` / `×3` HSB Chroma Multiplier Pads
     3. *Frosted Glacier* (`Lv 116–230`) — Two-Hit Frosted Ice Dice
     4. *GPADA Airfield* (`Lv 231–345`) — Quad-Rail `180°` Twist Launchers
     5. *SlogBog Lanterns* (`Lv 346–460`) — Chained Dice Freed by Adjacent Pops
     6. *Keep24 Hollows* (`Lv 461–575`) — Sculpted `keep24` & Sanctum Board Masks
     7. *Alpenglow Ridge* (`Lv 576–690`) — Paired Summit Warp Portals
     8. *Sum-Seven Sanctum* (`Lv 691–805`) — High-Density Chroma + Twist Matrices
     9. *Shifting Currents* (`Lv 806–920`) — Multi-Hazard Jetstream Stages
     10. *The Gravitorium* (`Lv 921–1,023`) — `6×6` Master Bosses & Grand `#1,023` Seal

---

## Pastel Colored Dice + Dark / Light / Spruce Modes + 3 Pace Speeds

Cycle live in the top bar between:
- **Obsidian Dark**: Matte-porcelain luminous pastel dice (*Coral Blush*, *Apricot Peach*, *Buttercream Gold*, *Mint Sage*, *Glacier Sky*, *Rose Quartz*) with deep espresso recessed pips over an obsidian-walnut tray.
- **Birch Light**: Sunlit alabaster-linen tray with warm ceramic pastel dice and crisp elevation shadows.
- **Spruce Wood**: Classic `akapps` `WoodGrain` dark spruce workshop table aesthetic.

Switch pace anytime on the **`Rabbit 🐇` • `TurtLe 🐢` • `SnaiL 🐌`** Speed Bar:
- **`Rabbit 🐇`**: Snappy `185ms` 3D tumbles, `170ms` match glow, `190ms` gravity cascades, and `1×` arcade Time Par.
- **`TurtLe 🐢`** *(Default)*: Smooth `460ms` 3D tumbles, `480ms` match-glow preview before popping, `450ms` wave-by-wave gravity drops, and `2×` Time Par.
- **`SnaiL 🐌`**: Zen `900ms` slow-motion Sum-7 cube inspection, `960ms` match glow, `880ms` cascades, and `4×` Zen Time Par.

---

## Opening & Running on MacBook Air / Xcode

Zero external dependencies (`< 1 MB` footprint—friendly even on tight SSD space!):

```bash
git clone https://github.com/gravity-wizard/fd-too0.git
cd fd-too0

# Option A: Open directly in Xcode 15 / 16+ (macOS & iOS Simulator)
open Package.swift

# Option B: Run the 1,023-level solver & Sum-7 algebra test suite
swift test

# Option C: Generate a full App Store / TestFlight .xcodeproj (if XcodeGen is installed)
brew install xcodegen && xcodegen generate && open FD_too0.xcodeproj
```

### Instant-Play iPhone / Browser Twin
Play all `1,023` identical SplitMix64-seeded levels right now on iPhone Safari (**Share → Add to Home Screen**) or desktop:
- **Direct Game URL**: https://gravitywizards.com/fd-too0
- **Inside `GwCrm` Spy Lab**: https://gravitywizards.com/crm?tab=spy
