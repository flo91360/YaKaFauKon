extends RefCounted
## Règles de progression : vitesse adaptative, niveau des textes, carrières.
## Fonctions statiques qui travaillent sur le dictionnaire du profil.

const Data = preload("res://scripts/core/data.gd")

const CALIBRATION_COUNT := 6 # frappes réussies avant le premier chronomètre
const READ_MARGIN_SEC := 3.0 # temps laissé pour lire le modèle avant de taper
const SPEED_CAP_FACTOR := 2.0 # l'exigence se stabilise à 2 x la vitesse de départ
const LEVEL_UP_SUCCESSES := [0, 10, 15] # frappes réussies pour passer au niveau suivant

const DEFAULT_SETTINGS := {
	"chrono": "parfois", # jamais / parfois / souvent / toujours
	"exigence": "normale", # facile / normale / difficile
	"tolerance": "normale", # stricte / normale / large
	"niveau_texte": "auto", # auto / 1 / 2 / 3
	"vitesse_besoins": "normale", # lente / normale / rapide
	"missions_minutes": 2, # minutes réelles entre deux missions
	"aide_couleur": "oui", # lettres du modèle en vert / rouge pendant la frappe
}
const SETTING_CHOICES := {
	"chrono": ["jamais", "parfois", "souvent", "toujours"],
	"exigence": ["facile", "normale", "difficile"],
	"tolerance": ["stricte", "normale", "large"],
	"niveau_texte": ["auto", "1", "2", "3"],
	"vitesse_besoins": ["lente", "normale", "rapide"],
	"missions_minutes": [1, 2, 3, 5],
	"aide_couleur": ["oui", "non"],
}
const SETTING_LABELS := {
	"chrono": "Fréquence du chronomètre",
	"exigence": "Exigence du chronomètre",
	"tolerance": "Tolérance aux fautes",
	"niveau_texte": "Niveau des textes",
	"vitesse_besoins": "Vitesse des besoins",
	"missions_minutes": "Minutes entre deux missions",
	"aide_couleur": "Lettres en couleur pendant la frappe",
}
const EXIGENCE_FACTOR := {"facile": 0.6, "normale": 0.75, "difficile": 0.9}
const TOLERANCE_OFFSET := {"stricte": -1, "normale": 0, "large": 1}
const NEEDS_SPEED := {"lente": 0.6, "normale": 1.0, "rapide": 1.4}
const CHRONO_EVERY := {"jamais": 0, "parfois": 3, "souvent": 2, "toujours": 1}


static func setting(profile: Dictionary, key: String):
	return profile.get("settings", {}).get(key, DEFAULT_SETTINGS[key])


static func new_typing_state() -> Dictionary:
	return {"level": 1, "level_successes": 0, "samples": [], "baseline_cps": 0.0, "ema_cps": 0.0, "since_timed": 0}


# --- Vitesse adaptative --------------------------------------------------------

static func is_calibrated(profile: Dictionary) -> bool:
	return profile["typing"]["baseline_cps"] > 0.0


## Faut-il un chronomètre pour la prochaine frappe ?
static func next_is_timed(profile: Dictionary) -> bool:
	if not is_calibrated(profile):
		return false
	var every: int = CHRONO_EVERY.get(setting(profile, "chrono"), 3)
	if every <= 0:
		return false
	return profile["typing"]["since_timed"] + 1 >= every


static func time_limit(profile: Dictionary, text: String) -> float:
	var t: Dictionary = profile["typing"]
	var base: float = t["baseline_cps"]
	var current: float = maxf(t["ema_cps"], base)
	var factor: float = EXIGENCE_FACTOR.get(setting(profile, "exigence"), 0.75)
	var target := clampf(current * factor, base * 0.5, base * SPEED_CAP_FACTOR)
	return READ_MARGIN_SEC + text.length() / maxf(target, 0.3)


## Enregistre une frappe réussie (cps = caractères par seconde) ; timed = avec chronomètre.
static func record_success(profile: Dictionary, cps: float, timed: bool) -> void:
	var t: Dictionary = profile["typing"]
	if timed:
		t["since_timed"] = 0
	else:
		t["since_timed"] += 1
	if t["baseline_cps"] <= 0.0:
		t["samples"].append(cps)
		if t["samples"].size() >= CALIBRATION_COUNT:
			var sorted: Array = t["samples"].duplicate()
			sorted.sort()
			t["baseline_cps"] = sorted[sorted.size() / 2]
			t["ema_cps"] = t["baseline_cps"]
	else:
		t["ema_cps"] = t["ema_cps"] * 0.8 + cps * 0.2
	# Niveau des textes (mode automatique)
	t["level_successes"] = int(t["level_successes"]) + 1
	var level := int(t["level"])
	if level < 3 and t["level_successes"] >= LEVEL_UP_SUCCESSES[level]:
		t["level"] = level + 1
		t["level_successes"] = 0


static func record_timeout(profile: Dictionary) -> void:
	profile["typing"]["since_timed"] = 0


static func reset_calibration(profile: Dictionary) -> void:
	var t: Dictionary = profile["typing"]
	t["samples"] = []
	t["baseline_cps"] = 0.0
	t["ema_cps"] = 0.0
	t["since_timed"] = 0


static func text_level(profile: Dictionary) -> int:
	var forced = setting(profile, "niveau_texte")
	if forced != "auto":
		return clampi(int(forced), 1, 3)
	return int(profile["typing"]["level"])


static func text_for(texts: Array, profile: Dictionary) -> String:
	return texts[clampi(text_level(profile), 1, texts.size()) - 1]


# --- Compétences ---------------------------------------------------------------

static func skill_level(profile: Dictionary, skill: String) -> int:
	return Data.skill_level(profile["skills_xp"].get(skill, 0.0))


static func skill_levels(profile: Dictionary) -> Dictionary:
	var result := {}
	for s in Data.SKILLS:
		result[s] = skill_level(profile, s)
	return result


# --- Carrières -------------------------------------------------------------------

static func current_tier(profile: Dictionary) -> int:
	var c: String = profile["career"]["current"]
	if c == "":
		return 0
	return int(profile["career"]["tiers"].get(c, 1))


static func can_change_career(profile: Dictionary) -> bool:
	return profile["career"]["current"] == "" or current_tier(profile) >= Data.CAREER_CHANGE_MIN_TIER


## Choisit ou change de carrière. L'ancien palier est conservé, la nouvelle
## carrière commence au palier 1 (ou reprend son palier si déjà essayée).
static func choose_career(profile: Dictionary, career: String) -> bool:
	if not Data.CAREERS.has(career) or career == profile["career"]["current"]:
		return false
	if not can_change_career(profile):
		return false
	profile["career"]["current"] = career
	if not profile["career"]["tiers"].has(career):
		profile["career"]["tiers"][career] = 1
		profile["career"]["missions"][career] = 0
	return true


## Compétences manquantes pour le palier suivant : {skill: niveau requis}.
static func missing_for_next_tier(profile: Dictionary) -> Dictionary:
	var c: String = profile["career"]["current"]
	var tier := current_tier(profile)
	var missing := {}
	if c == "" or tier >= 5:
		return missing
	var req: Dictionary = Data.CAREERS[c]["tiers"][tier]["req"]
	for s in req:
		if skill_level(profile, s) < req[s]:
			missing[s] = req[s]
	return missing


static func salary(profile: Dictionary) -> int:
	var c: String = profile["career"]["current"]
	if c == "":
		return 0
	return Data.CAREERS[c]["tiers"][current_tier(profile) - 1]["salary"]


## Après une mission réussie (le salaire est versé à part avec salary()). Renvoie true si le personnage monte d'un palier.
static func complete_mission(profile: Dictionary) -> bool:
	var c: String = profile["career"]["current"]
	if c == "":
		return false
	profile["career"]["missions"][c] = profile["career"]["missions"].get(c, 0) + 1
	return try_promotion(profile)


static func try_promotion(profile: Dictionary) -> bool:
	var c: String = profile["career"]["current"]
	var tier := current_tier(profile)
	if c == "" or tier >= 5:
		return false
	if profile["career"]["missions"].get(c, 0) < Data.MISSIONS_PER_TIER:
		return false
	if not missing_for_next_tier(profile).is_empty():
		return false
	profile["career"]["tiers"][c] = tier + 1
	profile["career"]["missions"][c] = 0
	return true
