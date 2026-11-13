extends RefCounted
## Objectifs à choix : le jeu propose 3 objectifs, l'enfant en choisit un,
## une barre montre où il en est, et une récompense arrive à la fin.
## Fonctions statiques qui travaillent sur le dictionnaire du profil.

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Shop = preload("res://scripts/core/shop.gd")

const CARE_ACTIONS := ["dormir", "manger", "toilettes", "douche", "dents"]
const OFFER_COUNT := 3


## Objectif en cours ({} s'il n'y en a pas).
static func current(profile: Dictionary) -> Dictionary:
	var o = profile.get("objectif", {})
	return o if o is Dictionary else {}


static func has_current(profile: Dictionary) -> bool:
	return not current(profile).is_empty()


# --- Propositions ---------------------------------------------------------------------

## Tous les objectifs possibles pour ce profil, à cet instant.
static func candidates(profile: Dictionary) -> Array:
	var result := []
	var done: int = int(profile.get("objectifs_finis", 0))
	var career: String = profile["career"]["current"]
	# Monter une compétence d'un niveau
	for s in Data.available_skills(profile):
		var level := Progression.skill_level(profile, s)
		if level < Data.SKILL_MAX:
			result.append({"type": "competence", "skill": s, "target": level + 1,
				"label": "Monter %s au niveau %d" % [Data.SKILLS[s]["label"], level + 1],
				"aide": Data.skill_help(s, profile), "pieces": 15 + 5 * (level + 1), "icone": s})
	# Taper des mots d'une activité
	var words := 8 if done < 3 else (12 if done < 8 else 15)
	for a in Data.LEXIQUE:
		if not Data.is_available(a, profile):
			continue
		result.append({"type": "mots", "action": a, "target": words,
			"label": "Taper %d mots : %s" % [words, Data.ACTIONS[a]["label"].to_lower()],
			"aide": "Choisis l'activité « %s » et tape les mots qui s'affichent." % Data.ACTIONS[a]["label"],
			"pieces": 10 + words, "icone": Data.main_skill(a)})
	# Finir des séries sans s'arrêter
	result.append({"type": "series", "target": 2 if done < 4 else 3,
		"label": "Finir %d séries de mots sans arrêter" % (2 if done < 4 else 3),
		"aide": "Une série, ce sont %d mots à la suite dans une activité. Va jusqu'au bout !" % Data.WORDS_PER_SERIES,
		"pieces": 25, "icone": "etoile"})
	# Prendre soin de son personnage
	result.append({"type": "soins", "target": 3,
		"label": "Prendre soin de toi : 3 actions",
		"aide": "Manger, dormir, aller aux toilettes, prendre une douche ou se brosser les dents.",
		"pieces": 15, "icone": "coeur"})
	result.append({"type": "vert", "target": 120,
		"label": "Garder toutes les jauges hors du rouge pendant 2 minutes",
		"aide": "Surveille les jauges en haut à gauche et occupe-toi de celles qui baissent.",
		"pieces": 20, "icone": "coeur"})
	# Agrandir la maison : le prochain achat du magasin
	var item := Shop.next_item(profile)
	if item != "" and done >= 1:
		result.append({"type": "achat", "item": item, "target": int(Data.SHOP[item]["prix"]),
			"label": "Acheter au magasin : %s" % Data.SHOP[item]["label"].to_lower(),
			"aide": "Il faut %d pièces. Gagne des pièces avec les objectifs et le travail, puis clique sur « Magasin »." % int(Data.SHOP[item]["prix"]),
			"pieces": 10, "icone": "magasin"})
	# Travail
	if career == "":
		if done >= 1:
			result.append({"type": "metier", "target": 1,
				"label": "Choisir un métier",
				"aide": "Clique sur le bouton « Travail » en haut à droite et choisis un métier.",
				"pieces": 20, "icone": "travail"})
	else:
		var n := 1 if done < 5 else 2
		result.append({"type": "missions", "target": n,
			"label": "Réussir %d mission%s de travail" % [n, "" if n == 1 else "s"],
			"aide": "Quand le bouton « Nouvelle mission » apparaît, clique dessus et lis bien la consigne.",
			"pieces": 30 * n, "icone": "travail"})
		result.append({"type": "argent", "target": 60,
			"label": "Gagner 60 pièces",
			"aide": "Les missions de travail et les objectifs rapportent des pièces.",
			"pieces": 20, "icone": "piece"})
		var tier := Progression.current_tier(profile)
		if tier < 5:
			result.append({"type": "palier", "target": tier + 1,
				"label": "Devenir %s" % Data.CAREERS[career]["tiers"][tier]["title"],
				"aide": "Réussis %d missions et monte les compétences demandées (bouton « Travail »)." % Data.MISSIONS_PER_TIER,
				"pieces": 50, "icone": "travail"})
	return result


## Trois propositions variées : une compétence, puis deux autres types différents.
static func offers(profile: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var all := candidates(profile)
	var by_type := {}
	for c in all:
		if not by_type.has(c["type"]):
			by_type[c["type"]] = []
		by_type[c["type"]].append(c)
	var result := []
	var types: Array = by_type.keys()
	# Le tout premier choix est simple et guidé.
	if int(profile.get("objectifs_finis", 0)) == 0 and int(profile.get("objectifs_choisis", 0)) == 0:
		types = ["competence", "mots", "soins"]
	else:
		# Le métier d'abord s'il n'est pas choisi ; sinon on mélange.
		var ordered := []
		for t in ["metier", "competence"]:
			if t in types:
				ordered.append(t)
				types.erase(t)
		_shuffle(types, rng)
		types = ordered + types
	for t in types:
		if result.size() >= OFFER_COUNT:
			break
		var list: Array = by_type.get(t, [])
		if list.is_empty():
			continue
		if t == "competence": # la compétence la plus basse, pour équilibrer
			list.sort_custom(func(a, b): return a["target"] < b["target"])
			var lowest: int = list[0]["target"]
			list = list.filter(func(c): return c["target"] == lowest)
		result.append(list[rng.randi() % list.size()])
	return result


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


# --- Choisir, avancer, terminer ---------------------------------------------------------

static func choose(profile: Dictionary, offer: Dictionary) -> void:
	var o := offer.duplicate(true)
	o["count"] = 0.0
	if o["type"] == "competence":
		o["start_xp"] = float(profile["skills_xp"].get(o["skill"], 0.0))
	profile["objectif"] = o
	profile["objectifs_choisis"] = int(profile.get("objectifs_choisis", 0)) + 1


static func abandon(profile: Dictionary) -> void:
	profile["objectif"] = {}


## Signale un événement du jeu. Renvoie true si l'objectif vient d'être atteint.
## Événements : "mot" {action}, "serie" {action}, "action" {action}, "argent" {amount},
## "mission", "metier", "palier", "temps" {sec, rouge}. (Un achat se voit dans le profil.)
static func notify(profile: Dictionary, event: String, data: Dictionary = {}) -> bool:
	var o := current(profile)
	if o.is_empty() or is_done(profile):
		return false
	match o["type"]:
		"mots":
			if event == "mot" and data.get("action", "") == o["action"]:
				o["count"] += 1
		"series":
			if event == "serie":
				o["count"] += 1
		"soins":
			if event == "action" and data.get("action", "") in CARE_ACTIONS:
				o["count"] += 1
		"vert":
			if event == "temps":
				o["count"] = 0.0 if data.get("rouge", false) else o["count"] + data.get("sec", 0.0)
		"missions":
			if event == "mission":
				o["count"] += 1
		"argent":
			if event == "argent":
				o["count"] += data.get("amount", 0)
		"metier":
			if event == "metier":
				o["count"] = 1
	return is_done(profile)


static func is_done(profile: Dictionary) -> bool:
	var o := current(profile)
	if o.is_empty():
		return false
	match o["type"]:
		"competence":
			return Progression.skill_level(profile, o["skill"]) >= int(o["target"])
		"palier":
			return Progression.current_tier(profile) >= int(o["target"])
		"metier":
			return profile["career"]["current"] != ""
		"achat":
			return Shop.owns(profile, o["item"])
	return o["count"] >= o["target"]


## Avancement entre 0 et 1.
static func fraction(profile: Dictionary) -> float:
	var o := current(profile)
	if o.is_empty():
		return 0.0
	if is_done(profile):
		return 1.0
	match o["type"]:
		"competence":
			var goal: float = Data.xp_for_level(int(o["target"]))
			var start: float = minf(o.get("start_xp", 0.0), goal - 1.0)
			return clampf((profile["skills_xp"].get(o["skill"], 0.0) - start) / (goal - start), 0.0, 1.0)
		"palier":
			var c: String = profile["career"]["current"]
			if c == "":
				return 0.0
			var missions: float = minf(profile["career"]["missions"].get(c, 0), Data.MISSIONS_PER_TIER)
			return clampf(missions / (Data.MISSIONS_PER_TIER + 1.0), 0.0, 0.95)
		"metier":
			return 0.0
		"achat": # les pièces sont réunies : il reste à aller au magasin
			return clampf(float(profile["money"]) / float(o["target"]), 0.0, 0.95)
	return clampf(o["count"] / float(o["target"]), 0.0, 1.0)


## Petit texte d'avancement (« 3 / 8 mots »).
static func progress_text(profile: Dictionary) -> String:
	var o := current(profile)
	if o.is_empty():
		return ""
	match o["type"]:
		"competence":
			return "%d %%" % int(fraction(profile) * 100.0)
		"mots":
			return "%d / %d mots" % [int(o["count"]), int(o["target"])]
		"series":
			return "%d / %d séries" % [int(o["count"]), int(o["target"])]
		"soins":
			return "%d / %d actions" % [int(o["count"]), int(o["target"])]
		"vert":
			return "%d / %d s" % [int(o["count"]), int(o["target"])]
		"missions":
			return "%d / %d" % [int(o["count"]), int(o["target"])]
		"argent":
			return "%d / %d pièces" % [int(o["count"]), int(o["target"])]
		"achat":
			return "%d / %d pièces" % [mini(int(profile["money"]), int(o["target"])), int(o["target"])]
	return ""


## Termine l'objectif atteint : renvoie la récompense {pieces, label} et vide l'objectif.
## (Les pièces sont à verser par l'appelant.)
static func claim(profile: Dictionary) -> Dictionary:
	var o := current(profile)
	if o.is_empty() or not is_done(profile):
		return {}
	profile["objectifs_finis"] = int(profile.get("objectifs_finis", 0)) + 1
	profile["etoiles"] = int(profile.get("etoiles", 0)) + 1
	profile["objectif"] = {}
	return {"pieces": int(o["pieces"]), "label": o["label"]}
