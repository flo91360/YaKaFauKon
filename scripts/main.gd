extends Node
## Point d'entrée : affiche l'écran demandé (profils, jeu, espace ergothérapeute).
## Options de lancement (après « -- ») : --demo (profil de démonstration non sauvegardé),
## --demo-frappe (ouvre directement une frappe), --capture=chemin.png (capture puis quitte).

const GameScreen = preload("res://scripts/screens/game_screen.gd")

var _screen: Node = null


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.any(func(a): return a.begins_with("--demo")):
		get_node("/root/Game").start_demo()
		show_game()
		if "--demo-competences" in args:
			await get_tree().process_frame
			var profile: Dictionary = get_node("/root/Game").profile
			profile["skills_xp"]["physique"] = 130.0
			profile["skills_xp"]["charisme"] = 45.0
			profile["skills_xp"]["organisation"] = 260.0
			_screen._open_skills()
		if "--demo-travail" in args:
			await get_tree().process_frame
			_screen._open_career()
		if "--demo-mission" in args:
			await get_tree().process_frame
			var game = get_node("/root/Game")
			_screen._on_career_chosen("organisateur")
			game.profile["mission_timer"] = 0.0
			await get_tree().create_timer(0.3).timeout
			_screen._open_mission()
			_screen._mission_panel.state["step"] = "question"
			_screen._mission_panel.refresh()
		if "--demo-frappe" in args:
			await get_tree().process_frame
			var f = _screen.studio.furniture.filter(func(x): return x.object_id == "toilettes")[0]
			_screen._start_typing(f, "toilettes")
	else:
		get_node("/root/Game").start_demo()
		show_game()
	for a in args:
		if a.begins_with("--capture="):
			_capture_later(a.substr(10))


func show_game() -> void:
	_set_screen(GameScreen.new())
	_screen.quit_to_profiles.connect(func(): get_tree().quit())


func _set_screen(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)


func _capture_later(path: String) -> void:
	for i in 90:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Capture enregistrée : ", path)
	get_tree().quit()
