extends RefCounted
## Boîte à outils 3D : formes arrondies fabriquées par calcul (aucun modèle externe)
## et matériaux partagés. Tout le décor et le personnage sont construits avec ces briques.

static var _mats := {}
static var _textures := {}
static var _meshes := {}


# --- Textures et matériaux --------------------------------------------------------------

static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load("res://textures/%s.png" % name)
	return _textures[name]


## Matériau uni (mis en cache : ne pas le modifier après coup).
static func mat(color: Color, rough := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var key := "c%s/%.2f/%.2f" % [color.to_html(), rough, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Matériau texturé, plaqué par projection (pas besoin de coordonnées de texture).
## `scale` = nombre de répétitions par mètre.
static func tex_mat(name: String, tint := Color.WHITE, scale := 1.0, normal := "", rough := 0.8, normal_strength := 1.0) -> StandardMaterial3D:
	var key := "t%s/%s/%.3f/%s/%.2f/%.2f" % [name, tint.to_html(), scale, normal, rough, normal_strength]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex(name)
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = tex(normal)
		m.normal_scale = normal_strength
	_mats[key] = m
	return m


## Matériau texturé classique (utilise les coordonnées de texture du maillage).
static func uv_mat(name: String, tint := Color.WHITE, rough := 0.8, alpha := false) -> StandardMaterial3D:
	var key := "u%s/%s/%.2f/%s" % [name, tint.to_html(), rough, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex(name)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func glass(color: Color, alpha := 0.3) -> StandardMaterial3D:
	var key := "g%s/%.2f" % [color.to_html(), alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Matériau lumineux (écran, abat-jour). Non mis en cache : son énergie peut changer.
static func glowing(color: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


# --- Boîte aux bords arrondis ------------------------------------------------------------

static func _band(half: float, r: float, seg: int) -> Array:
	var out := []
	for k in seg + 1:
		out.append(-half + r * float(k) / seg)
	var start := seg
	if half - r <= -half + r + 0.00001:
		start = seg - 1 # la bande plate est vide : on évite le doublon du milieu
	for k in range(start, -1, -1):
		out.append(half - r * float(k) / seg)
	return out


static func rounded_box(size: Vector3, radius := 0.05, seg := 3) -> ArrayMesh:
	var h := size * 0.5
	var r: float = clampf(radius, 0.001, minf(h.x, minf(h.y, h.z)) * 0.98)
	var key := "rb%.3f/%.3f/%.3f/%.3f/%d" % [size.x, size.y, size.z, r, seg]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var inner := h - Vector3(r, r, r)
	for f in [[0, 1, 2, 1.0], [0, 1, 2, -1.0], [1, 2, 0, 1.0], [1, 2, 0, -1.0], [2, 0, 1, 1.0], [2, 0, 1, -1.0]]:
		var an: int = f[0]
		var au: int = f[1]
		var av: int = f[2]
		var sgn: float = f[3]
		var cu := _band(h[au], r, seg)
		var cv := _band(h[av], r, seg)
		var base := verts.size()
		for j in cv.size():
			for i in cu.size():
				var p := Vector3.ZERO
				p[an] = sgn * h[an]
				p[au] = cu[i]
				p[av] = cv[j]
				var c := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := (p - c).normalized()
				verts.append(c + d * r)
				normals.append(d)
				uvs.append(Vector2(cu[i], cv[j]))
		var w := cu.size()
		for j in cv.size() - 1:
			for i in w - 1:
				var a := base + j * w + i
				var b := a + 1
				var cc := a + w + 1
				var dd := a + w
				var face_n := (verts[b] - verts[a]).cross(verts[dd] - verts[a])
				var outward := Vector3.ZERO
				outward[an] = sgn
				if face_n.dot(outward) < 0.0: # sens horaire vu de l'extérieur = face visible
					indices.append_array([a, b, cc, a, cc, dd])
				else:
					indices.append_array([a, cc, b, a, dd, cc])
	var mesh := _array_mesh(verts, normals, uvs, indices)
	_meshes[key] = mesh
	return mesh


# --- Forme de révolution (vase, lampe, cuvette…) -----------------------------------------
## profile : points (rayon, hauteur) du bas vers le haut.
static func lathe(profile: Array, segments := 24) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var n := profile.size()
	for i in n:
		var p: Vector2 = profile[i]
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, n - 1)]
		var t := (next - prev).normalized()
		var n2 := Vector2(t.y, -t.x)
		for s in segments + 1:
			var a := TAU * float(s) / segments
			verts.append(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
			normals.append(Vector3(cos(a) * n2.x, n2.y, sin(a) * n2.x).normalized())
			uvs.append(Vector2(float(s) / segments, float(i) / maxi(n - 1, 1)))
	var w := segments + 1
	for i in n - 1:
		for s in segments:
			var a := i * w + s
			var b := a + 1
			var c := a + w + 1
			var d := a + w
			var face_n := (verts[b] - verts[a]).cross(verts[d] - verts[a])
			if face_n.length_squared() < 0.0000000001:
				face_n = (verts[c] - verts[b]).cross(verts[d] - verts[b])
			if face_n.dot(normals[a] + normals[c]) < 0.0:
				indices.append_array([a, b, c, a, c, d])
			else:
				indices.append_array([a, c, b, a, d, c])
	return _array_mesh(verts, normals, uvs, indices)


# --- Tube le long d'un chemin (tuyau, arc de sourire, monture de lunettes…) ---------------
static func tube(path: Array, radius: float, radial := 8, closed := false) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var n := path.size()
	var up := Vector3.UP
	var prev_side := Vector3.ZERO
	for i in n:
		var p: Vector3 = path[i]
		var a: Vector3 = path[(i - 1 + n) % n] if closed else path[maxi(i - 1, 0)]
		var b: Vector3 = path[(i + 1) % n] if closed else path[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var side := t.cross(up)
		if side.length() < 0.01:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		if i > 0 and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		var up2 := side.cross(t).normalized()
		for s in radial + 1:
			var ang := TAU * float(s) / radial
			var dir := side * cos(ang) + up2 * sin(ang)
			verts.append(p + dir * radius)
			normals.append(dir)
			uvs.append(Vector2(float(s) / radial, float(i) / maxi(n - 1, 1)))
	var w := radial + 1
	var rings := n if closed else n - 1
	for i in rings:
		var i2 := (i + 1) % n
		for s in radial:
			var a := i * w + s
			var b := a + 1
			var c := i2 * w + s + 1
			var d := i2 * w + s
			var face_n := (verts[b] - verts[a]).cross(verts[d] - verts[a])
			if face_n.dot(normals[a]) < 0.0:
				indices.append_array([a, b, c, a, c, d])
			else:
				indices.append_array([a, c, b, a, d, c])
	if not closed: # bouts arrondis
		for end in [0, n - 1]:
			var center: Vector3 = path[end]
			var dir_out: Vector3 = (path[0] - path[1]).normalized() if end == 0 else (path[n - 1] - path[n - 2]).normalized()
			var ci := verts.size()
			verts.append(center + dir_out * radius * 0.6)
			normals.append(dir_out)
			uvs.append(Vector2(0.5, 0.5))
			for s in radial:
				var a: int = end * w + s
				var b: int = a + 1
				var face_n := (verts[b] - verts[a]).cross(verts[ci] - verts[a])
				if face_n.dot(dir_out) < 0.0:
					indices.append_array([a, b, ci])
				else:
					indices.append_array([a, ci, b])
	return _array_mesh(verts, normals, uvs, indices)


## Points d'un arc de cercle dans le plan XY (angles en degrés), utile pour tube().
static func arc_points(radius: float, from_deg: float, to_deg: float, steps := 10, squash_y := 1.0) -> Array:
	var pts := []
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		pts.append(Vector3(cos(a) * radius, sin(a) * radius * squash_y, 0))
	return pts


static func _array_mesh(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Formes simples (mises en cache) ------------------------------------------------------

static func sphere(radius: float, rings := 16) -> SphereMesh:
	var key := "sp%.3f/%d" % [radius, rings]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = rings * 2
		m.rings = rings
		_meshes[key] = m
	return _meshes[key]


static func cylinder(radius: float, height: float, top_radius := -1.0, segments := 24) -> CylinderMesh:
	var top := radius if top_radius < 0.0 else top_radius
	var key := "cy%.3f/%.3f/%.3f/%d" % [radius, height, top, segments]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = radius
		m.top_radius = top
		m.height = height
		m.radial_segments = segments
		_meshes[key] = m
	return _meshes[key]


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "ca%.3f/%.3f" % [radius, height]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(height, radius * 2.0)
		m.radial_segments = 20
		m.rings = 8
		_meshes[key] = m
	return _meshes[key]


static func torus(ring_radius: float, thickness: float) -> TorusMesh:
	var key := "to%.3f/%.3f" % [ring_radius, thickness]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = ring_radius - thickness
		m.outer_radius = ring_radius + thickness
		m.rings = 28
		m.ring_segments = 10
		_meshes[key] = m
	return _meshes[key]


static func quad(size: Vector2) -> QuadMesh:
	var key := "qd%.3f/%.3f" % [size.x, size.y]
	if not _meshes.has(key):
		var m := QuadMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


## Ajoute une forme à `parent`. `material` : un matériau ou une couleur.
static func add(parent: Node3D, mesh: Mesh, material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material is Material else mat(material)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi
