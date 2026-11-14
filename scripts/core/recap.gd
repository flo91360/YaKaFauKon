extends RefCounted
## Calculs du récapitulatif pour l'ergothérapeute (tout reste en local).

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Dreams = preload("res://scripts/core/dreams.gd")

const ERROR_LABELS := {
	"substitution": "lettres remplacées", "oubli": "lettres oubliées", "ajout": "lettres en trop",
	"inversion": "lettres inversées", "accents": "accents oubliés (tolérés)", "majuscules": "majuscules (tolérées)",
}
const COUNTED_ERRORS := ["substitution", "oubli", "ajout", "inversion"]


## Vitesse en caractères par minute.
static func speed_cpm(s: Dictionary) -> float:
	var t: float = s.get("temps_frappe_sec", 0.0)
	return s.get("caracteres", 0) / t * 60.0 if t > 0.0 else 0.0


static func error_count(s: Dictionary) -> int:
	var total := 0
	for k in COUNTED_ERRORS:
		total += int(s.get("erreurs", {}).get(k, 0))
	return total


static func red_any_sec(s: Dictionary) -> float:
	return s.get("rouge_au_moins_une_sec", 0.0)


static func session_lines(s: Dictionary) -> Array:
	var lines := []
	lines.append("Temps de jeu : %s" % format_duration(s.get("duree_sec", 0.0)))
	var cpm := speed_cpm(s)
	lines.append("Vitesse de frappe moyenne : %d caractères/min (environ %d mots/min)" % [roundi(cpm), roundi(cpm / 5.0)])
	lines.append("Frappes réussies : %d — ratées (trop de fautes) : %d" % [s.get("frappes_ok", 0), s.get("frappes_ratees", 0)])
	lines.append("Chronomètres réussis : %d — trop lents : %d" % [s.get("chronos_reussis", 0), s.get("chronos_rates", 0)])
	var errs := []
	for k in ERROR_LABELS:
		var n: int = int(s.get("erreurs", {}).get(k, 0))
		if n > 0:
			errs.append("%s : %d" % [ERROR_LABELS[k], n])
	lines.append("Erreurs : " + (", ".join(errs) if not errs.is_empty() else "aucune"))
	lines.append("Missions réussies : %d — abandonnées : %d" % [s.get("missions_reussies", 0), s.get("missions_abandonnees", 0)])
	var total_choices: int = s.get("choix_total", 0)
	if total_choices > 0:
		lines.append("Choix justes du premier coup : %d sur %d" % [s.get("choix_justes_du_premier_coup", 0), total_choices])
	lines.append("Tâches terminées : %d — abandonnées : %d" % [s.get("taches_finies", 0), s.get("taches_abandonnees", 0)])
	if s.has("series_finies"): # séances de la version 2
		var by_activity := []
		var words: Dictionary = s.get("mots_par_activite", {})
		for a in words:
			if Data.ACTIONS.has(a):
				by_activity.append("%s : %d" % [Data.ACTIONS[a]["label"].to_lower(), int(words[a])])
		lines.append("Mots de champ lexical réussis : %d%s" % [int(s.get("mots_ok", 0)), " (" + ", ".join(by_activity) + ")" if not by_activity.is_empty() else ""])
		lines.append("Séries de 5 mots terminées : %d — arrêtées avant la fin : %d" % [int(s.get("series_finies", 0)), int(s.get("series_interrompues", 0))])
		lines.append("Objectifs choisis : %d — atteints : %d — changés en cours : %d" % [int(s.get("objectifs_choisis", 0)), int(s.get("objectifs_finis", 0)), int(s.get("objectifs_abandonnes", 0))])
	var bought: Array = s.get("achats", []) if s.get("achats", []) is Array else []
	if not bought.is_empty(): # séances de la version 2.1
		var names := []
		for id in bought:
			if Data.SHOP.has(id):
				names.append(Data.SHOP[id]["label"].to_lower())
		lines.append("Achats au magasin : %s (%d pièces dépensées)" % [", ".join(names), int(s.get("argent_depense", 0))])
	var dreams_done: Array = s.get("reves_realises", []) if s.get("reves_realises", []) is Array else []
	if not dreams_done.is_empty(): # séances de la version 2.2
		var labels := []
		for d in dreams_done:
			if Data.DREAMS.has(d):
				labels.append(Data.DREAMS[d]["label"].to_lower())
		lines.append("Rêve réalisé : %s" % ", ".join(labels))
	if int(s.get("reves_changes", 0)) > 0:
		lines.append("A changé de rêve : %d fois" % int(s.get("reves_changes", 0)))
	lines.append("Temps avec au moins une jauge dans le rouge : %s" % format_duration(red_any_sec(s)))
	return lines


## Où en est l'objectif de vie (« Mon rêve »), en une ligne.
static func dream_line(profile: Dictionary) -> String:
	var dream := Dreams.current(profile)
	var parts := []
	if dream == "":
		parts.append("pas encore choisi")
	elif Dreams.is_done(profile):
		parts.append("%s (réalisé)" % Data.DREAMS[dream]["label"].to_lower())
	else:
		parts.append("%s, %d étape(s) sur %d" % [Data.DREAMS[dream]["label"].to_lower(), Dreams.steps_done(profile), Dreams.steps(profile).size()])
	var others := []
	for d in Dreams.achieved(profile):
		if d != dream:
			others.append(Data.DREAMS[d]["label"].to_lower())
	if not others.is_empty():
		parts.append("déjà réalisé : %s" % ", ".join(others))
	var changes := int(profile.get("reve", {}).get("changements", 0))
	if changes > 0:
		parts.append("changé %d fois en cours de route" % changes)
	return "Rêve : " + " — ".join(parts)


static func format_duration(sec: float) -> String:
	var total := int(sec)
	if total < 60:
		return "%d s" % total
	return "%d min %02d s" % [total / 60, total % 60]


## Synthèse sur toutes les séances.
static func overview(profile: Dictionary) -> Dictionary:
	var sessions: Array = profile.get("sessions", [])
	var o := {"seances": sessions.size(), "duree": 0.0, "finies": 0, "abandons": 0, "rouge": 0.0,
		"missions": 0, "choix_ok": 0, "choix": 0, "caracteres": 0, "erreurs": 0, "rouge_par_besoin": {},
		"erreurs_par_type": {}, "mots": 0, "series_finies": 0, "series_interrompues": 0,
		"objectifs_choisis": 0, "objectifs_finis": 0, "objectifs_abandonnes": 0}
	for s in sessions:
		o["duree"] += s.get("duree_sec", 0.0)
		o["finies"] += int(s.get("taches_finies", 0))
		o["abandons"] += int(s.get("taches_abandonnees", 0))
		o["rouge"] += red_any_sec(s)
		o["missions"] += int(s.get("missions_reussies", 0))
		o["choix_ok"] += int(s.get("choix_justes_du_premier_coup", 0))
		o["choix"] += int(s.get("choix_total", 0))
		o["caracteres"] += int(s.get("caracteres", 0))
		o["erreurs"] += error_count(s)
		for key in ["series_finies", "series_interrompues", "objectifs_choisis", "objectifs_finis", "objectifs_abandonnes"]:
			o[key] += int(s.get(key, 0))
		o["mots"] += int(s.get("mots_ok", 0))
		for n in s.get("rouge_sec", {}):
			o["rouge_par_besoin"][n] = o["rouge_par_besoin"].get(n, 0.0) + s["rouge_sec"][n]
		for k in COUNTED_ERRORS:
			o["erreurs_par_type"][k] = o["erreurs_par_type"].get(k, 0) + int(s.get("erreurs", {}).get(k, 0))
	var speeds := []
	for s in sessions:
		if s.get("frappes_ok", 0) > 0:
			speeds.append(speed_cpm(s))
	o["vitesses"] = speeds
	return o


## Quelques mots-clés simples pour résumer l'évolution.
static func keywords(profile: Dictionary) -> Array:
	var o := overview(profile)
	var words := []
	var speeds: Array = o["vitesses"]
	if speeds.size() >= 2:
		var n := mini(3, speeds.size() / 2)
		var first := _mean(speeds.slice(0, n))
		var last := _mean(speeds.slice(speeds.size() - n))
		if last > first * 1.1:
			words.append("Vitesse en progrès")
		elif last < first * 0.9:
			words.append("Vitesse en baisse")
		else:
			words.append("Vitesse stable")
	elif speeds.size() == 1:
		words.append("Première séance")
	if o["caracteres"] > 0:
		var rate: float = float(o["erreurs"]) / o["caracteres"]
		if rate < 0.05:
			words.append("Frappe précise")
		elif rate < 0.12:
			words.append("Quelques fautes")
		else:
			words.append("Fautes fréquentes")
		var top := ""
		for k in o["erreurs_par_type"]:
			if top == "" or o["erreurs_par_type"][k] > o["erreurs_par_type"][top]:
				top = k
		if top != "" and o["erreurs_par_type"][top] > 0:
			words.append("Surtout : " + ERROR_LABELS[top])
	var tasks: int = o["finies"] + o["abandons"]
	if tasks > 0:
		var ratio: float = float(o["finies"]) / tasks
		words.append("Persévérant" if ratio >= 0.85 else ("Persévérance moyenne" if ratio >= 0.6 else "Abandonne souvent"))
	if o["duree"] > 0.0:
		var red_share: float = o["rouge"] / o["duree"]
		words.append("Besoins bien gérés" if red_share < 0.1 else ("Besoins parfois oubliés" if red_share < 0.25 else "Besoins souvent dans le rouge"))
		var worst := ""
		for n in o["rouge_par_besoin"]:
			if worst == "" or o["rouge_par_besoin"][n] > o["rouge_par_besoin"][worst]:
				worst = n
		if worst != "" and o["rouge_par_besoin"][worst] > 60.0:
			words.append("À surveiller : " + Data.NEEDS[worst]["label"].to_lower())
	if o["choix"] > 0:
		words.append("Consignes bien comprises" if float(o["choix_ok"]) / o["choix"] >= 0.8 else "Relire les consignes")
	if o["missions"] > 0:
		words.append("%d mission(s) réussie(s)" % o["missions"])
	var series: int = o["series_finies"] + o["series_interrompues"]
	if series >= 3:
		words.append("Va au bout des séries de mots" if float(o["series_finies"]) / series >= 0.8 else "Arrête souvent les séries de mots")
	if o["objectifs_finis"] > 0:
		words.append("%d objectif(s) atteint(s)" % o["objectifs_finis"])
	return words


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


## Évolution des compétences entre la première séance et maintenant.
static func skills_progress(profile: Dictionary) -> Array:
	var lines := []
	var sessions: Array = profile.get("sessions", [])
	var start: Dictionary = sessions[0].get("competences_debut", {}) if not sessions.is_empty() else {}
	for s in Data.visible_skills(profile):
		var now := Progression.skill_level(profile, s)
		lines.append("%s : %d → %d sur 10" % [Data.SKILLS[s]["label"], int(start.get(s, 0)), now])
	return lines
