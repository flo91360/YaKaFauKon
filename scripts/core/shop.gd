extends RefCounted
## Magasin : l'enfant dépense ses pièces pour agrandir sa maison (voir Data.SHOP).
## Fonctions statiques qui travaillent sur le dictionnaire du profil.

const Data = preload("res://scripts/core/data.gd")


static func owns(profile: Dictionary, id: String) -> bool:
	return id in Data.purchases(profile)


## Pièces qui manquent pour acheter (0 si l'enfant a assez).
static func missing(profile: Dictionary, id: String) -> int:
	return maxi(int(Data.SHOP[id]["prix"]) - int(profile["money"]), 0)


static func can_buy(profile: Dictionary, id: String) -> bool:
	return Data.SHOP.has(id) and not owns(profile, id) and missing(profile, id) == 0


## Achète l'objet : retire les pièces et l'ajoute aux achats. Renvoie false si impossible.
static func buy(profile: Dictionary, id: String) -> bool:
	if not can_buy(profile, id):
		return false
	profile["money"] = int(profile["money"]) - int(Data.SHOP[id]["prix"])
	if not profile.get("achats") is Array:
		profile["achats"] = []
	profile["achats"].append(id)
	return true


## Prochain achat conseillé : le moins cher que l'enfant n'a pas encore ("" si tout est acheté).
static func next_item(profile: Dictionary) -> String:
	for id in Data.SHOP_ORDER:
		if not owns(profile, id):
			return id
	return ""


## Liste d'achats valide : identifiants connus, sans doublon (sauvegardes modifiées à la main).
static func clean(list) -> Array:
	var result := []
	if list is Array:
		for id in Data.SHOP_ORDER:
			if id in list:
				result.append(id)
	return result
