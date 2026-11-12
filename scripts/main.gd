extends Node
## Point d'entrée : enchaîne les écrans (joueurs → jeu, création, espace ergothérapeute).
##
## Options de lancement pour les tests (après « -- ») :
##   --demo, --demo-frappe, --demo-competences, --demo-travail, --demo-mission :
##       profil de démonstration jamais sauvegardé, ouvert directement sur un écran ;
##   --ecran=creation, --ecran=ergo-demo : affiche un écran (données fictives pour l'ergo) ;
##   --capture=chemin.png : enregistre une capture d'écran puis quitte.

const GameScreen = preload("res://scripts/screens/game_screen.gd")
const ProfileScreen = preload("res://scripts/screens/profile_screen.gd")
const CreateProfileScreen = preload("res://scripts/screens/create_profile_screen.gd")
const ErgoScreen = preload("res://scripts/screens/ergo_screen.gd")

var _screen: Node = null


func _game():
	return get_node("/root/Game")


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	for a in args:
		if a.begins_with("--capture="):
			_capture_later(a.substr(10))
	if args.any(func(a): return a.begins_with("--demo")):
		await _start_demo(args)
	elif args.any(func(a): return a.begins_with("--galerie")):
		_show_gallery(args)
	elif "--ecran=creation" in args:
		show_create()
	elif "--ecran=ergo-demo" in args:
		show_ergo(_demo_profiles(), false)
	else:
		show_profiles()


# --- Écrans -----------------------------------------------------------------------------

func show_profiles() -> void:
	var screen := ProfileScreen.new()
	screen.profiles = _game().list_profiles()
	_set_screen(screen)
	screen.profile_selected.connect(func(data):
		_game().load_profile(data)
		show_game())
	screen.new_profile_requested.connect(show_create)
	screen.ergo_requested.connect(func(): show_ergo(_load_all_profiles(), true))


func show_create() -> void:
	var screen := CreateProfileScreen.new()
	_set_screen(screen)
	screen.back.connect(show_profiles)
	screen.created.connect(func(child_name, appearance):
		_game().create_profile(child_name, appearance)
		show_game())


func show_game() -> void:
	var screen := GameScreen.new()
	_set_screen(screen)
	screen.quit_to_profiles.connect(func():
		_game().close_profile()
		show_profiles())


func show_ergo(profiles: Array, save_enabled: bool) -> void:
	var screen := ErgoScreen.new()
	screen.profiles = profiles
	screen.save_enabled = save_enabled
	_set_screen(screen)
	screen.back.connect(show_profiles)


func _load_all_profiles() -> Array:
	var result := []
	for p in _game().list_profiles():
		result.append(_game()._sanitize(p))
	return result


func _set_screen(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)


# --- Démonstrations et captures (tests) ---------------------------------------------------

func _start_demo(args: Array) -> void:
	_game().start_demo()
	for a in args:
		if a.begins_with("--heure="):
			_game().profile["game_minutes"] = float(a.substr(8)) * 60.0
	show_game()
	await get_tree().process_frame
	var screen = _screen
	if "--demo-competences" in args:
		var profile: Dictionary = _game().profile
		profile["skills_xp"]["physique"] = 130.0
		profile["skills_xp"]["charisme"] = 45.0
		profile["skills_xp"]["organisation"] = 260.0
		screen._open_skills()
	if "--demo-travail" in args:
		screen._open_career()
	if "--demo-mission" in args:
		screen._on_career_chosen("organisateur")
		_game().profile["mission_timer"] = 0.0
		await get_tree().create_timer(0.3).timeout
		screen._open_mission()
		screen._mission_panel.state["step"] = "question"
		screen._mission_panel.refresh()
	if "--demo-frappe" in args:
		var f = screen.studio.furniture.filter(func(x): return x.object_id == "toilettes")[0]
		screen._start_typing(f, "toilettes")


## Profils fictifs (jamais sauvegardés) pour montrer l'espace ergothérapeute.
func _demo_profiles() -> Array:
	var p: Dictionary = _game().new_profile_data("Léo", {"skin": 2, "hair": 0, "hair_style": 0, "outfit": 2})
	p["career"] = {"current": "artisan", "tiers": {"artisan": 2}, "missions": {"artisan": 1}}
	p["money"] = 95
	p["skills_xp"]["physique"] = 70.0
	p["skills_xp"]["creativite"] = 25.0
	p["typing"]["baseline_cps"] = 0.9
	p["typing"]["level"] = 2
	for i in 4:
		var s := {
			"date": "2026-11-%02d 16:%02d:00" % [4 + i * 7, 10 + i],
			"duree_sec": 420.0 + i * 60.0,
			"frappes_ok": 14 + i * 3, "frappes_ratees": 4 - i, "chronos_reussis": 2 + i, "chronos_rates": 2 - mini(i, 2),
			"caracteres": 120 + i * 40, "temps_frappe_sec": 140.0 - i * 8.0,
			"erreurs": {"substitution": 3, "oubli": 6 - i, "ajout": 1, "inversion": 2, "accents": 4, "majuscules": 1},
			"taches_finies": 9 + i, "taches_abandonnees": 2 - mini(i, 2),
			"missions_reussies": mini(i, 2), "missions_abandonnees": 1 if i == 0 else 0,
			"choix_justes_du_premier_coup": 2 + i, "choix_total": 4,
			"rouge_sec": {"faim": 60.0 - i * 15.0, "sommeil": 0.0, "toilettes": 20.0, "hygiene": 45.0, "social": 0.0},
			"rouge_au_moins_une_sec": 90.0 - i * 20.0,
			"competences_debut": {"physique": i, "creativite": 0, "charisme": 0, "organisation": 0},
			"competences_fin": {"physique": i + 1, "creativite": 1, "charisme": 0, "organisation": 0},
		}
		p["sessions"].append(s)
	var q: Dictionary = _game().new_profile_data("Inès", {"skin": 0, "hair": 3, "hair_style": 1, "outfit": 4})
	return [p, q]


## Galerie de contrôle : plusieurs personnages et animations côte à côte.
## --galerie=anim1,anim2… (une animation par personnage), --graine=N, --zoom
func _show_gallery(args: Array) -> void:
	var Character = load("res://scripts/world/character.gd")
	var Data = load("res://scripts/core/data.gd")
	var anims := ["idle", "walk", "run", "talk", "paint", "celebrate"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var zoom := "--zoom" in args
	for a in args:
		if a.begins_with("--galerie="):
			anims = Array(a.substr(10).split(","))
		if a.begins_with("--graine="):
			rng.seed = int(a.substr(9))
	var root := Node3D.new()
	add_child(root)
	_screen = root
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.8, 0.87, 0.94)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.86, 0.84, 0.8)
	ground.material_override = gm
	root.add_child(ground)
	var cam := Camera3D.new()
	var n := anims.size()
	cam.fov = 30
	cam.position = Vector3(0, 1.5, 3.4) if zoom else Vector3(0, 1.7, 2.6 + n * 1.25)
	root.add_child(cam)
	cam.look_at(Vector3(0, 1.25 if zoom else 0.9, 0))
	for i in n:
		var c = Character.new()
		root.add_child(c)
		c.build(Data.random_appearance(rng))
		c.position = Vector3((i - (n - 1) / 2.0) * (0.75 if zoom else 1.25), 0, 0)
		c.rotation_degrees.y = 180.0 - 18.0 * signf(c.position.x) * minf(absf(c.position.x), 1.0)
		var anim: String = anims[i]
		if anim.begins_with("sit"):
			c.position.y = 0.5
			c.set_pose("assis")
		elif anim == "sleep":
			c.position.y = 0.3
			c.set_pose("allonge")
		c.play(anim)


func _capture_later(path: String) -> void:
	for i in 90:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Capture enregistrée : ", path)
	get_tree().quit()
