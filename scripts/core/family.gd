extends RefCounted
## Relations et famille : rencontrer quelqu'un, la complicité, vivre ensemble,
## avoir des enfants ou non. Fonctions statiques qui travaillent sur le profil :
## profile["famille"] = {
##   "partenaire": {} ou {"nom", "genre" (0 femme, 1 homme), "aime", "apparence"},
##   "complicite": 0 à 100, "ensemble": vivent ensemble,
##   "enfants": [{"nom", "genre" (0 fille, 1 garçon), "age" ("bebe" ou "enfant"), "soins", "apparence"}],
##   "choix_enfant": "" (pas encore décidé) ou "non" (pas d'enfant pour l'instant),
##   "vu": l'enfant a déjà ouvert « Ma famille »}.

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")


static func new_state() -> Dictionary:
	return {"partenaire": {}, "complicite": 0, "ensemble": false, "enfants": [], "choix_enfant": "", "vu": false}


## Remet en ordre l'état lu dans une sauvegarde (anciennes versions, fichier modifié à la main).
static func clean(state) -> Dictionary:
	var result := new_state()
	if not state is Dictionary:
		return result
	var p = state.get("partenaire", {})
	if p is Dictionary and str(p.get("nom", "")) != "":
		result["partenaire"] = {"nom": str(p["nom"]), "genre": clampi(int(p.get("genre", 0)), 0, 1),
			"aime": str(p.get("aime", "")), "apparence": Data.complete_appearance(p.get("apparence", {}) if p.get("apparence", {}) is Dictionary else {})}
		result["complicite"] = clampi(int(state.get("complicite", 0)), 0, 100)
		result["ensemble"] = bool(state.get("ensemble", false))
	var kids = state.get("enfants", [])
	if kids is Array and result["ensemble"]:
		for k in kids:
			if k is Dictionary and str(k.get("nom", "")) != "" and result["enfants"].size() < Data.FAMILY_MAX_CHILDREN:
				var age := "enfant" if str(k.get("age", "")) == "enfant" else "bebe"
				result["enfants"].append({"nom": str(k["nom"]), "genre": clampi(int(k.get("genre", 0)), 0, 1), "age": age,
					"soins": maxi(int(k.get("soins", 0)), 0), "apparence": Data.complete_appearance(k.get("apparence", {}) if k.get("apparence", {}) is Dictionary else {})})
	result["choix_enfant"] = "non" if str(state.get("choix_enfant", "")) == "non" and result["enfants"].is_empty() else ""
	result["vu"] = bool(state.get("vu", false))
	return result


static func _state(profile: Dictionary) -> Dictionary:
	if not profile.get("famille") is Dictionary:
		profile["famille"] = new_state()
	return profile["famille"]


# --- Où en est l'enfant -----------------------------------------------------------------

static func partner(profile: Dictionary) -> Dictionary:
	return _state(profile)["partenaire"]


static func has_partner(profile: Dictionary) -> bool:
	return not partner(profile).is_empty()


static func partner_name(profile: Dictionary) -> String:
	return str(partner(profile).get("nom", ""))


static func complicity(profile: Dictionary) -> int:
	return int(_state(profile)["complicite"])


static func is_together(profile: Dictionary) -> bool:
	return has_partner(profile) and bool(_state(profile)["ensemble"])


static func children(profile: Dictionary) -> Array:
	return _state(profile)["enfants"]


## Le bébé (celui qui n'a pas encore grandi), ou {} s'il n'y en a pas.
static func baby(profile: Dictionary) -> Dictionary:
	for k in children(profile):
		if k["age"] == "bebe":
			return k
	return {}


static func has_baby(profile: Dictionary) -> bool:
	return not baby(profile).is_empty()


## Les enfants qui ont grandi.
static func grown(profile: Dictionary) -> Array:
	return children(profile).filter(func(k): return k["age"] == "enfant")


static func has_child(profile: Dictionary) -> bool:
	return not grown(profile).is_empty()


## "seul", "rencontre" (quelqu'un, pas encore ensemble) ou "ensemble".
static func stage(profile: Dictionary) -> String:
	if not has_partner(profile):
		return "seul"
	return "ensemble" if is_together(profile) else "rencontre"


## Compétences encore trop basses : {compétence: niveau demandé}.
static func missing_skills(profile: Dictionary, req: Dictionary) -> Dictionary:
	var result := {}
	for s in req:
		if Progression.skill_level(profile, s) < int(req[s]):
			result[s] = int(req[s])
	return result


static func skills_text(req: Dictionary) -> String:
	var parts := []
	for s in req:
		parts.append("le niveau %d en %s" % [int(req[s]), Data.SKILLS[s]["label"].to_lower()])
	return " et ".join(parts)


# --- Rencontrer quelqu'un -----------------------------------------------------------------

static func can_meet(profile: Dictionary) -> bool:
	return not has_partner(profile) and missing_skills(profile, Data.FAMILY_MEET_SKILLS).is_empty()


## Quatre personnes à rencontrer : deux femmes et deux hommes, chacune avec ses goûts.
static func proposals(rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := []
	var likes: Array = Data.FAMILY_LIKES.duplicate()
	for genre in [0, 1, 0, 1]:
		var names: Array = Data.FAMILY_NAMES[genre]
		var name: String = names[rng.randi() % names.size()]
		while result.any(func(p): return p["nom"] == name):
			name = names[rng.randi() % names.size()]
		var look := Data.random_appearance(rng)
		look["body"] = genre
		if genre == 0:
			look["beard"] = 0
		var like: String = likes.pop_at(rng.randi() % likes.size())
		result.append({"nom": name, "genre": genre, "aime": like, "apparence": look})
	return result


## L'enfant choisit la personne qui lui plaît. Renvoie false si ce n'est pas possible.
static func meet(profile: Dictionary, person: Dictionary) -> bool:
	if not can_meet(profile) or str(person.get("nom", "")) == "":
		return false
	var state := _state(profile)
	state["partenaire"] = {"nom": str(person["nom"]), "genre": clampi(int(person.get("genre", 0)), 0, 1), "aime": str(person.get("aime", "")),
		"apparence": Data.complete_appearance(person.get("apparence", {}))}
	state["complicite"] = 10
	state["ensemble"] = false
	return true


## La complicité monte avec les activités en couple. Renvoie la nouvelle valeur.
static func add_complicity(profile: Dictionary, amount: int) -> int:
	if not has_partner(profile):
		return 0
	var state := _state(profile)
	state["complicite"] = clampi(int(state["complicite"]) + amount, 0, 100)
	return state["complicite"]


static func can_move_in(profile: Dictionary) -> bool:
	return has_partner(profile) and not is_together(profile) and complicity(profile) >= Data.FAMILY_MOVE_IN


static func move_in(profile: Dictionary) -> bool:
	if not can_move_in(profile):
		return false
	_state(profile)["ensemble"] = true
	return true


# --- Enfants ---------------------------------------------------------------------------

static func can_have_baby(profile: Dictionary) -> bool:
	return is_together(profile) and not has_baby(profile) and children(profile).size() < Data.FAMILY_MAX_CHILDREN \
		and missing_skills(profile, Data.FAMILY_BABY_SKILLS).is_empty()


## Pourquoi pas de bébé maintenant ("" si c'est possible).
static func baby_blocker(profile: Dictionary) -> String:
	if not is_together(profile):
		return "Il faut d'abord vivre ensemble."
	if children(profile).size() >= Data.FAMILY_MAX_CHILDREN:
		return "Votre famille est au complet."
	if has_baby(profile):
		return "Occupe-toi d'abord de %s : un bébé à la fois." % baby(profile)["nom"]
	var lack := missing_skills(profile, Data.FAMILY_BABY_SKILLS)
	if not lack.is_empty():
		return "Pour accueillir un bébé, il faut %s (fais ton planning au bureau)." % skills_text(lack)
	return ""


## Quatre prénoms pour le bébé : deux filles et deux garçons.
static func baby_names(rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := []
	for genre in [0, 1, 0, 1]:
		var names: Array = Data.CHILD_NAMES[genre]
		var name: String = names[rng.randi() % names.size()]
		while result.any(func(c): return c["nom"] == name):
			name = names[rng.randi() % names.size()]
		result.append({"nom": name, "genre": genre})
	return result


## Le bébé arrive. Il ressemble à ses parents (peau et cheveux de l'un ou de l'autre).
static func have_baby(profile: Dictionary, child: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if not can_have_baby(profile) or str(child.get("nom", "")) == "":
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var genre := clampi(int(child.get("genre", 0)), 0, 1)
	var look := Data.random_appearance(rng)
	var mine: Dictionary = Data.complete_appearance(profile.get("appearance", {}))
	var theirs: Dictionary = partner(profile)["apparence"]
	look["body"] = genre
	look["beard"] = 0
	look["glasses"] = 0
	look["skin"] = (mine if rng.randf() < 0.5 else theirs)["skin"]
	look["hair"] = (mine if rng.randf() < 0.5 else theirs)["hair"]
	var baby_state := {"nom": str(child["nom"]), "genre": genre, "age": "bebe", "soins": 0, "apparence": look}
	var state := _state(profile)
	state["enfants"].append(baby_state)
	state["choix_enfant"] = ""
	return baby_state


## Un soin au bébé (série de mots terminée). Renvoie true si le bébé vient de grandir.
static func care_baby(profile: Dictionary) -> bool:
	var b := baby(profile)
	if b.is_empty():
		return false
	b["soins"] = int(b["soins"]) + 1
	if b["soins"] >= Data.FAMILY_BABY_CARES:
		b["age"] = "enfant"
		return true
	return false


## « Pas d'enfant pour l'instant » : un choix respecté, qu'on peut changer plus tard.
static func decline_children(profile: Dictionary) -> void:
	if is_together(profile) and children(profile).is_empty():
		_state(profile)["choix_enfant"] = "non"


static func declined(profile: Dictionary) -> bool:
	return _state(profile)["choix_enfant"] == "non"


# --- Textes ---------------------------------------------------------------------------

## « Ma famille » mérite un coup d'œil : quelque chose de nouveau est possible.
static func has_news(profile: Dictionary) -> bool:
	if not _state(profile)["vu"]:
		return true
	if can_move_in(profile):
		return true
	return can_have_baby(profile) and children(profile).is_empty() and not declined(profile)


## La prochaine chose à faire, en une phrase.
static func advice(profile: Dictionary) -> String:
	match stage(profile):
		"seul":
			var lack := missing_skills(profile, Data.FAMILY_MEET_SKILLS)
			if not lack.is_empty():
				return "Pour rencontrer quelqu'un, il faut %s : parle devant le miroir ou appelle un ami." % skills_text(lack)
			return "Clique sur « Ma famille » pour rencontrer quelqu'un."
		"rencontre":
			if can_move_in(profile):
				return "Vous êtes très complices : clique sur « Ma famille » pour vivre ensemble."
			return "Clique sur le canapé pour passer du temps avec %s : chaque mot réussi fait monter la complicité." % partner_name(profile)
	if has_baby(profile):
		return "Clique sur le berceau pour t'occuper de %s." % baby(profile)["nom"]
	if has_child(profile):
		return "Clique sur les jouets ou sur le petit lit pour passer du temps avec %s." % grown(profile)[0]["nom"]
	if declined(profile):
		return "Passe du temps avec %s sur le canapé." % partner_name(profile)
	var blocker := baby_blocker(profile)
	return blocker if blocker != "" else "Clique sur « Ma famille » si vous voulez accueillir un bébé."


## Le petit texte du cadre « Ma famille » (à gauche de l'écran).
static func status_text(profile: Dictionary) -> String:
	match stage(profile):
		"seul":
			return "Rencontrer quelqu'un"
		"rencontre":
			return "%s · complicité %d %%" % [partner_name(profile), complicity(profile)]
	var names := [partner_name(profile)]
	for k in children(profile):
		names.append(k["nom"])
	return "Avec " + " et ".join(names) if names.size() <= 2 else "Avec %s, %s et %s" % names


## Étapes du rêve « fonder une famille ».
static func dream_steps(profile: Dictionary) -> Array:
	var together := is_together(profile)
	return [
		{"label": "Rencontrer quelqu'un", "done": has_partner(profile)},
		{"label": "Être très complices (%d %%)" % Data.FAMILY_MOVE_IN, "done": together or complicity(profile) >= Data.FAMILY_MOVE_IN},
		{"label": "Vivre ensemble", "done": together},
		{"label": "Accueillir un bébé", "done": not children(profile).is_empty()},
		{"label": "Voir ton enfant grandir", "done": has_child(profile)},
	]


## Pour l'adulte : la famille en une ligne.
static func summary(profile: Dictionary) -> String:
	match stage(profile):
		"seul":
			return "Famille : personne pour l'instant"
		"rencontre":
			return "Famille : a rencontré %s (complicité %d %%)" % [partner_name(profile), complicity(profile)]
	var text := "Famille : vit avec %s (complicité %d %%)" % [partner_name(profile), complicity(profile)]
	var kids := []
	for k in children(profile):
		kids.append("%s (%s)" % [k["nom"], "bébé" if k["age"] == "bebe" else "enfant"])
	if not kids.is_empty():
		text += " — enfants : " + ", ".join(kids)
	elif declined(profile):
		text += " — pas d'enfant pour l'instant (choix de l'enfant)"
	return text
