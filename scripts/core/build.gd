extends RefCounted
## Jardin : les ressources récoltées (bois, pierres) et ce que l'enfant construit
## avec elles (voir Data.RESOURCES et Data.CONSTRUCTIONS).
## Fonctions statiques qui travaillent sur le dictionnaire du profil.

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")


# --- Ressources ------------------------------------------------------------------------

static func new_stock() -> Dictionary:
	var stock := {}
	for res in Data.RESOURCE_ORDER:
		stock[res] = 0
	return stock


## Réserve valide : ressources connues, nombres entiers positifs (sauvegardes modifiées à la main).
static func clean_stock(stock) -> Dictionary:
	var result := new_stock()
	if stock is Dictionary:
		for res in result:
			if typeof(stock.get(res)) in [TYPE_INT, TYPE_FLOAT]:
				result[res] = maxi(int(stock[res]), 0)
	return result


static func stock(profile: Dictionary, res: String) -> int:
	var all = profile.get("ressources", {})
	return int(all.get(res, 0)) if all is Dictionary else 0


## Ajoute des ressources à la réserve. Renvoie la nouvelle quantité.
static func add(profile: Dictionary, res: String, amount: int) -> int:
	if not profile.get("ressources") is Dictionary:
		profile["ressources"] = new_stock()
	profile["ressources"][res] = stock(profile, res) + maxi(amount, 0)
	return profile["ressources"][res]


# --- Constructions -----------------------------------------------------------------------

static func owns(profile: Dictionary, id: String) -> bool:
	return id in Data.constructions(profile)


## Ressources qui manquent : {ressource: quantité} (vide si l'enfant a tout).
static func missing_resources(profile: Dictionary, id: String) -> Dictionary:
	var result := {}
	var cost: Dictionary = Data.CONSTRUCTIONS[id]["cout"]
	for res in cost:
		var lack := int(cost[res]) - stock(profile, res)
		if lack > 0:
			result[res] = lack
	return result


## Compétences trop basses : {compétence: niveau demandé} (vide si tout va bien).
static func missing_skills(profile: Dictionary, id: String) -> Dictionary:
	var result := {}
	var req: Dictionary = Data.CONSTRUCTIONS[id]["competences"]
	for s in req:
		if Progression.skill_level(profile, s) < int(req[s]):
			result[s] = int(req[s])
	return result


static func can_build(profile: Dictionary, id: String) -> bool:
	return Data.CONSTRUCTIONS.has(id) and not owns(profile, id) \
		and missing_resources(profile, id).is_empty() and missing_skills(profile, id).is_empty()


## Construit : retire les ressources et note la construction. Renvoie false si impossible.
static func build(profile: Dictionary, id: String) -> bool:
	if not can_build(profile, id):
		return false
	var cost: Dictionary = Data.CONSTRUCTIONS[id]["cout"]
	for res in cost:
		profile["ressources"][res] = stock(profile, res) - int(cost[res])
	if not profile.get("constructions") is Array:
		profile["constructions"] = []
	profile["constructions"].append(id)
	return true


## Prochaine construction conseillée ("" si tout est construit).
static func next_item(profile: Dictionary) -> String:
	for id in Data.CONSTRUCTION_ORDER:
		if not owns(profile, id):
			return id
	return ""


## Avancement vers une construction, entre 0 et 1 (ressources réunies sur ressources demandées).
static func fraction(profile: Dictionary, id: String) -> float:
	var cost: Dictionary = Data.CONSTRUCTIONS[id]["cout"]
	var have := 0
	var total := 0
	for res in cost:
		total += int(cost[res])
		have += mini(stock(profile, res), int(cost[res]))
	return float(have) / maxi(total, 1)


## « 6 bûches et 8 pierres ».
static func cost_text(id: String) -> String:
	var parts := []
	var cost: Dictionary = Data.CONSTRUCTIONS[id]["cout"]
	for res in Data.RESOURCE_ORDER:
		if cost.has(res):
			parts.append(Data.resource_text(res, int(cost[res])))
	return " et ".join(parts)


## Ce qu'il reste à faire avant de construire, en une phrase ("" si tout est prêt).
static func advice(profile: Dictionary, id: String) -> String:
	var parts := []
	var lack := missing_resources(profile, id)
	for res in Data.RESOURCE_ORDER:
		if lack.has(res):
			parts.append("encore " + Data.resource_text(res, int(lack[res])))
	var skills := missing_skills(profile, id)
	for s in skills:
		parts.append("%s au niveau %d" % [Data.SKILLS[s]["label"].to_lower(), int(skills[s])])
	if parts.is_empty():
		return ""
	return "Il te faut " + ", ".join(parts) + "."


## Liste de constructions valide : identifiants connus, sans doublon.
static func clean(list) -> Array:
	var result := []
	if list is Array:
		for id in Data.CONSTRUCTION_ORDER:
			if id in list:
				result.append(id)
	return result
