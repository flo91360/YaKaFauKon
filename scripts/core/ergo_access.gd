extends RefCounted
## Mot d'accès de l'espace ergothérapeute. Il est choisi par l'ergo et gardé sur
## ce PC sous forme hachée (SHA-256 avec un sel), jamais en clair.
## Tant qu'aucun mot n'est choisi, le mot de départ « ergo » ouvre l'espace une
## fois, puis le jeu demande d'en choisir un autre.

const DEFAULT_WORD := "ergo"
const MIN_LENGTH := 6


## Mot comparé sans tenir compte des majuscules ni des espaces autour.
static func normalize(word: String) -> String:
	return word.strip_edges().to_lower()


static func hash_word(word: String, salt: String) -> String:
	return (salt + ":" + normalize(word)).sha256_text()


## True si l'ergo a déjà choisi son propre mot.
static func is_set(data: Dictionary) -> bool:
	return str(data.get("hache", "")) != "" and str(data.get("sel", "")) != ""


static func check(data: Dictionary, word: String) -> bool:
	if not is_set(data):
		return normalize(word) == DEFAULT_WORD
	return hash_word(word, str(data["sel"])) == str(data["hache"])


## Raison du refus d'un nouveau mot, ou "" s'il convient.
static func refusal(word: String, confirm: String) -> String:
	var w := normalize(word)
	if w.length() < MIN_LENGTH:
		return "Le mot doit avoir au moins %d caractères." % MIN_LENGTH
	if w == DEFAULT_WORD:
		return "Choisis un mot différent de « ergo »."
	if w != normalize(confirm):
		return "Les deux mots ne sont pas pareils."
	return ""


static func make(word: String) -> Dictionary:
	var salt := ""
	for i in 16:
		salt += "%02x" % (randi() % 256)
	return {"sel": salt, "hache": hash_word(word, salt)}


## Prénom tel qu'il apparaît sur « Qui joue ? » : entier, ou seulement l'initiale.
static func display_name(name: String, hide: bool) -> String:
	var n := name.strip_edges()
	if not hide or n == "":
		return n
	return n.substr(0, 1).to_upper() + "."


## Prénoms déjà pris (comparés sans majuscules ni accents).
static func is_duplicate(name: String, existing: Array) -> bool:
	var key := _fold(name)
	for e in existing:
		if _fold(str(e)) == key:
			return true
	return false


static func _fold(text: String) -> String:
	var t := text.strip_edges().to_lower()
	var from := "àâäáãéèêëíìîïóòôöõúùûüçñÿ"
	var to := "aaaaaeeeeiiiiooooouuuucny"
	for i in from.length():
		t = t.replace(from[i], to[i])
	return t
