extends SceneTree
## Test des profils : création, sauvegarde locale, reprise, réglages, récapitulatif.
## Le profil de test est supprimé à la fin.
## Lancer : Godot --headless --path . --script res://tests/profile_test.gd

const Recap = preload("res://scripts/core/recap.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Data = preload("res://scripts/core/data.gd")
const DreamPanel = preload("res://scripts/ui/dream_panel.gd")

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
	check(game.buy("lecture") and game.profile["money"] == 15, "achat au magasin : 40 pièces dépensées")
	check(not game.buy("chat"), "achat refusé sans assez de pièces")
	check(game.profile["reve"] == {"id": "", "fete": false, "changements": 0, "realises": []}, "nouveau profil : pas encore de rêve")
	game.choose_dream("maison")
	game.choose_dream("artisan")
	check(game.session["reves_changes"] == 1, "changement de rêve noté dans la séance")
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
	check(p["money"] == 15 and typeof(p["money"]) == TYPE_INT, "argent conservé (entier)")
	check(p["achats"] == ["lecture"], "achats du magasin conservés")
	check(p["reve"]["id"] == "artisan" and p["reve"]["changements"] == 1 and typeof(p["reve"]["changements"]) == TYPE_INT, "rêve et nombre de changements conservés")
	check(Recap.dream_line(p) == "Rêve : devenir maître artisan, 2 étape(s) sur 5 — changé 1 fois en cours de route", "rêve visible pour l'ergo")
	check(Recap.session_lines(p["sessions"][0]).has("A changé de rêve : 1 fois"), "changement de rêve dans le récapitulatif de la séance")
	p["career"]["tiers"]["artisan"] = 5
	var reward: Dictionary = game.claim_dream()
	check(reward.get("pieces", 0) == 100 and p["money"] == 115 and p["etoiles"] == 3, "rêve réalisé : 100 pièces et 3 étoiles versées")
	check(game.session["reves_realises"] == ["artisan"] and game.claim_dream().is_empty(), "rêve réalisé noté dans la séance, une seule fois")
	p["career"]["tiers"]["artisan"] = 2
	p["money"] = 15
	check(p["sessions"][0].get("achats", []) == ["lecture"] and int(p["sessions"][0]["argent_depense"]) == 40, "achat noté dans la séance pour l'ergo")
	check(Recap.session_lines(p["sessions"][0]).any(func(l): return l.begins_with("Achats au magasin : coin lecture")), "achat visible dans le récapitulatif")
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

	print("Sauvegarde de la version 1")
	var v1 := {
		"version": 1, "id": "test_v1_ancien", "name": "Ancien", "created": "2026-11-10 10:00:00",
		"appearance": {"skin": 2.0, "hair": 3.0, "hair_style": 1.0, "outfit": 4.0},
		"needs": {"faim": 40.0, "sommeil": 60.0, "toilettes": 70.0, "hygiene": 50.0, "social": 30.0},
		"skills_xp": {"physique": 75.0, "creativite": 20.0, "charisme": 0.0, "organisation": 5.0},
		"money": 40.0, "game_minutes": 2000.0,
		"career": {"current": "artisan", "tiers": {"artisan": 2.0}, "missions": {"artisan": 1.0}},
		"mission_timer": 30.0,
		"typing": {"level": 2.0, "level_successes": 4.0, "samples": [], "baseline_cps": 1.2, "ema_cps": 1.4, "since_timed": 1.0},
		"settings": {"chrono": "parfois", "exigence": "normale", "tolerance": "large", "niveau_texte": "auto", "vitesse_besoins": "normale", "missions_minutes": 2.0},
		"sessions": [{"date": "2026-11-10 10:00:00", "duree_sec": 400.0, "frappes_ok": 12, "frappes_ratees": 2, "chronos_reussis": 1, "chronos_rates": 1,
			"caracteres": 90, "temps_frappe_sec": 80.0, "erreurs": {"substitution": 2, "oubli": 1, "ajout": 0, "inversion": 0, "accents": 3, "majuscules": 0},
			"taches_finies": 8, "taches_abandonnees": 1, "missions_reussies": 1, "missions_abandonnees": 0,
			"choix_justes_du_premier_coup": 2, "choix_total": 2, "rouge_sec": {"faim": 10.0}, "rouge_au_moins_une_sec": 10.0,
			"competences_debut": {"physique": 0}, "competences_fin": {"physique": 2}, "argent_gagne": 40}],
	}
	game.save_any(v1)
	var old: Dictionary = {}
	for q in game.list_profiles():
		if q["id"] == "test_v1_ancien":
			old = q
	check(not old.is_empty(), "ancienne sauvegarde relue")
	game.load_profile(old)
	var o: Dictionary = game.profile
	check(o["appearance"]["skin"] == 2 and o["appearance"]["hair"] == 3 and o["appearance"]["hair_style"] == 1 and o["appearance"]["outfit"] == 4, "apparence de la version 1 conservée")
	check(o["appearance"].size() == Data.APPEARANCE_COUNTS.size(), "nouvelles options d'apparence ajoutées")
	check(Progression.skill_level(o, "physique") == 2 and o["money"] == 40 and Progression.current_tier(o) == 2, "progression de la version 1 conservée")
	check(Progression.setting(o, "tolerance") == "large" and Progression.setting(o, "aide_couleur") == "oui", "réglages conservés et complétés")
	check(o["tuto_fait"] == false and o["etoiles"] == 0 and o["objectif"].is_empty(), "nouveautés prêtes : tutoriel à voir, pas d'objectif")
	check(o["achats"] == [] and o["skills_xp"].has("douceur"), "version 2.1 : pas encore d'achat, nouvelles compétences à zéro")
	check(o["reve"]["id"] == "" and o["reve"]["realises"] == [], "version 2.2 : le rêve reste à choisir")
	check(Recap.session_lines(o["sessions"][0]).size() >= 8 and Recap.keywords(o).size() > 0, "récapitulatif des anciennes séances lisible")
	check(game.session.has("series_finies") and Recap.session_lines(game.session).size() >= 11, "nouvelles statistiques dans la séance en cours")
	var screen = load("res://scripts/screens/game_screen.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	check(screen.character != null and screen._overlay is DreamPanel and screen.tutorial == null, "le jeu s'ouvre avec l'ancien profil et demande d'abord le rêve")
	screen._overlay.find_child("Reve_nature", true, false).pressed.emit()
	await process_frame
	check(o["reve"]["id"] == "nature" and screen._overlay == null and screen.tutorial != null, "rêve choisi : le tutoriel commence")
	screen.queue_free()
	await process_frame
	game.close_profile()
	game.delete_profile("test_v1_ancien")
	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
