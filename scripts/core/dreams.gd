extends RefCounted
## Objectif de vie (« Mon rêve ») : l'enfant le choisit en début de partie, le jeu
## montre les étapes pour y arriver et le fête quand il est réalisé.
## Fonctions statiques qui travaillent sur le dictionnaire du profil :
## profile["reve"] = {"id": rêve en cours ("" = pas choisi), "fete": le rêve en cours
## a déjà été fêté, "changements": nombre de changements, "realises": [rêves réalisés]}.

const Data = preload("res://scripts/core/data.gd")
const Shop = preload("res://scripts/core/shop.gd")


static func new_state() -> Dictionary:
	return {"id": "", "fete": false, "changements": 0, "realises": []}


## Remet en ordre l'état lu dans une sauvegarde.
static func clean(state) -> Dictionary:
	var result := new_state()
	if not state is Dictionary:
		return result
	var id := str(state.get("id", ""))
	result["id"] = id if Data.DREAMS.has(id) else ""
	result["changements"] = int(state.get("changements", 0))
	var done = state.get("realises", [])
	if done is Array:
		for d in done:
			if Data.DREAMS.has(str(d)) and not str(d) in result["realises"]:
				result["realises"].append(str(d))
	result["fete"] = bool(state.get("fete", false)) and result["id"] in result["realises"]
	return result


static func _state(profile: Dictionary) -> Dictionary:
	if not profile.get("reve") is Dictionary:
		profile["reve"] = new_state()
	return profile["reve"]


## Rêve en cours ("" s'il n'est pas encore choisi).
static func current(profile: Dictionary) -> String:
	return _state(profile)["id"]


static func has_current(profile: Dictionary) -> bool:
	return current(profile) != ""


static func achieved(profile: Dictionary) -> Array:
	return _state(profile)["realises"]


## Choisit un rêve. Renvoie true si c'est un changement en cours de route
## (l'ancien rêve n'était pas réalisé) : c'est noté pour l'ergothérapeute.
static func choose(profile: Dictionary, dream: String) -> bool:
	if not Data.DREAMS.has(dream):
		return false
	var state := _state(profile)
	var old: String = state["id"]
	if old == dream:
		return false
	var changed: bool = old != "" and not old in state["realises"]
	if changed:
		state["changements"] = int(state["changements"]) + 1
	state["id"] = dream
	state["fete"] = dream in state["realises"]
	return changed


## Étapes du rêve : [{"label": texte, "done": bool}].
static func steps(profile: Dictionary, dream: String = "") -> Array:
	if dream == "":
		dream = current(profile)
	var result := []
	if dream == "":
		return result
	var career: String = Data.DREAMS[dream]["career"]
	if career == "":
		for item in Data.SHOP_ORDER:
			result.append({"label": "Acheter : %s" % Data.SHOP[item]["label"].to_lower(), "done": Shop.owns(profile, item)})
		return result
	var tier := int(profile["career"]["tiers"].get(career, 0))
	var info: Dictionary = Data.CAREERS[career]
	result.append({"label": "Choisir le travail : %s" % info["label"], "done": tier >= 1})
	for t in range(2, 6):
		var title: String = info["tiers"][t - 1]["title"]
		result.append({"label": "Devenir %s" % (title.left(1).to_lower() + title.substr(1)), "done": tier >= t})
	return result


static func steps_done(profile: Dictionary, dream: String = "") -> int:
	var n := 0
	for s in steps(profile, dream):
		if s["done"]:
			n += 1
	return n


## Avancement entre 0 et 1.
static func fraction(profile: Dictionary, dream: String = "") -> float:
	var all := steps(profile, dream)
	if all.is_empty():
		return 0.0
	return float(steps_done(profile, dream)) / all.size()


static func is_done(profile: Dictionary, dream: String = "") -> bool:
	var all := steps(profile, dream)
	return not all.is_empty() and steps_done(profile, dream) == all.size()


## Prochaine étape à franchir ("" si le rêve est réalisé ou pas choisi).
static func next_step(profile: Dictionary) -> String:
	for s in steps(profile):
		if not s["done"]:
			return s["label"]
	return ""


## Conseil pour la prochaine étape.
static func advice(profile: Dictionary) -> String:
	var dream := current(profile)
	if dream == "" or is_done(profile):
		return ""
	var career: String = Data.DREAMS[dream]["career"]
	if career == "":
		return "Gagne des pièces avec les objectifs et le travail, puis clique sur « Magasin »."
	var now: String = profile["career"]["current"]
	if now == career:
		return "Réussis tes missions et monte les compétences demandées : tout est dans « Travail »."
	if now == "":
		return "Clique sur « Travail » et choisis : %s." % Data.CAREERS[career]["label"]
	return "Tu pourras changer de travail à partir du palier %d : continue tes missions, puis clique sur « Travail »." % Data.CAREER_CHANGE_MIN_TIER


## Le rêve en cours vient-il d'être réalisé (et pas encore fêté) ?
static func to_celebrate(profile: Dictionary) -> bool:
	return has_current(profile) and not _state(profile)["fete"] and is_done(profile)


## Fête le rêve réalisé : renvoie la récompense {pieces, etoiles, label} et la note
## dans le profil. (Les pièces sont à verser par l'appelant.)
static func claim(profile: Dictionary) -> Dictionary:
	if not to_celebrate(profile):
		return {}
	var state := _state(profile)
	state["fete"] = true
	if not state["id"] in state["realises"]:
		state["realises"].append(state["id"])
	profile["etoiles"] = int(profile.get("etoiles", 0)) + Data.DREAM_REWARD_STARS
	return {"pieces": Data.DREAM_REWARD_PIECES, "etoiles": Data.DREAM_REWARD_STARS, "label": Data.DREAMS[state["id"]]["label"]}


## Cet objectif à choix fait-il avancer le rêve en cours ?
static func helps(profile: Dictionary, offer: Dictionary) -> bool:
	var dream := current(profile)
	if dream == "" or is_done(profile):
		return false
	var career: String = Data.DREAMS[dream]["career"]
	if career == "":
		return offer["type"] in ["achat", "argent"]
	var now: String = profile["career"]["current"]
	if now == "":
		return offer["type"] == "metier"
	if now != career: # il faut d'abord atteindre le palier qui permet de changer
		return offer["type"] in ["missions", "palier"] and int(profile["career"]["tiers"].get(now, 1)) < Data.CAREER_CHANGE_MIN_TIER
	if offer["type"] in ["missions", "palier"]:
		return true
	if offer["type"] == "competence":
		var tier := int(profile["career"]["tiers"].get(career, 1))
		if tier >= 5:
			return false
		var req: Dictionary = Data.CAREERS[career]["tiers"][tier]["req"]
		return req.has(offer["skill"]) and int(offer["target"]) <= int(req[offer["skill"]])
	return false
