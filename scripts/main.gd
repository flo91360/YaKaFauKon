extends Node
## Point d'entrée : enchaîne les écrans (joueurs → jeu, création, espace ergothérapeute).
##
## Options de lancement pour les tests (après « -- ») :
##   --demo, --demo-frappe, --demo-competences, --demo-travail, --demo-mission :
##       profil de démonstration jamais sauvegardé, ouvert directement sur un écran ;
##   --ecran=creation, --ecran=ergo-demo : affiche un écran (données fictives pour l'ergo) ;
##   --achats=lecture,jeux,guitare,terrasse,chat (ou --achats=tout), --pieces=N : maison et
##       pièces du profil de démonstration ; --demo-magasin ouvre le magasin,
##       --demo-achat=terrasse montre l'instant de l'achat ;
##   --ressources=bois:6,pierre:3, --constructions=banc,fontaine (ou tout), --vue=jardin :
##       réserve, constructions et vue du jardin ; --demo-construire ouvre « Construire »,
##       --demo-construit=banc montre l'instant de la construction ;
##   --famille=rencontre|calin|danse|main|canape|nuit|bebe|enfants|portrait : graphismes de la
##       famille (version 2.4), sans le code de jeu : une scène posée dans la maison ;
##   --capture=chemin.png : enregistre une capture d'écran puis quitte
##       (--images=N : après N images au lieu de 90).

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
		for a in args:
			if a.begins_with("--onglet="):
				_screen.appearance = load("res://scripts/core/data.gd").random_appearance()
				_screen._show_tab(int(a.substr(9)))
		for a in args: # ex. --visage=2 : forme du visage imposée
			if a.begins_with("--visage="):
				_screen.appearance = load("res://scripts/core/data.gd").APPEARANCE_DEFAULTS.duplicate()
				_screen.appearance["face"] = int(a.substr(9))
			if a.begins_with("--joues="):
				_screen.appearance["cheeks"] = int(a.substr(8))
				_screen._show_tab(1)
				_screen._show_tab(1)
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
	screen.existing_names = _game().list_profiles().map(func(p): return str(p.get("name", "")))
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
		if a.begins_with("--pieces="):
			_game().profile["money"] = int(a.substr(9))
		if a.begins_with("--achats="):
			var Data = load("res://scripts/core/data.gd")
			var wanted: Array = Data.SHOP_ORDER.duplicate() if a.substr(9) == "tout" else Array(a.substr(9).split(","))
			_game().profile["achats"] = load("res://scripts/core/shop.gd").clean(wanted)
		if a.begins_with("--ressources="): # ex. --ressources=bois:6,pierre:3
			for part in a.substr(13).split(",", false):
				_game().profile["ressources"][part.get_slice(":", 0)] = int(part.get_slice(":", 1))
		if a.begins_with("--constructions="):
			var D = load("res://scripts/core/data.gd")
			var built: Array = D.CONSTRUCTION_ORDER.duplicate() if a.substr(16) == "tout" else Array(a.substr(16).split(","))
			_game().profile["constructions"] = load("res://scripts/core/build.gd").clean(built)
		if a.begins_with("--objectifs-finis="):
			_game().profile["objectifs_finis"] = int(a.substr(18))
			_game().profile["objectifs_choisis"] = int(a.substr(18))
		if a.begins_with("--reve="): # ex. --reve=sportif ; --reve= : pas encore choisi
			_game().profile["reve"]["id"] = a.substr(7)
		if a.begins_with("--metier="): # ex. --metier=sportif:3 (carrière et palier)
			var job: PackedStringArray = a.substr(9).split(":")
			var tier := int(job[1]) if job.size() > 1 else 1
			_game().profile["career"] = {"current": job[0], "tiers": {job[0]: tier}, "missions": {job[0]: 1}}
		if a.begins_with("--famille-etat="): # rencontre, ensemble, bebe ou enfant
			_demo_family_state(a.substr(15))
	show_game()
	await get_tree().process_frame
	var screen = _screen
	if "--demo-famille" in args: # le panneau « Ma famille »
		screen._open_family()
	if "--vue=jardin" in args:
		screen.studio.set_view("jardin", true)
		screen.hud.set_view("jardin")
	if "--demo-construire" in args:
		screen._open_build()
	for a in args:
		if a.begins_with("--famille="):
			_demo_family(screen, a.substr(10))
	for a in args:
		if a.begins_with("--demo-construit="): # ex. --demo-construit=banc : la construction vient d'être faite
			var D = load("res://scripts/core/data.gd")
			for res in D.CONSTRUCTIONS[a.substr(17)]["cout"]:
				_game().profile["ressources"][res] = 20
			for sk in D.CONSTRUCTIONS[a.substr(17)]["competences"]:
				_game().profile["skills_xp"][sk] = 400.0
			screen._on_built(a.substr(17))
	if "--demo-reve" in args:
		screen._open_dream()
	if "--demo-competences" in args:
		var profile: Dictionary = _game().profile
		profile["skills_xp"]["physique"] = 130.0
		profile["skills_xp"]["charisme"] = 45.0
		profile["skills_xp"]["organisation"] = 260.0
		screen._open_skills()
	if "--demo-travail" in args:
		screen._open_career()
	if "--demo-mission" in args:
		if _game().profile["career"]["current"] == "":
			screen._on_career_chosen("organisateur")
		_game().profile["mission_timer"] = 0.0
		await get_tree().create_timer(0.3).timeout
		for a in args:
			if a.begins_with("--mission="): # ex. --mission=robot : cette mission précise
				for m in load("res://scripts/core/data.gd").MISSIONS:
					if m["id"] == a.substr(10):
						screen._mission_state["data"] = m
		screen._open_mission()
		screen._mission_panel.state["step"] = "question"
		screen._mission_panel.refresh()
	for a in args:
		# Série de mots, 2 mots déjà réussis : sur le tapis de course, ou
		# --demo-serie=bois_jardin:couper pour un autre objet.
		if a == "--demo-serie" or a.begins_with("--demo-serie="):
			var target: PackedStringArray = (a.get_slice("=", 1) if a.contains("=") else "tapis:sport").split(":")
			var support = screen.studio.get_object(target[0])
			screen._start_typing(support, target[1])
			screen.typing.force_close()
			screen._state = "walking"
			screen.character.position = support.use_point
			screen._on_arrived()
			for i in 2:
				screen._on_series_word_ok({"cps": 2.0})
				screen._series["index"] += 1
			screen._open_series_word()
			screen.typing._input.text = screen.typing.model_text.left(3)
			screen.typing._refresh_model()
	if "--demo-objectifs" in args:
		screen._open_objectives()
	if "--demo-magasin" in args:
		screen._open_shop()
	for a in args:
		if a.begins_with("--demo-achat="): # ex. --demo-achat=terrasse : l'achat vient d'être fait
			_game().profile["money"] = 500
			screen._on_shop_bought(a.substr(13))
	if "--demo-guide" in args:
		screen._open_guide()
	if "--demo-pause" in args:
		screen._toggle_pause()
	if "--demo-look" in args:
		screen._open_look()
	for a in args:
		if a == "--demo-tuto" or a.begins_with("--demo-tuto="): # ex. --demo-tuto=4 (étape)
			screen.start_tutorial()
			if a.contains("="):
				screen.tutorial._show(int(a.get_slice("=", 1)) - 1)
	for a in args:
		if a.begins_with("--demo-action="): # ex. --demo-action=cuisine:cuisiner
			var parts: PackedStringArray = a.substr(14).split(":")
			var f = screen.studio.get_object(parts[0])
			screen._object = f
			screen._action_id = parts[1]
			screen._state = "walking"
			screen.character.position = f.use_point
			screen._on_arrived()
			screen.typing.force_close()
			var zone: String = screen.studio.zone_of(f.position)
			if zone != "maison":
				screen.studio.set_view(zone, true)
				screen.hud.set_view(zone, screen.studio.has_nursery())
	if "--demo-frappe" in args:
		var f = screen.studio.furniture.filter(func(x): return x.object_id == "toilettes")[0]
		screen._start_typing(f, "toilettes")


## Scènes de démonstration des graphismes de la famille (version 2.4) : on pose les
## personnages à la main pour les contrôler en image.
## Famille de démonstration (jamais sauvegardée) : où en est l'histoire.
func _demo_family_state(state: String) -> void:
	var Family = load("res://scripts/core/family.gd")
	var p: Dictionary = _game().profile
	p["famille"] = Family.new_state()
	p["famille"]["vu"] = true
	if state == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	p["skills_xp"]["charisme"] = maxf(p["skills_xp"].get("charisme", 0.0), 60.0)
	Family.meet(p, Family.proposals(rng)[1])
	p["famille"]["complicite"] = 46
	if state == "rencontre":
		return
	p["famille"]["complicite"] = 80
	Family.move_in(p)
	if state == "ensemble":
		return
	p["skills_xp"]["organisation"] = maxf(p["skills_xp"].get("organisation", 0.0), float(load("res://scripts/core/data.gd").xp_for_level(2)))
	Family.have_baby(p, Family.baby_names(rng)[0], rng)
	if state == "bebe":
		p["famille"]["enfants"][0]["soins"] = 1
		return
	p["famille"]["enfants"][0]["soins"] = 9
	p["famille"]["enfants"][0]["age"] = "enfant"
	Family.have_baby(p, Family.baby_names(rng)[3], rng)


func _demo_family(screen, scene: String) -> void:
	var studio = screen.studio
	var me = screen.character
	var partner_look := {"body": 0, "skin": 3, "hair": 5, "hair_style": 4, "outfit": 5, "outfit_style": 1, "bottom": 2, "height": 2}
	var kid_look := {"body": 1, "skin": 1, "hair": 5, "hair_style": 1, "outfit": 6, "outfit_style": 0, "bottom": 1}
	var kid2_look := {"body": 0, "skin": 2, "hair": 2, "hair_style": 5, "outfit": 3, "outfit_style": 3, "bottom": 3}
	var partner = studio.add_family_member(partner_look)
	var middle := Vector3(0.4, 0, 1.3)
	match scene:
		"rencontre": # le personnage offre des fleurs
			studio.duo(me, partner, middle, "give", "celebrate", 0.95)
			studio.hearts(middle + Vector3(0, 1.9, 0), 5)
		"calin":
			studio.duo(me, partner, middle, "hug", "hug", 0.5)
			studio.hearts(middle + Vector3(0, 1.9, 0), 6)
		"danse":
			studio.duo(me, partner, middle, "dance", "dance", 0.9)
		"main":
			studio.side_by_side(me, partner, middle, middle + Vector3(0.6, 0, 0.8))
		"canape":
			var sofa = studio.get_object("canape")
			var seats: Array = sofa.get_meta("guest_points")
			me.start_acting("assis", sofa.pose_point, sofa.face_point, "sit_cuddle")
			partner.start_acting("assis", (sofa.pose_point as Vector3).lerp(seats[0], 0.62), sofa.face_point, "sit_cuddle_r")
			studio.hearts(sofa.position + Vector3(0, 1.7, -0.2), 3)
		"nuit":
			studio.set_double_bed(true)
			var bed = studio.get_object("lit")
			me.start_acting("allonge", bed.pose_point, bed.face_point, "sleep")
			partner.start_acting("allonge", bed.get_meta("partner_point"), bed.get_meta("partner_face"), "sleep")
		"bebe":
			studio.set_double_bed(true)
			studio.add_nursery()
			studio.set_baby(false)
			var crib = studio.get_object("berceau")
			me.start_acting("debout", crib.use_point, crib.use_point + Vector3(1, 0, 0.9), "rock")
			partner.start_acting("debout", crib.use_point + Vector3(0.75, 0, 0.5), crib.use_point, "hold_l")
			studio.hearts(crib.use_point + Vector3(0.2, 1.9, 0.2), 4)
		"biberon":
			studio.add_nursery()
			var crib = studio.get_object("berceau")
			me.start_acting("debout", crib.use_point, crib.use_point + Vector3(1, 0, 0.9), "feed")
			partner.start_acting("debout", crib.use_point + Vector3(1.6, 0, 1.6), crib.use_point, "wave")
		"enfants":
			studio.set_double_bed(true)
			studio.add_nursery()
			studio.set_baby(true)
			var toys = studio.get_object("jouets")
			var kid = studio.add_family_member(kid_look, "enfant")
			kid.start_acting("debout", toys.get_meta("kid_point"), toys.position, "floor_play")
			me.start_acting("debout", toys.get_meta("adult_point"), toys.position, "kneel_play")
			var kid2 = studio.add_family_member(kid2_look, "enfant")
			kid2.start_acting("debout", toys.position + Vector3(0.95, 0, -0.35), toys.position, "cuddle_toy")
			var crib = studio.get_object("berceau")
			partner.start_acting("debout", crib.use_point, crib.position, "wave")
		"dodo": # l'enfant dort dans son lit, le bébé dans le berceau
			studio.add_nursery()
			studio.set_baby(true)
			var small_bed = studio.get_object("lit_enfant")
			var kid = studio.add_family_member(kid_look, "enfant")
			kid.start_acting("allonge", small_bed.pose_point, small_bed.face_point, "sleep")
			me.start_acting("debout", small_bed.use_point, small_bed.position, "wave")
			partner.start_acting("debout", studio.get_object("berceau").use_point, studio.get_object("berceau").position, "idle")
		_: # portrait de famille dans le salon
			var kid = studio.add_family_member(kid_look, "enfant")
			var kid2 = studio.add_family_member(kid2_look, "enfant")
			var look := middle + Vector3(0.6, 0, 0.8)
			studio.side_by_side(me, partner, middle, look, 1.5)
			kid.start_acting("debout", middle + Vector3(0.28, 0, 0.36), look + Vector3(0.28, 0, 0.36), "wave")
			kid2.start_acting("debout", middle + Vector3(-0.12, 0, 0.62), look + Vector3(-0.12, 0, 0.62), "cuddle_toy")
	if studio.has_nursery():
		studio.set_view("chambre", true)
	if "--zoom" in OS.get_cmdline_user_args(): # vue rapprochée de la scène
		studio.focus_on(me.position * Vector3(1, 0, 1), 0.15)


## Profils fictifs (jamais sauvegardés) pour montrer l'espace ergothérapeute.
func _demo_profiles() -> Array:
	var p: Dictionary = _game().new_profile_data("Léo", {"skin": 2, "hair": 0, "hair_style": 0, "outfit": 2})
	p["career"] = {"current": "artisan", "tiers": {"artisan": 2}, "missions": {"artisan": 1}}
	p["money"] = 95
	p["reve"] = {"id": "artisan", "fete": false, "changements": 1, "realises": []}
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
## --galerie=anim1,anim2… (une animation par personnage), --graine=N, --zoom, --profil
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
		var kid: bool = (anims[i] as String).ends_with("@enfant") # ex. --galerie=idle,floor_play@enfant
		anims[i] = (anims[i] as String).trim_suffix("@enfant")
		c.build(Data.random_appearance(rng), "enfant" if kid else "adulte")
		c.position = Vector3((i - (n - 1) / 2.0) * (0.75 if zoom else 1.25), 0, 0)
		c.rotation_degrees.y = 180.0 - 18.0 * signf(c.position.x) * minf(absf(c.position.x), 1.0)
		if "--profil" in args: # vus de côté (ils regardent vers la gauche)
			c.rotation_degrees.y = 90.0
		var anim: String = anims[i]
		if anim.begins_with("sit"):
			c.position.y = 0.5
			c.set_pose("assis")
		elif anim == "sleep":
			c.position.y = 0.3
			c.set_pose("allonge")
		c.play(anim)


func _capture_later(path: String) -> void:
	var frames := 90
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--images="): # nombre d'images avant la capture
			frames = int(a.substr(9))
	for i in frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Capture enregistrée : ", path)
	get_tree().quit()
