# Author: Gravity Wizards / FD_too0 — Joe SmoLLey 3D Spatial Deck
# Description: Parametric Autodesk Fusion 360 B-Rep Solid Generator for 3D-Printable AxLe Dice.
#
# Generates 6 Solid Parametric Components laid out flat on the XY Print Bed (Z >= 0):
#   1) AxleDie_Pin16_Rolls_2354 : Protruding self-righting 45-deg conical-acorn pins on [1 & 6]
#   2) AxleDie_Pin25_Rolls_1364 : Protruding self-righting 45-deg conical-acorn pins on [2 & 5]
#   3) AxleDie_Pin34_Rolls_1265 : Protruding self-righting 45-deg conical-acorn pins on [3 & 4]
#   4) RegularDie_RH000_1to6    : Matching 18mm Western Right-Handed (RH000) Control Die
#   5) ModularDie_3AxisCore     : 18mm RH000 Die with chamfered [1-6], [2-5], [3-4] through-bores
#   6) ModularPin_SnapKit       : Flat-printable self-righting Axle Shaft + Press-Fit Acorn Cap
#
# WHY PROTRUDING CONICAL-ACORN PINS WORK & PRINT SUPPORT-FREE:
#   - Each die is oriented flat on one of its 4 unpinned ring faces on the XY print bed (Z = 0..18mm),
#     placing the two opposite protruding pins HORIZONTALLY along +-X at Z = 9mm.
#   - Because each pin tapers at ~45 deg from a 6.6mm base boss to a 1.6mm rounded acorn tip
#     (4.8mm protrusion), the underside slope is <= 45 deg from vertical -> ZERO SUPPORTS NEEDED!
#   - In play, if the die ever tries to stand on a 1.6mm rounded pin tip (raising the CoM to 13.8mm),
#     any >3.3 deg tilt topples it immediately onto the 4 flat ring faces -> it can NEVER land with
#     either pinned number face-up or face-down!

import adsk.core
import adsk.fusion
import math
import traceback


def mm(val_mm: float) -> float:
    """Fusion 360 internal API length unit is centimeters (1 cm = 10 mm)."""
    return val_mm * 0.1


# Canonical Western Right-Handed Casino Die (RH000) face basis in local cube coords:
#   +Z = Top, -Z = Bottom, +X = Right, -X = Left, +Y = Back, -Y = Front
# For each die variant we rotate the RH000pip assignment so the pinned Sum-7 pair sits on +-X
# (horizontal on the print bed!) while a flat ring face sits cleanly on -Z (the print bed Z=0).
DIE_ORIENTATION_CONFIGS = [
    {
        "name": "1_AxleDie_Pin16_Rolls_2354",
        # Pinned pair [1, 6] on +X / -X; sits flat on 5 (-Z), with 2 on +Z, 3 on -Y, 4 on +Y
        # Check RH000 chirality around V_123 = (+X=1, -Y=3, +Z=2): det([+X, +Z, -Y]) ->
        # Wait: in canonical (+X=3, +Y=1, +Z=2), det = +1.
        # Map canonical (+X=3, +Y=1, +Z=2) -> bed coords:
        #   canonical +Y (1) -> +X
        #   canonical +Z (2) -> +Z
        #   canonical +X (3) -> +Y  (since (+X) x (+Y)? Wait: det([cX=+Y, cY=+X, cZ=+Z]) = -1, so set cX = -Y -> 3 on -Y, 4 on +Y!)
        # Verify: 1=(+1,0,0), 2=(0,0,+1), 3=(0,-1,0) => det([[0,1,0],[0,0,1],[-1,0,0]]^T):
        #   cX=(0,-1,0), cY=(1,0,0), cZ=(0,0,1) -> cX x cY = (0,0,1) = cZ! Exact +1 RH000!
        "face_pips": {
            "+X": 1, "-X": 6,
            "+Z": 2, "-Z": 5,
            "-Y": 3, "+Y": 4,
        },
        "pinned_x": True,
        "three_axis_bore": False,
    },
    {
        "name": "2_AxleDie_Pin25_Rolls_1364",
        # Pinned pair [2, 5] on +X / -X:
        # Set cZ(2) = (1,0,0)[+X], cY(1) = (0,0,1)[+Z] -> cX(3) = cY x cZ = (0,0,1) x (1,0,0) = (0,1,0)[+Y]!
        # Verify cX x cY = (0,1,0) x (0,0,1) = (1,0,0) = cZ! Exact +1 RH000!
        "face_pips": {
            "+X": 2, "-X": 5,
            "+Z": 1, "-Z": 6,
            "+Y": 3, "-Y": 4,
        },
        "pinned_x": True,
        "three_axis_bore": False,
    },
    {
        "name": "3_AxleDie_Pin34_Rolls_1265",
        # Pinned pair [3, 4] on +X / -X:
        # Canonical! cX(3) = (1,0,0)[+X], cY(1) = (0,1,0)[+Y], cZ(2) = (0,0,1)[+Z]! Exact +1 RH000!
        "face_pips": {
            "+X": 3, "-X": 4,
            "+Z": 2, "-Z": 5,
            "+Y": 1, "-Y": 6,
        },
        "pinned_x": True,
        "three_axis_bore": False,
    },
    {
        "name": "4_RegularDie_RH000_1to6",
        "face_pips": {
            "+X": 3, "-X": 4,
            "+Z": 1, "-Z": 6,
            "-Y": 2, "+Y": 5,
        },
        "pinned_x": False,
        "three_axis_bore": False,
    },
    {
        "name": "5_ModularDie_3AxisCore",
        "face_pips": {
            "+X": 3, "-X": 4,
            "+Z": 1, "-Z": 6,
            "-Y": 2, "+Y": 5,
        },
        "pinned_x": False,
        "three_axis_bore": True,
    },
]


def pip_2d_offsets(pip: int, d: float):
    """Returns 2D (u, v) pip offsets in cm on a face, matching RH000 chirality."""
    if pip == 1:
        return [(0.0, 0.0)]
    if pip == 2:
        return [(-d, d), (d, -d)]
    if pip == 3:
        return [(-d, -d), (0.0, 0.0), (d, d)]
    if pip == 4:
        return [(-d, -d), (-d, d), (d, -d), (d, d)]
    if pip == 5:
        return [(-d, -d), (-d, d), (0.0, 0.0), (d, -d), (d, d)]
    if pip == 6:
        return [(-d, -d), (-d, 0.0), (-d, d), (d, -d), (d, 0.0), (d, d)]
    return []


def face_basis(tag: str):
    """Returns outward unit normal n, in-plane u, in-plane v as (x,y,z) tuples."""
    mapping = {
        "+X": ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
        "-X": ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
        "+Y": ((0, 1, 0), (-1, 0, 0), (0, 0, 1)),
        "-Y": ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
        "+Z": ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
        "-Z": ((0, 0, -1), (1, 0, 0), (0, -1, 0)),
    }
    return mapping[tag]


def add_or_union(tbm, accum_body, new_body):
    if accum_body is None:
        return new_body
    tbm.booleanOperation(accum_body, new_body, adsk.fusion.BooleanTypes.UnionBooleanType)
    return accum_body


def build_die_component(
    root_comp: adsk.fusion.Component,
    cfg: dict,
    center_xy_mm: tuple,
    side_mm: float,
    fillet_mm: float,
    pip_rad_mm: float,
    pip_depth_mm: float,
    pin_base_rad_mm: float,
    pin_tip_rad_mm: float,
    pin_protrusion_mm: float,
    bore_rad_mm: float,
):
    tbm = adsk.fusion.TemporaryBRepManager.get()
    occ = root_comp.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = cfg["name"]

    cx = mm(center_xy_mm[0])
    cy = mm(center_xy_mm[1])
    cz = mm(side_mm * 0.5)  # Bottom face rests flat on Z = 0!
    side = mm(side_mm)
    half = side * 0.5

    # 1. Base Cube Body
    obb = adsk.core.OrientedBoundingBox3D.create(
        adsk.core.Point3D.create(cx, cy, cz),
        adsk.core.Vector3D.create(1, 0, 0),
        adsk.core.Vector3D.create(0, 1, 0),
        side,
        side,
        side,
    )
    box_temp = tbm.createBox(obb)

    bf_cube = comp.features.baseFeatures.add()
    bf_cube.startEdit()
    comp.bRepBodies.add(box_temp, bf_cube)
    bf_cube.finishEdit()

    target_body = comp.bRepBodies.item(0)
    target_body.name = cfg["name"] + "_Body"

    # 2. Fillet all 12 cube edges for crisp parlour feel & smooth rolling
    edge_col = adsk.core.ObjectCollection.create()
    for e in target_body.edges:
        edge_col.add(e)
    fillets = comp.features.filletFeatures
    f_in = fillets.createInput()
    f_in.addConstantRadiusEdgeSet(edge_col, adsk.core.ValueInput.createByReal(mm(fillet_mm)), True)
    fillets.add(f_in)

    # 3. Optional Protruding Self-Righting 45-deg Conical-Acorn Pin-Axles along +-X
    if cfg["pinned_x"]:
        join_temp = None
        r_base = mm(pin_base_rad_mm)
        r_tip = mm(pin_tip_rad_mm)
        prot = mm(pin_protrusion_mm)
        embed = mm(0.8)  # Anchor 0.8mm inside cube wall for clean boolean union

        for sign in (-1.0, 1.0):
            p_inner = adsk.core.Point3D.create(cx + sign * (half - embed), cy, cz)
            p_cone_end = adsk.core.Point3D.create(cx + sign * (half + prot - r_tip), cy, cz)
            cone = tbm.createCylinderOrCone(p_inner, r_base, p_cone_end, r_tip)
            tip_sphere = tbm.createSphere(p_cone_end, r_tip)
            join_temp = add_or_union(tbm, join_temp, cone)
            join_temp = add_or_union(tbm, join_temp, tip_sphere)

        bf_join = comp.features.baseFeatures.add()
        bf_join.startEdit()
        join_body = comp.bRepBodies.add(join_temp, bf_join)
        bf_join.finishEdit()

        combines = comp.features.combineFeatures
        tools = adsk.core.ObjectCollection.create()
        tools.add(join_body)
        c_in = combines.createInput(target_body, tools)
        c_in.operation = adsk.fusion.FeatureOperations.JoinFeatureOperation
        c_in.isKeepToolBodies = False
        combines.add(c_in)

    # 4. Recessed Spherical Casino Pips + Optional 3-Axis Modular Through-Bores
    cut_temp = None
    d_pip = mm(side_mm * 0.275)  # +-4.95mm on 18mm die -> clears central 6.6mm boss cleanly!
    r_pip = mm(pip_rad_mm)
    depth = mm(pip_depth_mm)
    # Sphere center offset outside face so cap depth == pip_depth_mm:
    sphere_out = r_pip - depth

    for face_tag, pip_num in cfg["face_pips"].items():
        n, u_ax, v_ax = face_basis(face_tag)
        is_pinned_face = cfg["pinned_x"] and face_tag in ("+X", "-X")
        is_bored_face = cfg["three_axis_bore"]

        for (du, dv) in pip_2d_offsets(pip_num, d_pip):
            is_center_pip = abs(du) < 1e-6 and abs(dv) < 1e-6
            if is_center_pip and (is_pinned_face or is_bored_face):
                # Carve a crisp annular bullseye moat around the pin/bore so 1, 3, 5 remain 100% readable!
                ring_center = adsk.core.Point3D.create(
                    cx + n[0] * half,
                    cy + n[1] * half,
                    cz + n[2] * half,
                )
                ring_axis = adsk.core.Vector3D.create(n[0], n[1], n[2])
                major_r = mm(pin_base_rad_mm + 0.85) if is_pinned_face else mm(bore_rad_mm + 1.15)
                torus = tbm.createTorus(ring_center, ring_axis, major_r, mm(0.55))
                cut_temp = add_or_union(tbm, cut_temp, torus)
            else:
                px = cx + n[0] * (half + sphere_out) + u_ax[0] * du + v_ax[0] * dv
                py = cy + n[1] * (half + sphere_out) + u_ax[1] * du + v_ax[1] * dv
                pz = cz + n[2] * (half + sphere_out) + u_ax[2] * du + v_ax[2] * dv
                sp = tbm.createSphere(adsk.core.Point3D.create(px, py, pz), r_pip)
                cut_temp = add_or_union(tbm, cut_temp, sp)

    if cfg["three_axis_bore"]:
        rb = mm(bore_rad_mm)
        ext = half + mm(1.0)
        b_x = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(cx - ext, cy, cz), rb,
            adsk.core.Point3D.create(cx + ext, cy, cz), rb
        )
        b_y = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(cx, cy - ext, cz), rb,
            adsk.core.Point3D.create(cx, cy + ext, cz), rb
        )
        b_z = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(cx, cy, cz - ext), rb,
            adsk.core.Point3D.create(cx, cy, cz + ext), rb
        )
        cut_temp = add_or_union(tbm, cut_temp, b_x)
        cut_temp = add_or_union(tbm, cut_temp, b_y)
        cut_temp = add_or_union(tbm, cut_temp, b_z)

    if cut_temp is not None:
        bf_cut = comp.features.baseFeatures.add()
        bf_cut.startEdit()
        cut_body = comp.bRepBodies.add(cut_temp, bf_cut)
        bf_cut.finishEdit()

        combines = comp.features.combineFeatures
        tools = adsk.core.ObjectCollection.create()
        tools.add(cut_body)
        c_in = combines.createInput(target_body, tools)
        c_in.operation = adsk.fusion.FeatureOperations.CutFeatureOperation
        c_in.isKeepToolBodies = False
        combines.add(c_in)


def build_modular_snap_pin_kit(
    root_comp: adsk.fusion.Component,
    center_xy_mm: tuple,
    side_mm: float,
    bore_rad_mm: float,
    clearance_mm: float,
    pin_base_rad_mm: float,
    pin_tip_rad_mm: float,
    pin_protrusion_mm: float,
):
    """Builds the removable Axle Pin + Press-Fit Acorn Cap upright on Z=0 for zero-support printing."""
    tbm = adsk.fusion.TemporaryBRepManager.get()
    occ = root_comp.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = "6_ModularPin_Shaft_and_Cap"

    cx = mm(center_xy_mm[0])
    cy = mm(center_xy_mm[1])
    shaft_r = mm(bore_rad_mm - clearance_mm)
    r_base = mm(pin_base_rad_mm)
    r_tip = mm(pin_tip_rad_mm)
    prot = mm(pin_protrusion_mm)
    die_len = mm(side_mm)

    # Part A: Pin with integrated bottom acorn head (printed shaft-up from flat collar shoulder or tip-up?
    # Wait: printing collar-down with shaft pointing +Z and a separate bottom acorn cap pointing +Z
    # gives TWO flat Z=0 bases and ZERO supports!)
    # Piece 1 (at cy - 8mm): Collar flange on Z=0 + self-righting cone pointing +Z? No, shaft goes into die,
    # cone sticks OUT of die! Put the flat inner shoulder face on Z=0:
    #   - Piece 1 (Stepped Acorn Cap + Full Through-Tenon? No:
    #     Sub-piece 1A: Through-Shaft with integrated Socket on top? Even simpler:
    #     Two identical Acorn Caps (flat shoulder on Z=0, 45-deg self-righting acorn cone pointing +Z,
    #     with a central blind socket) + One flat-lying Octagonal/Chamfered Connecting Rod on Z=0!)
    # CHECK THAT 3-PIECE ZERO-SUPPORT DESIGN:
    #   - 2x Identical Acorn End-Caps sitting FLAT on their inner shoulder at Z=0 (cone points UP +Z,
    #     blind socket opens from Z=0 upward -> 45-deg cone outside, short 3.6mm socket inside)!
    #   - 1x Connecting Rod printed vertically (with 8mm brim) or flat-bottomed D-shaft on Z=0!
    cap_socket_r = mm(2.0 + clearance_mm * 0.5)
    cap_socket_h = mm(4.2)

    kit_temp = None
    for idx, y_off in enumerate((-8.0, 8.0)):
        py = cy + mm(y_off)
        cone_h = prot - r_tip
        cone = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(cx - mm(6.0), py, 0.0), r_base,
            adsk.core.Point3D.create(cx - mm(6.0), py, cone_h), r_tip
        )
        tip = tbm.createSphere(adsk.core.Point3D.create(cx - mm(6.0), py, cone_h), r_tip)
        tbm.booleanOperation(cone, tip, adsk.fusion.BooleanTypes.UnionBooleanType)

        sock = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(cx - mm(6.0), py, -mm(0.1)), cap_socket_r,
            adsk.core.Point3D.create(cx - mm(6.0), py, cap_socket_h), cap_socket_r
        )
        tbm.booleanOperation(cone, sock, adsk.fusion.BooleanTypes.DifferenceBooleanType)
        kit_temp = add_or_union(tbm, kit_temp, cone)

    # Connecting Rod + Tenon Ends (standing on Z=0; total height = 18 + 2*4.0 = 26.0mm)
    rod_x = cx + mm(6.0)
    tenon_r = mm(2.0 - clearance_mm * 0.5)
    tenon_h = mm(4.0)
    rod_total_h = die_len + 2.0 * tenon_h

    tenon_full = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, 0.0), tenon_r,
        adsk.core.Point3D.create(rod_x, cy, rod_total_h), tenon_r
    )
    mid_collar = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, tenon_h), shaft_r,
        adsk.core.Point3D.create(rod_x, cy, tenon_h + die_len), shaft_r
    )
    # 45-deg print-friendly chamfer between lower tenon and mid_collar so ZERO overhang on Z!
    chamfer_h = max(mm(0.2), shaft_r - tenon_r)
    lower_taper = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, tenon_h - chamfer_h), tenon_r,
        adsk.core.Point3D.create(rod_x, cy, tenon_h), shaft_r
    )
    tbm.booleanOperation(tenon_full, mid_collar, adsk.fusion.BooleanTypes.UnionBooleanType)
    tbm.booleanOperation(tenon_full, lower_taper, adsk.fusion.BooleanTypes.UnionBooleanType)
    kit_temp = add_or_union(tbm, kit_temp, tenon_full)

    bf_kit = comp.features.baseFeatures.add()
    bf_kit.startEdit()
    comp.bRepBodies.add(kit_temp, bf_kit)
    bf_kit.finishEdit()


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        doc = app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = adsk.fusion.Design.cast(app.activeProduct)
        design.designType = adsk.fusion.DesignTypes.ParametricDesignType
        root = design.rootComponent
        root.name = "FD_too0_AxleDice_18mm_Set"

        # Register reference User Parameters in Fusion 360 (Modify -> Change Parameters)
        params = design.userParameters
        param_defs = [
            ("DieSide", "18.0 mm", "Cube face-to-face width"),
            ("EdgeFillet", "1.4 mm", "12-edge parlour bevel radius"),
            ("PipRadius", "1.45 mm", "Recessed RH000 pip sphere radius"),
            ("PipDepth", "0.85 mm", "Recessed pip depth"),
            ("PinBaseRadius", "3.3 mm", "Self-supporting 45-deg axle boss base radius"),
            ("PinTipRadius", "0.85 mm", "Rounded unstable acorn tip radius"),
            ("PinProtrusion", "4.8 mm", "Protrusion past pinned faces (prevents landing face-up)"),
            ("ModularBoreRadius", "2.2 mm", "Through-bore radius for modular 3-axis die"),
            ("PrintClearance", "0.20 mm", "FDM press/slip clearance"),
        ]
        for p_name, p_expr, p_desc in param_defs:
            params.add(p_name, adsk.core.ValueInput.createByString(p_expr), "mm", p_desc)

        side_mm = 18.0
        fillet_mm = 1.4
        pip_rad_mm = 1.45
        pip_depth_mm = 0.85
        pin_base_rad_mm = 3.3
        pin_tip_rad_mm = 0.85
        pin_protrusion_mm = 4.8
        bore_rad_mm = 2.2
        clearance_mm = 0.20

        # Arrange the 6 components cleanly in a 3x2 grid on the XY print bed (Z >= 0)
        grid_xy = [
            (-34.0, 16.0),
            (0.0, 16.0),
            (34.0, 16.0),
            (-34.0, -16.0),
            (0.0, -16.0),
            (34.0, -16.0),
        ]

        for idx, cfg in enumerate(DIE_ORIENTATION_CONFIGS):
            build_die_component(
                root_comp=root,
                cfg=cfg,
                center_xy_mm=grid_xy[idx],
                side_mm=side_mm,
                fillet_mm=fillet_mm,
                pip_rad_mm=pip_rad_mm,
                pip_depth_mm=pip_depth_mm,
                pin_base_rad_mm=pin_base_rad_mm,
                pin_tip_rad_mm=pin_tip_rad_mm,
                pin_protrusion_mm=pin_protrusion_mm,
                bore_rad_mm=bore_rad_mm,
            )

        build_modular_snap_pin_kit(
            root_comp=root,
            center_xy_mm=grid_xy[5],
            side_mm=side_mm,
            bore_rad_mm=bore_rad_mm,
            clearance_mm=clearance_mm,
            pin_base_rad_mm=pin_base_rad_mm,
            pin_tip_rad_mm=pin_tip_rad_mm,
            pin_protrusion_mm=pin_protrusion_mm,
        )

        app.activeViewport.fit()
        ui.messageBox(
            "FD_too0 AxLe Dice Set Generated!\n\n"
            "• 3 Monolithic Support-Free AxLe Dice ([1-6], [2-5], [3-4])\n"
            "• 1 Matching 18mm ReguLar RH000 Die\n"
            "• 1 Modular 3-Axis Core Die + Snap Acorn Pin Kit\n\n"
            "All parts sit flat on Z = 0 with <=45° slopes for zero-support 3D printing.\n"
            "Use File -> 3D Print (or right-click any Component -> Save As Mesh) to slice!"
        )
    except Exception:
        if ui:
            ui.messageBox("AxleDiceGenerator failed:\n{}".format(traceback.format_exc()))
