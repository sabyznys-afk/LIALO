import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix

MODELS_DIR = r"D:\downpour-godot\assets\models"


def ensure_models_dir():
    os.makedirs(MODELS_DIR, exist_ok=True)
    return MODELS_DIR


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_pbr_mat(
    name,
    base_color=(0.7, 0.7, 0.7, 1.0),
    roughness=0.55,
    metallic=0.0,
    emission=None,
    emission_strength=0.0,
    alpha=1.0,
    coat=0.0,
    subsurface=0.0,
    double_sided=False,
):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    nt = mat.node_tree
    bsdf = None
    for n in nt.nodes:
        if n.type == "BSDF_PRINCIPLED":
            bsdf = n
            break
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    if len(base_color) == 3:
        rgba = (base_color[0], base_color[1], base_color[2], 1.0)
    else:
        rgba = tuple(base_color)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = float(roughness)
    bsdf.inputs["Metallic"].default_value = float(metallic)
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = float(alpha)
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = float(coat)
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = float(subsurface)
    if emission is not None and emission_strength > 0.0:
        if len(emission) == 3:
            em_rgba = (emission[0], emission[1], emission[2], 1.0)
        else:
            em_rgba = tuple(emission)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = em_rgba
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = float(emission_strength)
    return mat


def box_uv_bm(bm, scale=1.0):
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * scale, co.y * scale
            elif ax >= ay and ax >= az:
                u, v = co.y * scale, co.z * scale
            else:
                u, v = co.x * scale, co.z * scale
            loop[uv_layer].uv = (u, v)


def finish_bmesh(name, bm, mat=None, smooth=True, uv_scale=1.0, auto_uv=True, recalc_normals=True):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if recalc_normals and len(bm.faces) > 0:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    if auto_uv:
        box_uv_bm(bm, scale=uv_scale)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def set_obj_smooth(obj, smooth=True):
    mesh = obj.data
    for p in mesh.polygons:
        p.use_smooth = smooth


def add_subsurf(obj, levels=1):
    mod = obj.modifiers.new(name="Subsurf", type="SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return mod


def add_bevel(obj, width=0.003, segments=2, angle_deg=35.0):
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle_deg)
    mod.use_clamp_overlap = True
    return mod


def add_edge_split(obj, angle_deg=38.0):
    mod = obj.modifiers.new(name="EdgeSplit", type="EDGE_SPLIT")
    mod.split_angle = math.radians(angle_deg)
    mod.use_edge_angle = True
    return mod


def lathe_profile(
    name,
    profile_rz,
    segments=32,
    mat=None,
    smooth=True,
    cap_bottom=True,
    cap_top=True,
    radial_fn=None,
    uv_scale=1.0,
):
    bm = bmesh.new()
    rings = []
    n_prof = len(profile_rz)
    for ri, (r_base, z_base) in enumerate(profile_rz):
        ring_verts = []
        for si in range(segments):
            ang = (float(si) / float(segments)) * math.tau
            if radial_fn is not None:
                px, py, pz = radial_fn(r_base, z_base, ang, ri, n_prof)
            else:
                px = math.cos(ang) * r_base
                py = math.sin(ang) * r_base
                pz = z_base
            ring_verts.append(bm.verts.new((px, py, pz)))
        rings.append(ring_verts)

    for ri in range(n_prof - 1):
        r0 = rings[ri]
        r1 = rings[ri + 1]
        for si in range(segments):
            s_next = (si + 1) % segments
            try:
                bm.faces.new((r0[si], r0[s_next], r1[s_next], r1[si]))
            except ValueError:
                pass

    if cap_bottom and profile_rz[0][0] > 1e-5:
        try:
            bm.faces.new(list(reversed(rings[0])))
        except ValueError:
            pass
    if cap_top and profile_rz[-1][0] > 1e-5:
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass

    return finish_bmesh(name, bm, mat=mat, smooth=smooth, uv_scale=uv_scale)


def tube_along_points(
    name,
    points,
    radii,
    ring_segs=12,
    mat=None,
    cap_ends=True,
    smooth=True,
    scale_xy_fn=None,
):
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    n_pts = len(pts)
    if isinstance(radii, (int, float)):
        rads = [float(radii)] * n_pts
    else:
        rads = [float(r) for r in radii]

    tangents = []
    for i in range(n_pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n_pts - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        if t.length < 1e-7:
            t = Vector((0, 0, 1))
        else:
            t.normalize()
        tangents.append(t)

    # Parallel transport frame so tube never twists abruptly
    ref = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.85 else Vector((0, 1, 0))
    normal = tangents[0].cross(ref).normalized()
    binormal = tangents[0].cross(normal).normalized()

    rings = []
    for i in range(n_pts):
        if i > 0:
            rot_q = tangents[i - 1].rotation_difference(tangents[i])
            normal = (rot_q @ normal).normalized()
            binormal = tangents[i].cross(normal).normalized()

        sx, sy = (1.0, 1.0)
        if scale_xy_fn is not None:
            sx, sy = scale_xy_fn(i, n_pts)

        r = rads[i]
        ring = []
        for si in range(ring_segs):
            ang = (float(si) / float(ring_segs)) * math.tau
            offset = normal * (math.cos(ang) * r * sx) + binormal * (math.sin(ang) * r * sy)
            ring.append(bm.verts.new(pts[i] + offset))
        rings.append(ring)

    for i in range(n_pts - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        for si in range(ring_segs):
            sn = (si + 1) % ring_segs
            try:
                bm.faces.new((r0[si], r0[sn], r1[sn], r1[si]))
            except ValueError:
                pass

    if cap_ends:
        try:
            bm.faces.new(list(reversed(rings[0])))
        except ValueError:
            pass
        try:
            bm.faces.new(rings[-1])
        except ValueError:
            pass

    return finish_bmesh(name, bm, mat=mat, smooth=smooth)


def extrude_poly_3d(name, pts_2d, depth, axis="Z", mat=None, smooth=False, bevel_w=0.0):
    """Build a solid prism from a 2D outline extruded symmetrically along axis ('X', 'Y', or 'Z')."""
    bm = bmesh.new()
    half = depth * 0.5
    front_v = []
    back_v = []
    for x, y in pts_2d:
        if axis == "Z":
            front_v.append(bm.verts.new((x, y, half)))
            back_v.append(bm.verts.new((x, y, -half)))
        elif axis == "Y":
            front_v.append(bm.verts.new((x, half, y)))
            back_v.append(bm.verts.new((x, -half, y)))
        else:
            front_v.append(bm.verts.new((half, x, y)))
            back_v.append(bm.verts.new((-half, x, y)))

    bm.faces.new(front_v)
    bm.faces.new(list(reversed(back_v)))
    n = len(pts_2d)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front_v[i], back_v[i], back_v[j], front_v[j]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = finish_bmesh(name, bm, mat=mat, smooth=smooth)
    if bevel_w > 0.0:
        add_bevel(obj, width=bevel_w, segments=2, angle_deg=30.0)
    return obj


def grid_cloth(name, nu, nv, eval_fn, uv_fn=None, mat=None, closed_u=False, smooth=True):
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    grid = []
    for vi in range(nv + 1):
        v = float(vi) / float(nv)
        row = []
        u_count = nu if closed_u else nu + 1
        for ui in range(u_count):
            u = float(ui) / float(nu)
            pos = eval_fn(u, v)
            row.append((bm.verts.new(pos), u, v))
        grid.append(row)

    for vi in range(nv):
        r0 = grid[vi]
        r1 = grid[vi + 1]
        for ui in range(nu):
            un = (ui + 1) % nu if closed_u else (ui + 1)
            u0 = float(ui) / float(nu)
            u1 = float(ui + 1) / float(nu)
            v0 = float(vi) / float(nv)
            v1 = float(vi + 1) / float(nv)
            a, b, c, d = r0[ui][0], r0[un][0], r1[un][0], r1[ui][0]
            try:
                f = bm.faces.new((a, b, c, d))
                uvs = (
                    uv_fn(u0, v0) if uv_fn else (u0, v0),
                    uv_fn(u1, v0) if uv_fn else (u1, v0),
                    uv_fn(u1, v1) if uv_fn else (u1, v1),
                    uv_fn(u0, v1) if uv_fn else (u0, v1),
                )
                for loop, uv in zip(f.loops, uvs):
                    loop[uv_layer].uv = uv
            except ValueError:
                pass

    return finish_bmesh(name, bm, mat=mat, smooth=smooth, auto_uv=False)


def create_icosphere_sculpted(name, subdivisions, eval_fn, mat=None, smooth=True, uv_scale=1.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = Vector(eval_fn(d.x, d.y, d.z))
    return finish_bmesh(name, bm, mat=mat, smooth=smooth, uv_scale=uv_scale)


def make_box(name, size_xyz, center_xyz=(0, 0, 0), mat=None, bevel_w=0.0, rot_deg=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size_xyz
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    obj = finish_bmesh(name, bm, mat=mat, smooth=(bevel_w > 0.0))
    obj.location = center_xyz
    obj.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    if bevel_w > 0.0:
        add_bevel(obj, width=bevel_w, segments=2, angle_deg=35.0)
    return obj


def make_cylinder(name, radius_bot, radius_top, height, segments=20, center_xyz=(0, 0, 0), mat=None, smooth=True, bevel_w=0.0, rot_deg=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=radius_bot,
        radius2=radius_top,
        depth=height,
    )
    obj = finish_bmesh(name, bm, mat=mat, smooth=smooth)
    obj.location = center_xyz
    obj.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    if bevel_w > 0.0:
        add_bevel(obj, width=bevel_w, segments=2, angle_deg=35.0)
    return obj


def make_sphere(name, radius, segments=24, rings=14, center_xyz=(0, 0, 0), scale_xyz=(1, 1, 1), mat=None, smooth=True, rot_deg=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    for v in bm.verts:
        v.co.x *= scale_xyz[0]
        v.co.y *= scale_xyz[1]
        v.co.z *= scale_xyz[2]
    obj = finish_bmesh(name, bm, mat=mat, smooth=smooth)
    obj.location = center_xyz
    obj.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    return obj


def export_glb(filename, objects=None):
    ensure_models_dir()
    filepath = os.path.join(MODELS_DIR, filename)
    bpy.ops.object.select_all(action="DESELECT")
    target_objs = list(objects) if objects is not None else [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in target_objs:
        o.select_set(True)
    if target_objs:
        bpy.context.view_layer.objects.active = target_objs[0]

    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
    )

    # Print Godot-space AABB: Blender (x, y, z) -> Godot (x, z, -y)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    gx_min, gy_min, gz_min = 1e9, 1e9, 1e9
    gx_max, gy_max, gz_max = -1e9, -1e9, -1e9
    tri_count = 0
    for o in target_objs:
        if o.type != "MESH":
            continue
        eo = o.evaluated_get(depsgraph)
        me = eo.to_mesh()
        tri_count += len(me.polygons)
        mw = o.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            gx, gy, gz = w.x, w.z, -w.y
            gx_min, gx_max = min(gx_min, gx), max(gx_max, gx)
            gy_min, gy_max = min(gy_min, gy), max(gy_max, gy)
            gz_min, gz_max = min(gz_min, gz), max(gz_max, gz)
        eo.to_mesh_clear()

    sz_kb = os.path.getsize(filepath) / 1024.0 if os.path.exists(filepath) else 0.0
    print(
        f"[GLB_EXPORTED] {filename} | {sz_kb:.1f} KB | polys={tri_count} | "
        f"Godot AABB X=[{gx_min:.3f},{gx_max:.3f}] Y=[{gy_min:.3f},{gy_max:.3f}] Z=[{gz_min:.3f},{gz_max:.3f}]"
    )
    return filepath
