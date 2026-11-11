extends SceneTree
## Test des profils : création, sauvegarde locale, reprise, réglages, récapitulatif.
## Le profil de test est supprimé à la fin.
## Lancer : Godot --headless --path . --script res://tests/profile_test.gd

const Recap = preload("res://scripts/core/recap.gd")
const Progression = preload("res://scripts/core/progression.gd")

var _fails := 0
var _count := 0


func _initialize() -> void:
	_run()


func check(cond: bool, label: String) -> void:
	_count += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  ÉCHEC ", label)


func _run() -> void:
	await process_frame
	var game = root.get_node("Game")
	print("Profils et sauvegarde")
	var before: int = game.list_profiles().size()
	game.create_profile("Test Auto", {"skin": 2, "hair": 1, "hair_style": 2, "outfit": 3})
	var id: String = game.profile["id"]
	check(game.list_profiles().size() == before + 1, "profil enregistré sur le disque")
	game.profile["needs"]["faim"] = 12.0
	game.profile["money"] = 55
	game.profile["skills_xp"]["physique"] = 75.0
	game.profile["career"] = {"current": "artisan", "tiers": {"artisan": 2}, "missions": {"artisan": 1}}
	game.profile["settings"]["chrono"] = "souvent"
	game.profile["typing"]["level"] = 3
	game.session["duree_sec"] = 300.0
	game.session["frappes_ok"] = 10
	game.session["caracteres"] = 100
	game.session["temps_frappe_sec"] = 100.0
	game.session["taches_finies"] = 4
	game.close_profile()
	check(game.profile.is_empty(), "profil fermé")

	var loaded: Dictionary = {}
	for p in game.list_profiles():
		if p["id"] == id:
			loaded = p
	check(not loaded.is_empty(), "profil retrouvé dans la liste")
	game.load_profile(loaded)
	var p: Dictionary = game.profile
	check(is_equal_approx(p["needs"]["faim"], 12.0), "les jauges reprennent où l'enfant s'était arrêté")
	check(p["money"] == 55 and typeof(p["money"]) == TYPE_INT, "argent conservé (entier)")
	check(Progression.skill_level(p, "physique") == 2, "compétences conservées")
	check(Progression.current_tier(p) == 2, "palier de carrière conservé")
	check(Progression.setting(p, "chrono") == "souvent", "réglage de l'ergo conservé")
	check(Progression.text_level(p) == 3, "niveau de texte conservé")
	check(p["appearance"]["hair_style"] == 2 and typeof(p["appearance"]["hair_style"]) == TYPE_INT, "apparence conservée")
	check(p["sessions"].size() == 2, "nouvelle séance ajoutée à l'historique")
	check(int(p["sessions"][0]["frappes_ok"]) == 10, "séance précédente conservée")
	check(Recap.keywords(p).size() > 0, "le récapitulatif produit des mots-clés")
	check(Recap.session_lines(p["sessions"][0]).size() >= 8, "le récapitulatif d'une séance est complet")
	check(roundi(Recap.speed_cpm(p["sessions"][0])) == 60, "vitesse calculée (60 caractères/min)")
	game.close_profile()
	check(game.list_profiles().size() == before + 1, "la séance vide n'est pas gardée et rien n'est dupliqué")

	game.delete_profile(id)
	check(game.list_profiles().size() == before, "profil de test supprimé")
	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
