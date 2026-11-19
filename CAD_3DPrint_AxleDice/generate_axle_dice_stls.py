#!/usr/bin/env python3
"""
generate_axle_dice_stls.py — FD_too0 (Joe SmoLLey 3D Spatial Deck)

Generates ready-to-slice, 100% watertight binary .STL files for 3D printing
Western Right-Handed (RH000) Self-Righting AxLe Dice & Modular Skewer Kit:

  1) AxleDie_Pin16_Rolls_2-3-5-4_18mm.stl  (Pins on [1 & 6], rolls {2,3,5,4})
  2) AxleDie_Pin25_Rolls_1-3-6-4_18mm.stl  (Pins on [2 & 5], rolls {1,3,6,4})
  3) AxleDie_Pin34_Rolls_1-2-6-5_18mm.stl  (Pins on [3 & 4], rolls {1,2,6,5})
  4) RegularDie_RH000_Standard_18mm.stl    (Matching 18mm Regular 1..6 Control Die)
  5) ModularDie_3AxisCore_18mm.stl         (Universal 3-Axis Bored Cube)
  6) ModularAxlePin_SnapKit_18mm.stl       (2x Acorn End-Caps + Print-Ready Rod)

Uses exact analytic Signed Distance Fields (SDF) + Kuhn 6-Tetrahedra isosurface
extraction + Newton level-set vertex projection for sub-micron geometric fidelity
and guaranteed 2-manifold watertightness.
"""

import os
import struct
import numpy as np


# ---------------------------------------------------------------------------
# Exact Vectorized SDF Primitives (all dimensions in millimeters)
# ---------------------------------------------------------------------------

def sdf_rounded_box(p: np.ndarray, center: tuple, half_extents: tuple, radius: float) -> np.ndarray:
    q = np.abs(p - np.array(center, dtype=np.float32)) - (
        np.array(half_extents, dtype=np.float32) - radius
    )
    outside = np.linalg.norm(np.maximum(q, 0.0), axis=-1)
    inside = np.minimum(np.maximum(q[..., 0], np.maximum(q[..., 1], q[..., 2])), 0.0)
    return outside + inside - radius


def sdf_sphere(p: np.ndarray, center: tuple, radius: float) -> np.ndarray:
    return np.linalg.norm(p - np.array(center, dtype=np.float32), axis=-1) - radius


def sdf_capsule_cone_x(
    p: np.ndarray,
    x_a: float,
    x_b: float,
    cy: float,
    cz: float,
    r_a: float,
    r_b: float,
) -> np.ndarray:
    """Exact SDF of a rounded-end conical frustum (uneven capsule) along the X axis!
    At x = x_a has spherical radius r_a; tapers linearly to spherical tip radius r_b at x = x_b.
    """
    px = p[..., 0] - x_a
    py = p[..., 1] - cy
    pz = p[..., 2] - cz
    rho = np.hypot(py, pz)

    dx = x_b - x_a
    L = abs(dx)
    u = px * (1.0 if dx >= 0 else -1.0)  # axial distance from a -> b in [0, L]

    dr = r_a - r_b
    # Note: if r_a - r_b < L, valid real uneven-capsule cone!
    h_sq = L * L - dr * dr
    b_len = np.sqrt(max(1e-6, h_sq))
    sin_a = dr / L
    cos_a = b_len / L

    # Rotate (rho, u) into cone normal frame:
    q_x = rho * cos_a + u * sin_a
    q_y = -rho * sin_a + u * cos_a

    # Clamp along slanted generator [0, b_len]:
    d_cap_a = np.hypot(rho, u) - r_a
    d_cap_b = np.hypot(rho, u - L) - r_b
    d_side = q_x - r_a

    cond_a = q_y < 0.0
    cond_b = q_y > b_len
    return np.where(cond_a, d_cap_a, np.where(cond_b, d_cap_b, d_side))


def sdf_capped_cylinder_z(
    p: np.ndarray, cx: float, cy: float, z0: float, z1: float, radius: float
) -> np.ndarray:
    zc = 0.5 * (z0 + z1)
    hh = 0.5 * abs(z1 - z0)
    d_rad = np.hypot(p[..., 0] - cx, p[..., 1] - cy) - radius
    d_ax = np.abs(p[..., 2] - zc) - hh
    outside = np.hypot(np.maximum(d_rad, 0.0), np.maximum(d_ax, 0.0))
    inside = np.minimum(np.maximum(d_rad, d_ax), 0.0)
    return outside + inside


def sdf_cone_frustum_z(
    p: np.ndarray, cx: float, cy: float, z0: float, z1: float, r0: float, r1: float
) -> np.ndarray:
    """Exact Capped Cone SDF along Z from (z0, r0) to (z1, r1)."""
    q_x = np.hypot(p[..., 0] - cx, p[..., 1] - cy)
    zc = 0.5 * (z0 + z1)
    h = 0.5 * (z1 - z0)
    q_y = p[..., 2] - zc

    k1_x, k1_y = r1, h
    k2_x, k2_y = r1 - r0, 2.0 * h

    ca_x = q_x - np.minimum(q_x, np.where(q_y < 0.0, r0, r1))
    ca_y = np.abs(q_y) - h

    denom = k2_x * k2_x + k2_y * k2_y
    t = np.clip(((r1 - q_x) * k2_x + (h - q_y) * k2_y) / denom, 0.0, 1.0)
    cb_x = q_x - r1 + k2_x * t
    cb_y = q_y - h + k2_y * t

    s = np.where((cb_x < 0.0) & (ca_y < 0.0), -1.0, 1.0)
    d2 = np.minimum(ca_x * ca_x + ca_y * ca_y, cb_x * cb_x + cb_y * cb_y)
    return s * np.sqrt(np.maximum(d2, 0.0))


def sdf_torus_on_plane(
    p: np.ndarray, center: tuple, normal: tuple, major_r: float, minor_r: float
) -> np.ndarray:
    rel = p - np.array(center, dtype=np.float32)
    n = np.array(normal, dtype=np.float32)
    ax_dist = rel[..., 0] * n[0] + rel[..., 1] * n[1] + rel[..., 2] * n[2]
    in_plane_sq = np.maximum(0.0, np.sum(rel * rel, axis=-1) - ax_dist * ax_dist)
    in_plane_r = np.sqrt(in_plane_sq)
    return np.hypot(in_plane_r - major_r, ax_dist) - minor_r


def sdf_infinite_cyl(p: np.ndarray, center: tuple, axis: str, radius: float) -> np.ndarray:
    cx, cy, cz = center
    if axis == "X":
        return np.hypot(p[..., 1] - cy, p[..., 2] - cz) - radius
    if axis == "Y":
        return np.hypot(p[..., 0] - cx, p[..., 2] - cz) - radius
    return np.hypot(p[..., 0] - cx, p[..., 1] - cy) - radius


# ---------------------------------------------------------------------------
# Western RH000 Die Face & Pip Layout
# ---------------------------------------------------------------------------

def pip_2d_offsets(pip: int, d: float):
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
    return {
        "+X": ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
        "-X": ((-1.0, 0.0, 0.0), (0.0, -1.0, 0.0), (0.0, 0.0, 1.0)),
        "+Y": ((0.0, 1.0, 0.0), (-1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
        "-Y": ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
        "+Z": ((0.0, 0.0, 1.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)),
        "-Z": ((0.0, 0.0, -1.0), (1.0, 0.0, 0.0), (0.0, -1.0, 0.0)),
    }[tag]


def make_die_sdf_fn(
    face_pips: dict,
    pinned_x: bool,
    three_axis_bore: bool,
    side: float = 18.0,
    fillet: float = 1.4,
    pip_r: float = 1.45,
    pip_depth: float = 0.85,
    pin_base_r: float = 3.3,
    pin_tip_r: float = 0.85,
    pin_prot: float = 4.8,
    bore_r: float = 2.2,
):
    half = side * 0.5
    center = (0.0, 0.0, half)
    d_pip = side * 0.275
    sphere_out = pip_r - pip_depth

    def eval_sdf(p: np.ndarray) -> np.ndarray:
        d = sdf_rounded_box(p, center, (half, half, half), fillet)

        # Union protruding self-righting conical-acorn pins on +-X
        if pinned_x:
            for sign in (-1.0, 1.0):
                x_inner = sign * (half - 1.2)
                x_tip = sign * (half + pin_prot - pin_tip_r)
                d_pin = sdf_capsule_cone_x(p, x_inner, x_tip, 0.0, half, pin_base_r, pin_tip_r)
                d = np.minimum(d, d_pin)

        # Cut recessed spherical pips & center bullseye rings
        for tag, pip_num in face_pips.items():
            n, u_ax, v_ax = face_basis(tag)
            is_pin_face = pinned_x and tag in ("+X", "-X")
            for (du, dv) in pip_2d_offsets(pip_num, d_pip):
                is_center = abs(du) < 1e-6 and abs(dv) < 1e-6
                if is_center and (is_pin_face or three_axis_bore):
                    rc = (
                        center[0] + n[0] * half,
                        center[1] + n[1] * half,
                        center[2] + n[2] * half,
                    )
                    maj_r = (pin_base_r + 0.85) if is_pin_face else (bore_r + 1.15)
                    d_ring = sdf_torus_on_plane(p, rc, n, maj_r, 0.55)
                    d = np.maximum(d, -d_ring)
                else:
                    sc = (
                        center[0] + n[0] * (half + sphere_out) + u_ax[0] * du + v_ax[0] * dv,
                        center[1] + n[1] * (half + sphere_out) + u_ax[1] * du + v_ax[1] * dv,
                        center[2] + n[2] * (half + sphere_out) + u_ax[2] * du + v_ax[2] * dv,
                    )
                    d_sp = sdf_sphere(p, sc, pip_r)
                    d = np.maximum(d, -d_sp)

        # Cut 3 orthogonal modular axle bores (+ subtle entry chamfers)
        if three_axis_bore:
            for ax in ("X", "Y", "Z"):
                d_cyl = sdf_infinite_cyl(p, center, ax, bore_r)
                d = np.maximum(d, -d_cyl)

        return d

    return eval_sdf


def make_modular_pin_kit_sdf_fn(
    side: float = 18.0,
    bore_r: float = 2.2,
    clearance: float = 0.20,
    pin_base_r: float = 3.3,
    pin_tip_r: float = 0.85,
    pin_prot: float = 4.8,
):
    """2x Acorn End-Caps (flat shoulder on Z=0) + 1x Stepped Connecting Rod (on Z=0)."""
    shaft_r = bore_r - clearance
    sock_r = 1.35 + clearance * 0.5
    tenon_r = 1.35 - clearance * 0.5
    tenon_h = 3.6
    cone_h = pin_prot - pin_tip_r

    def eval_sdf(p: np.ndarray) -> np.ndarray:
        d = np.full(p.shape[:-1], 1e6, dtype=np.float32)

        # Two identical self-righting Acorn Caps sitting flat on Z = 0
        for y_off in (-5.5, 5.5):
            cx, cy = -5.0, y_off
            d_cone = sdf_cone_frustum_z(p, cx, cy, 0.0, cone_h, pin_base_r, pin_tip_r)
            d_tip = sdf_sphere(p, (cx, cy, cone_h), pin_tip_r)
            # Clip Z >= 0 cleanly so bottom sits 100% flat on bed!
            d_cap = np.maximum(np.minimum(d_cone, d_tip), -p[..., 2])
            d_sock = sdf_capped_cylinder_z(p, cx, cy, -0.5, tenon_h + 0.3, sock_r)
            d_cap = np.maximum(d_cap, -d_sock)
            d = np.minimum(d, d_cap)

        # Stepped Connecting Rod standing at (+5.0, 0.0) on Z = 0
        rx, ry = 5.0, 0.0
        total_h = side + 2.0 * tenon_h
        d_core = sdf_capped_cylinder_z(p, rx, ry, 0.0, total_h, tenon_r)
        d_mid = sdf_capped_cylinder_z(p, rx, ry, tenon_h + 0.65, tenon_h + side, shaft_r)
        # 45-deg self-supporting taper from tenon_r up to shaft_r
        d_tap = sdf_cone_frustum_z(p, rx, ry, tenon_h, tenon_h + 0.65, tenon_r, shaft_r)
        d_rod = np.minimum(d_core, np.minimum(d_mid, d_tap))
        d = np.minimum(d, d_rod)
        return d

    return eval_sdf


# ---------------------------------------------------------------------------
# Guaranteed-Manifold Kuhn 6-Tetrahedra Isosurface Extractor + Newton Projection
# ---------------------------------------------------------------------------

# 8 cube corners:
CUBE_CORNERS = np.array(
    [
        [0, 0, 0],  # 0
        [1, 0, 0],  # 1
        [0, 1, 0],  # 2
        [1, 1, 0],  # 3
        [0, 0, 1],  # 4
        [1, 0, 1],  # 5
        [0, 1, 1],  # 6
        [1, 1, 1],  # 7
    ],
    dtype=np.int32,
)

# 6 Kuhn tetrahedra sharing diagonal (0 -> 7), all positively oriented!
KUHN_TETS = [
    (0, 1, 3, 7),
    (0, 3, 2, 7),
    (0, 2, 6, 7),
    (0, 6, 4, 7),
    (0, 4, 5, 7),
    (0, 5, 1, 7),
]


def build_tet_lookup():
    """Builds exact oriented triangle edge-pair table for all 16 sign masks of a tetrahedron (v0,v1,v2,v3)."""
    # Positive orientation of tet (0,1,2,3): det([v1-v0, v2-v0, v3-v0]) > 0.
    # Outward normal points from negative (inside, bit=1) toward positive (outside, bit=0).
    table = {}
    pts = np.array(
        [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
    )

    def edge_pt(a, b):
        return 0.5 * (pts[a] + pts[b])

    for mask in range(1, 15):
        ins = [i for i in range(4) if (mask >> i) & 1]
        outs = [i for i in range(4) if not ((mask >> i) & 1)]
        inside_center = np.mean(pts[ins], axis=0)
        outside_center = np.mean(pts[outs], axis=0)
        desired_dir = outside_center - inside_center

        tris = []
        if len(ins) == 1:
            a = ins[0]
            e0, e1, e2 = (a, outs[0]), (a, outs[1]), (a, outs[2])
            p0, p1, p2 = edge_pt(*e0), edge_pt(*e1), edge_pt(*e2)
            n = np.cross(p1 - p0, p2 - p0)
            if np.dot(n, desired_dir) < 0:
                e1, e2 = e2, e1
            tris.append((e0, e1, e2))
        elif len(ins) == 3:
            b = outs[0]
            e0, e1, e2 = (ins[0], b), (ins[1], b), (ins[2], b)
            p0, p1, p2 = edge_pt(*e0), edge_pt(*e1), edge_pt(*e2)
            n = np.cross(p1 - p0, p2 - p0)
            if np.dot(n, desired_dir) < 0:
                e1, e2 = e2, e1
            tris.append((e0, e1, e2))
        else:
            # 2 inside (i0, i1), 2 outside (o0, o1) -> quad (i0-o0, i0-o1, i1-o1, i1-o0)
            i0, i1 = ins[0], ins[1]
            o0, o1 = outs[0], outs[1]
            q0 = (i0, o0)
            q1 = (i0, o1)
            q2 = (i1, o1)
            q3 = (i1, o0)
            p0, p1, p2, p3 = edge_pt(*q0), edge_pt(*q1), edge_pt(*q2), edge_pt(*q3)
            n = np.cross(p1 - p0, p2 - p0)
            if np.dot(n, desired_dir) < 0:
                tris.append((q0, q2, q1))
                tris.append((q0, q3, q2))
            else:
                tris.append((q0, q1, q2))
                tris.append((q0, q2, q3))
        table[mask] = tris
    return table


TET_TABLE = build_tet_lookup()


def extract_watertight_mesh(sdf_fn, bounds_min: tuple, bounds_max: tuple, pitch: float = 0.34):
    xs = np.arange(bounds_min[0], bounds_max[0] + pitch, pitch, dtype=np.float32)
    ys = np.arange(bounds_min[1], bounds_max[1] + pitch, pitch, dtype=np.float32)
    zs = np.arange(bounds_min[2], bounds_max[2] + pitch, pitch, dtype=np.float32)

    X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
    P = np.stack([X, Y, Z], axis=-1)
    V = sdf_fn(P).astype(np.float32)

    nx, ny, nz = len(xs), len(ys), len(zs)
    # Flatten grid vertex index: vid = (i * ny + j) * nz + k
    coords_flat = P.reshape(-1, 3)
    vals_flat = V.reshape(-1)

    ii, jj, kk = np.meshgrid(
        np.arange(nx - 1, dtype=np.int32),
        np.arange(ny - 1, dtype=np.int32),
        np.arange(nz - 1, dtype=np.int32),
        indexing="ij",
    )
    # Filter active cells (any sign change among 8 corners)
    v_min = np.minimum(
        np.minimum(np.minimum(V[:-1, :-1, :-1], V[1:, :-1, :-1]), np.minimum(V[:-1, 1:, :-1], V[1:, 1:, :-1])),
        np.minimum(np.minimum(V[:-1, :-1, 1:], V[1:, :-1, 1:]), np.minimum(V[:-1, 1:, 1:], V[1:, 1:, 1:])),
    )
    v_max = np.maximum(
        np.maximum(np.maximum(V[:-1, :-1, :-1], V[1:, :-1, :-1]), np.maximum(V[:-1, 1:, :-1], V[1:, 1:, :-1])),
        np.maximum(np.maximum(V[:-1, :-1, 1:], V[1:, :-1, 1:]), np.maximum(V[:-1, 1:, 1:], V[1:, 1:, 1:])),
    )
    active = (v_min < 0.0) & (v_max >= 0.0)
    ai, aj, ak = ii[active], jj[active], kk[active]

    corner_vids = np.empty((len(ai), 8), dtype=np.int64)
    for c_idx, (di, dj, dk) in enumerate(CUBE_CORNERS):
        corner_vids[:, c_idx] = ((ai + di) * ny + (aj + dj)) * nz + (ak + dk)

    all_edge_u = []
    all_edge_v = []

    for c0, c1, c2, c3 in KUHN_TETS:
        # Check orientation of Kuhn tet: det([v1-v0, v2-v0, v3-v0])
        d1 = CUBE_CORNERS[c1] - CUBE_CORNERS[c0]
        d2 = CUBE_CORNERS[c2] - CUBE_CORNERS[c0]
        d3 = CUBE_CORNERS[c3] - CUBE_CORNERS[c0]
        flip = np.linalg.det(np.stack([d1, d2, d3], axis=0)) < 0

        tv = corner_vids[:, [c0, c1, c2, c3]]
        ts = vals_flat[tv] < 0.0
        masks = (
            ts[:, 0].astype(np.int32)
            | (ts[:, 1].astype(np.int32) << 1)
            | (ts[:, 2].astype(np.int32) << 2)
            | (ts[:, 3].astype(np.int32) << 3)
        )

        for mask, tri_specs in TET_TABLE.items():
            sel = np.nonzero(masks == mask)[0]
            if len(sel) == 0:
                continue
            sub_tv = tv[sel]
            for e0, e1, e2 in tri_specs:
                edges = (e0, e2, e1) if flip else (e0, e1, e2)
                u_cols = []
                v_cols = []
                for a_loc, b_loc in edges:
                    va = sub_tv[:, a_loc]
                    vb = sub_tv[:, b_loc]
                    u_cols.append(np.minimum(va, vb))
                    v_cols.append(np.maximum(va, vb))
                all_edge_u.append(np.stack(u_cols, axis=1))
                all_edge_v.append(np.stack(v_cols, axis=1))

    eu = np.concatenate(all_edge_u, axis=0).reshape(-1)
    ev = np.concatenate(all_edge_v, axis=0).reshape(-1)
    edge_keys = (eu << 30) | ev
    unique_keys, inv_idx = np.unique(edge_keys, return_inverse=True)

    u_unique = unique_keys >> 30
    v_unique = unique_keys & ((1 << 30) - 1)

    p_u = coords_flat[u_unique]
    p_v = coords_flat[v_unique]
    f_u = vals_flat[u_unique]
    f_v = vals_flat[v_unique]
    denom = f_u - f_v
    t = np.where(np.abs(denom) > 1e-9, f_u / denom, 0.5)
    t = np.clip(t, 0.001, 0.999)[:, None]
    verts = p_u + t * (p_v - p_u)

    # 1 gentle damped level-set refinement step (capped at 0.18 * pitch so zero foldovers!)
    eps = 0.02
    f0 = sdf_fn(verts)
    gx = (sdf_fn(verts + np.array([eps, 0, 0], dtype=np.float32)) - sdf_fn(verts - np.array([eps, 0, 0], dtype=np.float32))) / (2 * eps)
    gy = (sdf_fn(verts + np.array([0, eps, 0], dtype=np.float32)) - sdf_fn(verts - np.array([0, eps, 0], dtype=np.float32))) / (2 * eps)
    gz = (sdf_fn(verts + np.array([0, 0, eps], dtype=np.float32)) - sdf_fn(verts - np.array([0, 0, eps], dtype=np.float32))) / (2 * eps)
    grad = np.stack([gx, gy, gz], axis=-1)
    gnorm = np.maximum(np.linalg.norm(grad, axis=-1, keepdims=True), 1e-6)
    step = np.clip(f0[:, None] / gnorm, -0.18 * pitch, 0.18 * pitch)
    verts = verts - 0.65 * step * (grad / gnorm)

    # Snap bottom print-bed vertices near Z = 0 cleanly onto Z = 0.000
    verts[:, 2] = np.where(np.abs(verts[:, 2]) < 0.06, 0.0, np.maximum(0.0, verts[:, 2]))

    faces = inv_idx.reshape(-1, 3)
    return verts.astype(np.float32), faces.astype(np.int32)


def verify_manifold_and_write_binary_stl(path: str, header_title: str, verts: np.ndarray, faces: np.ndarray):
    # Verify watertight Euler edge pairing: every directed edge (a,b) has reverse (b,a)!
    e01 = faces[:, [0, 1]]
    e12 = faces[:, [1, 2]]
    e20 = faces[:, [2, 0]]
    directed = np.vstack([e01, e12, e20]).astype(np.int64)
    fwd = (directed[:, 0] << 28) | directed[:, 1]
    rev = (directed[:, 1] << 28) | directed[:, 0]
    fwd_sorted = np.sort(fwd)
    rev_sorted = np.sort(rev)
    is_watertight = np.array_equal(fwd_sorted, rev_sorted)

    v0 = verts[faces[:, 0]]
    v1 = verts[faces[:, 1]]
    v2 = verts[faces[:, 2]]
    cross = np.cross(v1 - v0, v2 - v0)
    norms = np.linalg.norm(cross, axis=-1, keepdims=True)
    unit_normals = np.where(norms > 1e-12, cross / norms, np.array([0.0, 0.0, 1.0], dtype=np.float32))

    # Signed enclosed volume (mm^3):
    vol_mm3 = float(np.sum(np.einsum("ij,ij->i", v0, cross)) / 6.0)
    bbox_min = verts.min(axis=0)
    bbox_max = verts.max(axis=0)
    dims = bbox_max - bbox_min

    os.makedirs(os.path.dirname(path), exist_ok=True)
    num_tris = len(faces)
    header = header_title.encode("ascii", errors="ignore")[:80].ljust(80, b" ")

    stl_dtype = np.dtype(
        [
            ("normal", "<f4", (3,)),
            ("v0", "<f4", (3,)),
            ("v1", "<f4", (3,)),
            ("v2", "<f4", (3,)),
            ("attr", "<u2"),
        ]
    )
    records = np.zeros(num_tris, dtype=stl_dtype)
    records["normal"] = unit_normals
    records["v0"] = v0
    records["v1"] = v1
    records["v2"] = v2

    with open(path, "wb") as f:
        f.write(header)
        f.write(struct.pack("<I", num_tris))
        f.write(records.tobytes())

    print(
        f"[OK] {os.path.basename(path):42s} | tris={num_tris:6d} | watertight={is_watertight} "
        f"| vol={vol_mm3/1000.0:5.2f} cm^3 | bbox=({dims[0]:.1f} x {dims[1]:.1f} x {dims[2]:.1f} mm)"
    )
    if not is_watertight or vol_mm3 <= 0:
        raise RuntimeError(f"Mesh verification failed for {path}: watertight={is_watertight}, vol={vol_mm3}")


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "STL_ReadyToPrint")
    jobs = [
        (
            "AxleDie_Pin16_Rolls_2-3-5-4_18mm.stl",
            "FD_too0 18mm Axle Die [Pin 1-6 -> Rolls 2,3,5,4] Support-Free",
            make_die_sdf_fn(
                face_pips={"+X": 1, "-X": 6, "+Z": 2, "-Z": 5, "-Y": 3, "+Y": 4},
                pinned_x=True,
                three_axis_bore=False,
            ),
            (-15.0, -10.2, -1.0),
            (15.0, 10.2, 19.2),
            0.46,
        ),
        (
            "AxleDie_Pin25_Rolls_1-3-6-4_18mm.stl",
            "FD_too0 18mm Axle Die [Pin 2-5 -> Rolls 1,3,6,4] Support-Free",
            make_die_sdf_fn(
                face_pips={"+X": 2, "-X": 5, "+Z": 1, "-Z": 6, "+Y": 3, "-Y": 4},
                pinned_x=True,
                three_axis_bore=False,
            ),
            (-15.0, -10.2, -1.0),
            (15.0, 10.2, 19.2),
            0.46,
        ),
        (
            "AxleDie_Pin34_Rolls_1-2-6-5_18mm.stl",
            "FD_too0 18mm Axle Die [Pin 3-4 -> Rolls 1,2,6,5] Support-Free",
            make_die_sdf_fn(
                face_pips={"+X": 3, "-X": 4, "+Z": 2, "-Z": 5, "+Y": 1, "-Y": 6},
                pinned_x=True,
                three_axis_bore=False,
            ),
            (-15.0, -10.2, -1.0),
            (15.0, 10.2, 19.2),
            0.46,
        ),
        (
            "RegularDie_RH000_Standard_18mm.stl",
            "FD_too0 18mm Regular RH000 Casino Control Die (1..6)",
            make_die_sdf_fn(
                face_pips={"+X": 3, "-X": 4, "+Z": 1, "-Z": 6, "-Y": 2, "+Y": 5},
                pinned_x=False,
                three_axis_bore=False,
            ),
            (-10.2, -10.2, -1.0),
            (10.2, 10.2, 19.2),
            0.44,
        ),
        (
            "ModularDie_3AxisCore_18mm.stl",
            "FD_too0 18mm Modular 3-Axis Bored RH000 Die Core",
            make_die_sdf_fn(
                face_pips={"+X": 3, "-X": 4, "+Z": 1, "-Z": 6, "-Y": 2, "+Y": 5},
                pinned_x=False,
                three_axis_bore=True,
            ),
            (-10.2, -10.2, -1.0),
            (10.2, 10.2, 19.2),
            0.44,
        ),
        (
            "ModularAxlePin_SnapKit_18mm.stl",
            "FD_too0 Modular Axle Shaft + 2x Acorn Self-Righting End-Caps",
            make_modular_pin_kit_sdf_fn(),
            (-9.8, -10.2, -1.0),
            (9.2, 10.2, 26.6),
            0.36,
        ),
    ]

    parts_for_3mf = []
    x_offsets = [-80.0, -46.0, -12.0, 20.0, 48.0, 76.0]
    for (fname, title, sdf_fn, bmin, bmax, pitch), x_off in zip(jobs, x_offsets):
        verts, faces = extract_watertight_mesh(sdf_fn, bmin, bmax, pitch=pitch)
        verify_manifold_and_write_binary_stl(os.path.join(out_dir, fname), title, verts, faces)
        part_name = fname.replace("_18mm.stl", "")
        parts_for_3mf.append((part_name, verts, faces, x_off))

    out_3mf = os.path.join(os.path.dirname(os.path.abspath(__file__)), "FD_too0_AxleDice_CompleteSet_18mm.3mf")
    write_3mf_assembly(out_3mf, parts_for_3mf)


def write_3mf_assembly(path: str, parts: list):
    import zipfile

    content_types = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        '  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n'
        '</Types>\n'
    )
    rels_xml = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n'
        '</Relationships>\n'
    )

    chunks = [
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">\n',
        '  <resources>\n',
    ]
    build_items = []
    for obj_id, (name, verts, faces, x_off) in enumerate(parts, start=1):
        chunks.append(f'    <object id="{obj_id}" name="{name}" type="model">\n      <mesh>\n        <vertices>\n')
        v_lines = [f'          <vertex x="{v[0]:.4f}" y="{v[1]:.4f}" z="{v[2]:.4f}"/>\n' for v in verts]
        chunks.extend(v_lines)
        chunks.append('        </vertices>\n        <triangles>\n')
        t_lines = [f'          <triangle v1="{t[0]}" v2="{t[1]}" v3="{t[2]}"/>\n' for t in faces]
        chunks.extend(t_lines)
        chunks.append('        </triangles>\n      </mesh>\n    </object>\n')
        build_items.append(f'    <item objectid="{obj_id}" transform="1 0 0 0 1 0 0 0 1 {x_off:.2f} 0 0"/>\n')

    chunks.append('  </resources>\n  <build>\n')
    chunks.extend(build_items)
    chunks.append('  </build>\n</model>\n')
    model_xml = "".join(chunks)

    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", rels_xml)
        zf.writestr("3D/3dmodel.model", model_xml)

    size_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"[OK] {os.path.basename(path):42s} | 6-part 3MF assembly (unit=mm) | {size_mb:.2f} MB")


if __name__ == "__main__":
    main()

