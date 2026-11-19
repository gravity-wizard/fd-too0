# 🎲 FD_too0 — 3D-Printable Self-Righting AxLe Dice (Autodesk Fusion 360 + Ready-to-Slice STLs)

Protruding pin-axles physically prevent a die from ever coming to rest with its two pinned faces pointing up or down! When a `45°` conical-acorn pin cap (`0.85 mm` spherical tip radius, `4.8 mm` protrusion on an `18.0 mm` RH000 casino cube) touches the table, the die's center of mass sits `13.8 mm` above a tiny rounded point (`< 3.5°` tip-over angle), causing gravity to immediately roll the cube off the pin onto one of its **4 flat equatorial ring faces (`25%` exact probability each)**.

This folder gives you **two complete paths** to 3D print a parlour set:

1. **Ready-to-Slice Watertight `.STL` Meshes** (`STL_ReadyToPrint/`) — drop straight into Bambu Studio, PrusaSlicer, OrcaSlicer, or Cura today (**100% support-free!**).
2. **Parametric Autodesk Fusion 360 Python Script** (`Fusion360_Scripts/AxleDiceGenerator/`) — builds native editable B-Rep solids with live Fusion 360 `User Parameters` (`DieSide`, `PinProtrusion`, `PinTipRadius`, `PrintClearance`, etc.) so you can tweak dimensions or export `.f3d` / `.step` / `.3mf`.

---

## 📦 Included 3D Models (`STL_ReadyToPrint/`)

| File | Overall BBox (`mm`) | Pinned Faces (Never Land Up!) | 4 Rollable Ring Faces (`25%` Each) | Print Orientation |
| :--- | :---: | :---: | :---: | :--- |
| `AxleDie_Pin16_Rolls_2-3-5-4_18mm.stl` | `27.6 × 18.0 × 18.0` | **`1` & `6`** | **`{2, 3, 5, 4}`** | Flat on face `5` (`Z = 0`), pins horizontal (`±X`, `≤ 42°` overhang — **no supports!**) |
| `AxleDie_Pin25_Rolls_1-3-6-4_18mm.stl` | `27.6 × 18.0 × 18.0` | **`2` & `5`** | **`{1, 3, 6, 4}`** | Flat on face `6` (`Z = 0`), pins horizontal (`±X`, **no supports!**) |
| `AxleDie_Pin34_Rolls_1-2-6-5_18mm.stl` | `27.6 × 18.0 × 18.0` | **`3` & `4`** | **`{1, 2, 6, 5}`** | Flat on face `5` (`Z = 0`), pins horizontal (`±X`, **no supports!**) |
| `RegularDie_RH000_Standard_18mm.stl` | `18.0 × 18.0 × 18.0` | *None (Free 1–6)* | All `{1, 2, 3, 4, 5, 6}` | Flat on face `6` (`Z = 0`) — matching control die |
| `ModularDie_3AxisCore_18mm.stl` | `18.0 × 18.0 × 18.0` | *Convertible (`[1-6]`, `[2-5]`, or `[3-4]`)* | Any chosen 4-ring OR all 6 faces | `18 mm` RH000 die with `3.20 mm` orthogonal through-bores on all 3 axes |
| `ModularAxlePin_SnapKit_18mm.stl` | `15.2 × 17.4 × 25.2` | *Removable Pin Kit* | Converts `ModularDie_3AxisCore` | 2× flat-base self-righting acorn caps + 1× stepped push-fit axle rod |

### Why Every Pip Stays 100% Readable (Even on Pinned Faces!)
- **Even faces (`2, 4, 6`)**: Standard RH000 pips sit at `±4.95 mm` (`1.45 mm` radius), leaving a clean `7.00 mm` center corridor that completely clears the `6.60 mm` (`R = 3.30 mm`) conical pin boss or `3.20 mm` modular bore.
- **Odd faces (`1, 3, 5`)**: Instead of losing the center pip under the pin/bore, an **annular bullseye moat** (`R_in = 3.55 mm`, `R_out = 4.45 mm`) frames the center pin or bore so you can still read which axis is pinned at a glance!

---

## 🛠️ How to Open & Customize in Autodesk Fusion 360 (macOS / Windows)

1. Open **Autodesk Fusion 360**.
2. Click the **Utilities** tab on the top toolbar.
3. Click **ADD-INS** (`Scripts and Add-Ins`, shortcut `Shift + S`).
4. Under the **Scripts** tab, click the green **`+`** icon next to **My Scripts**.
5. Select the folder:
   `/Users/hmfr/fd-too0/CAD_3DPrint_AxleDice/Fusion360_Scripts/AxleDiceGenerator`
6. Select **`AxleDiceGenerator`** in the list and click **Run**.
7. Fusion 360 creates a clean new design (`FD_too0 Self-Righting Axle Dice Set (18mm RH000)`) with all **6 solid B-Rep Components** laid out side-by-side on the `XY` print plane (`Z >= 0`) and registers editable parameters under **Solid -> Modify -> Change Parameters**:
   - `DieSide = 18.0 mm`
   - `CornerFillet = 1.35 mm`
   - `PinBaseRadius = 3.30 mm`
   - `PinTipRadius = 0.85 mm`
   - `PinProtrusion = 4.80 mm`
   - `BoreDiameter = 3.20 mm`
   - `PrintClearance = 0.16 mm`
8. To export from Fusion 360: right-click any Component in the Browser -> **Save As Mesh** (`.3mf` or `.stl`, Refinement: **High**), or **Export...** -> `.f3d` / `.step`.

---

## 🖨️ Recommended FDM Slicer Settings (Bambu / Prusa / Creality)

- **Supports**: **OFF / Disabled!** Every overhang on the monolithic horizontal pins and spherical pip concavities is `<= 42°` from vertical.
- **Layer Height**: `0.16 mm` (or `0.12 mm` Fine for glassy spherical pips and rounded acorn tips).
- **Wall Loops / Perimeters**: `4` walls (`1.6 mm` shell for crisp casino bounce and durable pin shafts).
- **Infill**: `35% – 50%` **Gyroid** or **Cubic** (gives balanced rotational inertia and weighty parlour feel).
- **Seam Position**: `Aligned` or `Nearest` on a cube corner bevel.
- **Brim**: None needed for the `18 mm` dice (`~15.3 × 15.3 mm` flat first layer); enable a `3 mm` outer brim only on the vertical `ModularAxlePin_SnapKit` rod if printing on a smooth PEI plate.
- **Two-Color Pip Pop (Optional)**: Pause or paint with a fine acrylic paint marker inside the recessed pips and annular center bullseyes (classic crimson on `1` & `4`, deep ink on `2, 3, 5, 6`).

To regenerate the `.stl` meshes from Python at any time:
```bash
python3 CAD_3DPrint_AxleDice/generate_axle_dice_stls.py
```
