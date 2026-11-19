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


def build_gravity_wizard_temp_body(
    tbm: adsk.fusion.TemporaryBRepManager,
    origin_mm: tuple,
    axis_dir: tuple,
    up_dir: tuple,
    pin_base_rad_mm: float,
    hat_brim_rad_mm: float,
    pin_tip_rad_mm: float,
    pin_protrusion_mm: float,
    embed_mm: float = 0.85,
    include_cape_corbel: bool = True,
):
    """Sculpts a miniature 3D B-Rep Gravity Wizard wearing a wide-brimmed pointed Wizard's Hat!
    - Local coords (h, s, u) in mm:
        h : distance outward along pin-axle from cube face (or Z=0 base)
        s : lateral cheek axis (up x axis)
        u : face/beard/hat-curl direction (+Z on horizontal dice for crisp top-facing detail!)
    """
    ox, oy, oz = origin_mm
    ax, ay, az = axis_dir
    ux, uy, uz = up_dir
    # Lateral unit vector s = up x axis
    sx = uy * az - uz * ay
    sy = uz * ax - ux * az
    sz = ux * ay - uy * ax

    def wpt(h_val: float, s_val: float, u_val: float) -> adsk.core.Point3D:
        return adsk.core.Point3D.create(
            mm(ox + ax * h_val + sx * s_val + ux * u_val),
            mm(oy + ay * h_val + sy * s_val + uy * u_val),
            mm(oz + az * h_val + sz * s_val + uz * u_val),
        )

    wiz = None

    # 1. Starlight Robe Shoulders & Collar emerging from die face
    robe = tbm.createCylinderOrCone(
        wpt(-embed_mm, 0.0, -0.12), mm(pin_base_rad_mm),
        wpt(1.45, 0.0, 0.05), mm(1.75),
    )
    wiz = add_or_union(tbm, wiz, robe)

    # 2. Support-Free Flowing Gravity Cloak Corbel underneath (-u) for horizontal FDM printing
    if include_cape_corbel:
        cape = tbm.createCylinderOrCone(
            wpt(-embed_mm, 0.0, -1.28), mm(2.02),
            wpt(2.12, 0.0, -0.52), mm(1.76),
        )
        wiz = add_or_union(tbm, wiz, cape)

    # 3. Gravity Wizard Head
    head = tbm.createSphere(wpt(1.58, 0.0, 0.12), mm(1.68))
    wiz = add_or_union(tbm, wiz, head)

    # 4. Lush Flowing Pointed Wizard Beard + Mustache Cheeks + Cute Round Nose (+u)
    beard_cone = tbm.createCylinderOrCone(
        wpt(1.55, 0.0, 1.08), mm(1.18),
        wpt(0.38, 0.0, 2.20), mm(0.46),
    )
    beard_tip = tbm.createSphere(wpt(0.34, 0.0, 2.24), mm(0.50))
    must_l = tbm.createSphere(wpt(1.52, -0.52, 1.48), mm(0.52))
    must_r = tbm.createSphere(wpt(1.52, 0.52, 1.48), mm(0.52))
    nose = tbm.createSphere(wpt(1.78, 0.0, 1.72), mm(0.55))
    for part in (beard_cone, beard_tip, must_l, must_r, nose):
        wiz = add_or_union(tbm, wiz, part)

    # 5. Wide Flared Wizard's Hat Brim (coaxial at u=0.22 for crisp sliver-free NURBS booleans!)
    brim_low = tbm.createCylinderOrCone(
        wpt(1.60, 0.0, 0.22), mm(1.70),
        wpt(2.12, 0.0, 0.22), mm(hat_brim_rad_mm),
    )
    brim_rim = tbm.createCylinderOrCone(
        wpt(2.12, 0.0, 0.22), mm(hat_brim_rad_mm),
        wpt(2.24, 0.0, 0.22), mm(hat_brim_rad_mm),
    )
    brim_up = tbm.createCylinderOrCone(
        wpt(2.24, 0.0, 0.22), mm(hat_brim_rad_mm),
        wpt(2.58, 0.0, 0.22), mm(2.08),
    )
    hatband = tbm.createTorus(
        wpt(2.56, 0.0, 0.22),
        adsk.core.Vector3D.create(ax, ay, az),
        mm(1.90),
        mm(0.34),
    )
    for part in (brim_low, brim_rim, brim_up, hatband):
        wiz = add_or_union(tbm, wiz, part)

    # 6. Tall Pointed Wizard's Hat Crown + Whimsical Bent Tip + Star Orb!
    elbow_h = max(3.6, pin_protrusion_mm * 0.74)
    tip_h = max(elbow_h + 0.9, pin_protrusion_mm - pin_tip_rad_mm)
    crown_low = tbm.createCylinderOrCone(
        wpt(2.42, 0.0, 0.22), mm(2.02),
        wpt(elbow_h, 0.0, 0.42), mm(0.98),
    )
    crown_elbow = tbm.createSphere(wpt(elbow_h - 0.03, 0.0, 0.42), mm(1.04))
    crown_tip = tbm.createCylinderOrCone(
        wpt(elbow_h - 0.06, 0.0, 0.40), mm(0.96),
        wpt(tip_h, 0.0, 1.00), mm(pin_tip_rad_mm * 0.90),
    )
    star_orb = tbm.createSphere(wpt(tip_h + 0.04, 0.0, 1.02), mm(pin_tip_rad_mm))
    for part in (crown_low, crown_elbow, crown_tip, star_orb):
        wiz = add_or_union(tbm, wiz, part)

    return wiz


def build_die_component(
    root_comp: adsk.fusion.Component,
    cfg: dict,
    center_xy_mm: tuple,
    side_mm: float,
    fillet_mm: float,
    pip_rad_mm: float,
    pip_depth_mm: float,
    pin_base_rad_mm: float,
    hat_brim_rad_mm: float,
    pin_tip_rad_mm: float,
    pin_protrusion_mm: float,
    bore_rad_mm: float,
):
    tbm = adsk.fusion.TemporaryBRepManager.get()
    occ = root_comp.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = cfg["name"]

    cx_mm, cy_mm = center_xy_mm
    cz_mm = side_mm * 0.5
    cx = mm(cx_mm)
    cy = mm(cy_mm)
    cz = mm(cz_mm)  # Bottom face rests flat on Z = 0!
    side = mm(side_mm)
    half = side * 0.5
    half_mm = side_mm * 0.5

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

    target_body = bf_cube.bodies.item(0)
    target_body.name = cfg["name"] + "_Body"

    # 2. Fillet all 12 cube edges for crisp parlour feel & smooth rolling
    edge_col = adsk.core.ObjectCollection.create()
    for e in target_body.edges:
        edge_col.add(e)
    fillets = comp.features.filletFeatures
    f_in = fillets.createInput()
    f_in.addConstantRadiusEdgeSet(edge_col, adsk.core.ValueInput.createByReal(mm(fillet_mm)), True)
    fillets.add(f_in)

    # 3. Protruding Self-Righting Gravity Wizard Pin-Axles wearing Pointed Wizard Hats along +-X
    if cfg["pinned_x"]:
        wiz_temps = []
        for sign in (-1.0, 1.0):
            wiz_temp = build_gravity_wizard_temp_body(
                tbm=tbm,
                origin_mm=(cx_mm + sign * half_mm, cy_mm, cz_mm),
                axis_dir=(sign, 0.0, 0.0),
                up_dir=(0.0, 0.0, 1.0),
                pin_base_rad_mm=pin_base_rad_mm,
                hat_brim_rad_mm=hat_brim_rad_mm,
                pin_tip_rad_mm=pin_tip_rad_mm,
                pin_protrusion_mm=pin_protrusion_mm,
                embed_mm=0.85,
                include_cape_corbel=True,
            )
            wiz_temps.append(wiz_temp)

        bf_join = comp.features.baseFeatures.add()
        bf_join.startEdit()
        for wt in wiz_temps:
            comp.bRepBodies.add(wt, bf_join)
        bf_join.finishEdit()

        combines = comp.features.combineFeatures
        tools = adsk.core.ObjectCollection.create()
        for b in bf_join.bodies:
            tools.add(b)
        c_in = combines.createInput(target_body, tools)
        c_in.operation = adsk.fusion.FeatureOperations.JoinFeatureOperation
        c_in.isKeepToolBodies = False
        combines.add(c_in)

    # 4. Recessed Spherical Casino Pips + Optional 3-Axis Modular Through-Bores
    cut_tools = []
    d_pip = mm(side_mm * 0.275)  # +-4.95mm on 18mm die -> clears central Gravity Wizard base cleanly!
    r_pip = mm(pip_rad_mm)
    depth = mm(pip_depth_mm)
    sphere_out = r_pip - depth

    for face_tag, pip_num in cfg["face_pips"].items():
        n, u_ax, v_ax = face_basis(face_tag)
        is_pinned_face = cfg["pinned_x"] and face_tag in ("+X", "-X")
        is_bored_face = cfg["three_axis_bore"]

        for (du, dv) in pip_2d_offsets(pip_num, d_pip):
            is_center_pip = abs(du) < 1e-6 and abs(dv) < 1e-6
            if is_center_pip and (is_pinned_face or is_bored_face):
                # Carve a crisp magic-circle bullseye moat around the wizard/bore so 1, 3, 5 stay 100% readable!
                ring_center = adsk.core.Point3D.create(
                    cx + n[0] * half,
                    cy + n[1] * half,
                    cz + n[2] * half,
                )
                ring_axis = adsk.core.Vector3D.create(n[0], n[1], n[2])
                major_r = mm(pin_base_rad_mm + 1.05) if is_pinned_face else mm(bore_rad_mm + 1.15)
                torus = tbm.createTorus(ring_center, ring_axis, major_r, mm(0.50))
                cut_tools.append(torus)
            else:
                px = cx + n[0] * (half + sphere_out) + u_ax[0] * du + v_ax[0] * dv
                py = cy + n[1] * (half + sphere_out) + u_ax[1] * du + v_ax[1] * dv
                pz = cz + n[2] * (half + sphere_out) + u_ax[2] * du + v_ax[2] * dv
                sp = tbm.createSphere(adsk.core.Point3D.create(px, py, pz), r_pip)
                cut_tools.append(sp)

    if cfg["three_axis_bore"]:
        rb = mm(bore_rad_mm)
        ext = half + mm(1.0)
        bore_cross = tbm.createCylinderOrCone(
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
        tbm.booleanOperation(bore_cross, b_y, adsk.fusion.BooleanTypes.UnionBooleanType)
        tbm.booleanOperation(bore_cross, b_z, adsk.fusion.BooleanTypes.UnionBooleanType)
        cut_tools.append(bore_cross)

    if cut_tools:
        bf_cut = comp.features.baseFeatures.add()
        bf_cut.startEdit()
        for ct in cut_tools:
            comp.bRepBodies.add(ct, bf_cut)
        bf_cut.finishEdit()

        combines = comp.features.combineFeatures
        tools = adsk.core.ObjectCollection.create()
        for b in bf_cut.bodies:
            tools.add(b)
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
    hat_brim_rad_mm: float,
    pin_tip_rad_mm: float,
    pin_protrusion_mm: float,
):
    """Builds 2x Standing Gravity Wizard Snap-Caps (flat on Z=0) + 1x Stepped Connecting Rod."""
    tbm = adsk.fusion.TemporaryBRepManager.get()
    occ = root_comp.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    comp = occ.component
    comp.name = "6_ModularPin_GravityWizards"

    cx_mm, cy_mm = center_xy_mm
    cx = mm(cx_mm)
    cy = mm(cy_mm)
    shaft_r = mm(bore_rad_mm - clearance_mm)
    die_len = mm(side_mm)

    # Press-fit socket enclosed cleanly inside the thick robe/head/brim (Z = 0..2.35 mm)
    tenon_nom_mm = 1.05
    cap_socket_r = mm(tenon_nom_mm + clearance_mm * 0.5)
    cap_socket_h = mm(2.35)

    kit_parts = []
    for idx, y_off in enumerate((-7.5, 7.5)):
        wiz_x_mm = cx_mm - 6.0
        wiz_y_mm = cy_mm + y_off
        wiz = build_gravity_wizard_temp_body(
            tbm=tbm,
            origin_mm=(wiz_x_mm, wiz_y_mm, 0.0),
            axis_dir=(0.0, 0.0, 1.0),
            up_dir=(0.0, -1.0, 0.0),
            pin_base_rad_mm=pin_base_rad_mm,
            hat_brim_rad_mm=hat_brim_rad_mm,
            pin_tip_rad_mm=pin_tip_rad_mm,
            pin_protrusion_mm=pin_protrusion_mm,
            embed_mm=1.2,
            include_cape_corbel=False,
        )
        # Trim anything below Z = 0 cleanly so the wizard's robe base sits 100% flat on the print bed!
        trim_box = tbm.createBox(
            adsk.core.OrientedBoundingBox3D.create(
                adsk.core.Point3D.create(mm(wiz_x_mm), mm(wiz_y_mm), -mm(5.0)),
                adsk.core.Vector3D.create(1, 0, 0),
                adsk.core.Vector3D.create(0, 1, 0),
                mm(16.0),
                mm(16.0),
                mm(10.0),
            )
        )
        tbm.booleanOperation(wiz, trim_box, adsk.fusion.BooleanTypes.DifferenceBooleanType)

        sock = tbm.createCylinderOrCone(
            adsk.core.Point3D.create(mm(wiz_x_mm), mm(wiz_y_mm), -mm(0.2)), cap_socket_r,
            adsk.core.Point3D.create(mm(wiz_x_mm), mm(wiz_y_mm), cap_socket_h), cap_socket_r
        )
        tbm.booleanOperation(wiz, sock, adsk.fusion.BooleanTypes.DifferenceBooleanType)
        kit_parts.append((f"WizardSnapCap_{idx + 1}", wiz))

    # Stepped Connecting Rod standing at (+6.0 mm, 0) on Z = 0
    rod_x = cx + mm(6.0)
    tenon_r = mm(tenon_nom_mm - clearance_mm * 0.5)
    tenon_h = mm(2.15)
    rod_total_h = die_len + 2.0 * tenon_h

    rod_body = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, 0.0), tenon_r,
        adsk.core.Point3D.create(rod_x, cy, rod_total_h), tenon_r
    )
    mid_collar = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, tenon_h + mm(0.85)), shaft_r,
        adsk.core.Point3D.create(rod_x, cy, tenon_h + die_len), shaft_r
    )
    lower_taper = tbm.createCylinderOrCone(
        adsk.core.Point3D.create(rod_x, cy, tenon_h), tenon_r,
        adsk.core.Point3D.create(rod_x, cy, tenon_h + mm(0.85)), shaft_r
    )
    tbm.booleanOperation(rod_body, mid_collar, adsk.fusion.BooleanTypes.UnionBooleanType)
    tbm.booleanOperation(rod_body, lower_taper, adsk.fusion.BooleanTypes.UnionBooleanType)
    kit_parts.append(("SteppedAxleRod", rod_body))

    bf_kit = comp.features.baseFeatures.add()
    bf_kit.startEdit()
    for _, part_temp in kit_parts:
        comp.bRepBodies.add(part_temp, bf_kit)
    bf_kit.finishEdit()

    for idx, (part_name, _) in enumerate(kit_parts):
        if idx < bf_kit.bodies.count:
            bf_kit.bodies.item(idx).name = part_name


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = adsk.fusion.Design.cast(app.activeProduct)
        if design.designType != adsk.fusion.DesignTypes.ParametricDesignType:
            design.designType = adsk.fusion.DesignTypes.ParametricDesignType
        root = design.rootComponent
        # Note: design.rootComponent.name is read-only in Fusion (reflects saved document title).

        # Register reference User Parameters in Fusion 360 (Modify -> Change Parameters)
        params = design.userParameters
        param_defs = [
            ("DieSide", "18.0 mm", "Cube face-to-face width"),
            ("EdgeFillet", "1.4 mm", "12-edge parlour bevel radius"),
            ("PipRadius", "1.45 mm", "Recessed RH000 pip sphere radius"),
            ("PipDepth", "0.85 mm", "Recessed pip depth"),
            ("WizardRobeRadius", "3.15 mm", "Gravity Wizard robe base radius on pinned face"),
            ("WizardHatBrimRadius", "2.92 mm", "Wide flared Wizard Hat brim radius"),
            ("WizardHatTipRadius", "0.58 mm", "Pointed Wizard Hat star-orb tip radius (<2.2 deg tip-off!)"),
            ("WizardHeight", "6.30 mm", "Gravity Wizard total height past cube face"),
            ("ModularBoreRadius", "2.2 mm", "Through-bore radius for modular 3-axis die"),
            ("PrintClearance", "0.20 mm", "FDM press/slip clearance"),
        ]
        for p_name, p_expr, p_desc in param_defs:
            if params.itemByName(p_name) is None:
                params.add(p_name, adsk.core.ValueInput.createByString(p_expr), "mm", p_desc)

        side_mm = 18.0
        fillet_mm = 1.4
        pip_rad_mm = 1.45
        pip_depth_mm = 0.85
        pin_base_rad_mm = 3.15
        hat_brim_rad_mm = 2.92
        pin_tip_rad_mm = 0.58
        pin_protrusion_mm = 6.30
        bore_rad_mm = 2.2
        clearance_mm = 0.20

        # Arrange the 6 components cleanly in a 3x2 grid on the XY print bed (Z >= 0)
        grid_xy = [
            (-38.0, 16.0),
            (0.0, 16.0),
            (38.0, 16.0),
            (-38.0, -16.0),
            (0.0, -16.0),
            (38.0, -16.0),
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
                hat_brim_rad_mm=hat_brim_rad_mm,
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
            hat_brim_rad_mm=hat_brim_rad_mm,
            pin_tip_rad_mm=pin_tip_rad_mm,
            pin_protrusion_mm=pin_protrusion_mm,
        )

        app.activeViewport.fit()
        ui.messageBox(
            "🧙‍♂️ FD_too0 Gravity Wizard AxLe Dice Generated!\n\n"
            "• 3 Monolithic Support-Free Gravity Wizard AxLe Dice ([1-6], [2-5], [3-4])\n"
            "• 1 Matching 18mm ReguLar RH000 Die\n"
            "• 1 Modular 3-Axis Core Die + 2 Standing Gravity Wizard Snap-Caps\n\n"
            "Each wizard wears a wide-brimmed pointed Wizard's Hat (<2.2° tip-off angle)\n"
            "so pinned faces NEVER land face-up! Right-click any Component -> Save As Mesh to slice."
        )
    except Exception:
        if ui:
            ui.messageBox("AxleDiceGenerator failed:\n{}".format(traceback.format_exc()))

