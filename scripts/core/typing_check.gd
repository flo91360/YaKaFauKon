extends RefCounted
## Comparaison tolérante entre le texte modèle et ce que l'enfant a tapé.
## - accents et majuscules ignorés (mais comptés pour le récapitulatif) ;
## - 1 erreur admise sur un mot seul, 2 sur un texte de plusieurs mots
##   (réglable : stricte = une de moins, large = une de plus).

const ACCENTS := {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a",
	"é": "e", "è": "e", "ê": "e", "ë": "e",
	"î": "i", "ï": "i", "í": "i", "ì": "i",
	"ô": "o", "ö": "o", "ó": "o", "ò": "o",
	"ù": "u", "û": "u", "ü": "u", "ú": "u",
	"ç": "c", "ÿ": "y", "ñ": "n", "œ": "oe", "æ": "ae",
}


static func clean_spaces(text: String) -> String:
	var t := text.replace("’", "'").replace("\t", " ").strip_edges()
	while t.contains("  "):
		t = t.replace("  ", " ")
	while t.length() > 0 and ".!?;,".contains(t[t.length() - 1]):
		t = t.substr(0, t.length() - 1).strip_edges()
	return t


static func strip_accents(text: String) -> String:
	var out := ""
	for c in text:
		out += ACCENTS.get(c, c)
	return out


static func normalize(text: String) -> String:
	return strip_accents(clean_spaces(text).to_lower())


static func allowed_errors(model: String, tolerance_offset := 0) -> int:
	var base := 1 if not normalize(model).contains(" ") else 2
	return maxi(base + tolerance_offset, 0)


## Renvoie un dictionnaire :
## ok, errors, allowed, details {substitution, oubli, ajout, inversion, accents, majuscules}
static func check(model: String, typed: String, tolerance_offset := 0) -> Dictionary:
	var a := normalize(model)
	var b := normalize(typed)
	var details := _edit_details(a, b)
	var errors: int = details["substitution"] + details["oubli"] + details["ajout"] + details["inversion"]
	# Fautes ignorées, mais notées pour l'ergothérapeute.
	var raw_model := clean_spaces(model)
	var raw_typed := clean_spaces(typed)
	var lower_dist := distance(raw_model.to_lower(), raw_typed.to_lower())
	details["accents"] = maxi(lower_dist - errors, 0)
	details["majuscules"] = maxi(distance(raw_model, raw_typed) - lower_dist, 0)
	var allowed := allowed_errors(model, tolerance_offset)
	return {"ok": b.length() > 0 and errors <= allowed, "errors": errors, "allowed": allowed, "details": details}


## Distance d'édition (avec inversion de deux lettres voisines).
static func distance(a: String, b: String) -> int:
	return _matrix(a, b)[a.length()][b.length()]


static func _matrix(a: String, b: String) -> Array:
	var n := a.length()
	var m := b.length()
	var d := []
	for i in n + 1:
		var row := []
		row.resize(m + 1)
		d.append(row)
	for i in n + 1:
		d[i][0] = i
	for j in m + 1:
		d[0][j] = j
	for i in range(1, n + 1):
		for j in range(1, m + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			var best: int = mini(mini(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost)
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1] and a[i - 1] != a[i - 2]:
				best = mini(best, d[i - 2][j - 2] + 1)
			d[i][j] = best
	return d


static func _edit_details(a: String, b: String) -> Dictionary:
	var details := {"substitution": 0, "oubli": 0, "ajout": 0, "inversion": 0}
	var d := _matrix(a, b)
	var i := a.length()
	var j := b.length()
	while i > 0 or j > 0:
		if i > 0 and j > 0 and a[i - 1] == b[j - 1] and d[i][j] == d[i - 1][j - 1]:
			i -= 1
			j -= 1
		elif i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1] and a[i - 1] != a[i - 2] and d[i][j] == d[i - 2][j - 2] + 1:
			details["inversion"] += 1
			i -= 2
			j -= 2
		elif i > 0 and j > 0 and d[i][j] == d[i - 1][j - 1] + 1:
			details["substitution"] += 1
			i -= 1
			j -= 1
		elif i > 0 and d[i][j] == d[i - 1][j] + 1:
			details["oubli"] += 1 # lettre du modèle oubliée
			i -= 1
		else:
			details["ajout"] += 1 # lettre en trop
			j -= 1
	return details
