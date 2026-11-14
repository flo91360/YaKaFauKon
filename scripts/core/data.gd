extends RefCounted
## Données du jeu (besoins, actions, compétences, carrières, missions).
## Tout est décrit ici sous forme de dictionnaires pour pouvoir ajouter
## facilement de nouvelles activités, compétences ou carrières.

# --- Besoins --------------------------------------------------------------
# decay = points perdus par heure de jeu (1 heure de jeu = 1 minute réelle).
const NEEDS := {
	"faim": {"label": "Faim", "decay": 14.0, "alerte": "a très faim !", "conseil": "Va à la cuisine pour manger."},
	"sommeil": {"label": "Sommeil", "decay": 7.0, "alerte": "est très fatigué !", "conseil": "Va dormir dans le lit."},
	"toilettes": {"label": "Toilettes", "decay": 16.0, "alerte": "doit aller aux toilettes !", "conseil": "Va aux toilettes."},
	"hygiene": {"label": "Hygiène", "decay": 9.0, "alerte": "a besoin de se laver !", "conseil": "Prends une douche ou brosse-toi les dents."},
	"social": {"label": "Vie sociale", "decay": 8.0, "alerte": "se sent seul !", "conseil": "Appelle un ami ou invite des amis."},
}
const NEED_ORDER := ["faim", "sommeil", "toilettes", "hygiene", "social"]
const RED_THRESHOLD := 25.0
const ORANGE_THRESHOLD := 50.0

# --- Compétences -------------------------------------------------------------
# Une compétence se voit dans le jeu dès qu'une activité que l'enfant possède
# l'entraîne (voir available_skills) : certaines arrivent avec le magasin.
const SKILLS := {
	"physique": {"label": "Physique", "active": true},
	"creativite": {"label": "Créativité", "active": true},
	"charisme": {"label": "Charisme", "active": true},
	"organisation": {"label": "Organisation", "active": true},
	"humour": {"label": "Humour", "active": true},
	"logique": {"label": "Logique", "active": true},
	"sociabilite": {"label": "Sociabilité", "active": true},
	"patience": {"label": "Patience", "active": true},
	"responsabilite": {"label": "Responsabilité", "active": true},
	"douceur": {"label": "Douceur", "active": true},
}
const SKILL_MAX := 10

## XP total nécessaire pour atteindre le niveau `level`.
static func xp_for_level(level: int) -> int:
	return 10 * level * (level + 1)


static func skill_level(xp: float) -> int:
	var level := 0
	while level < SKILL_MAX and xp >= xp_for_level(level + 1):
		level += 1
	return level


static func active_skills() -> Array:
	var result := []
	for id in SKILLS:
		if SKILLS[id]["active"]:
			result.append(id)
	return result


# --- Objets et actions ------------------------------------------------------
# texts = [niveau 1 : mot-clé, niveau 2 : article + mot, niveau 3 : petite phrase]
# minutes = durée en minutes de jeu ; needs = effet total sur les besoins ;
# skills = XP gagnée ; sleep = le temps passe plus vite pendant l'action ;
# anim = animation du personnage pendant l'action ;
# achat = l'action demande un achat du magasin (voir SHOP).
# Les actions qui donnent de la compétence se jouent en « série de mots » : après le
# mot de départ, l'enfant tape WORDS_PER_SERIES mots du champ lexical (voir LEXIQUE).
const ACTIONS := {
	"dormir": {"anim": "sleep", "label": "Dormir", "texts": ["lit", "le lit", "aller au lit"], "minutes": 480,
		"needs": {"sommeil": 100.0}, "skills": {}, "sleep": true, "verbe": "dort"},
	"manger": {"anim": "eat", "label": "Manger", "texts": ["repas", "un repas", "manger un repas"], "minutes": 30,
		"needs": {"faim": 70.0}, "skills": {}, "verbe": "mange"},
	"cuisiner": {"anim": "cook", "label": "Faire la cuisine", "texts": ["cuisine", "la cuisine", "faire la cuisine"], "minutes": 60,
		"needs": {"faim": 45.0, "hygiene": -5.0}, "skills": {"organisation": 10.0, "creativite": 6.0}, "verbe": "cuisine"},
	"toilettes": {"anim": "sit_read", "label": "Aller aux toilettes", "texts": ["toilettes", "les toilettes", "aller aux toilettes"], "minutes": 10,
		"needs": {"toilettes": 100.0}, "skills": {}, "verbe": "est aux toilettes"},
	"douche": {"anim": "shower", "label": "Prendre une douche", "texts": ["douche", "la douche", "prendre une douche"], "minutes": 20,
		"needs": {"hygiene": 75.0}, "skills": {}, "verbe": "se douche"},
	"dents": {"anim": "brush", "label": "Se brosser les dents", "texts": ["dents", "les dents", "se brosser les dents"], "minutes": 5,
		"needs": {"hygiene": 30.0}, "skills": {}, "verbe": "se brosse les dents"},
	"appeler": {"anim": "sit_phone", "label": "Appeler un ami", "texts": ["ami", "un ami", "appeler un ami"], "minutes": 30,
		"needs": {"social": 45.0}, "skills": {"charisme": 4.0}, "verbe": "téléphone"},
	"inviter": {"anim": "sit_chat", "label": "Inviter des amis", "texts": ["amis", "des amis", "inviter des amis"], "minutes": 90,
		"needs": {"social": 80.0, "faim": -10.0}, "skills": {"charisme": 8.0, "humour": 6.0}, "verbe": "reçoit des amis"},
	"sport": {"anim": "run", "label": "Faire du sport", "texts": ["sport", "le sport", "faire du sport"], "minutes": 45,
		"needs": {"hygiene": -20.0, "sommeil": -10.0}, "skills": {"physique": 12.0}, "verbe": "fait du sport"},
	"peindre": {"anim": "paint", "label": "Peindre", "texts": ["peinture", "la peinture", "faire de la peinture"], "minutes": 45,
		"needs": {}, "skills": {"creativite": 12.0}, "verbe": "peint"},
	"miroir": {"anim": "talk", "label": "Parler devant le miroir", "texts": ["miroir", "le miroir", "parler au miroir"], "minutes": 30,
		"needs": {}, "skills": {"charisme": 12.0}, "verbe": "parle au miroir"},
	"bois": {"anim": "hammer", "label": "Travailler le bois", "texts": ["bois", "le bois", "travailler le bois"], "minutes": 60,
		"needs": {"hygiene": -10.0}, "skills": {"physique": 6.0, "creativite": 6.0}, "verbe": "travaille le bois"},
	"planning": {"anim": "sit_write", "label": "Faire mon planning", "texts": ["planning", "le planning", "faire mon planning"], "minutes": 30,
		"needs": {}, "skills": {"organisation": 12.0}, "verbe": "fait son planning"},
	"lire": {"anim": "sit_read", "label": "Lire un livre", "texts": ["livre", "un livre", "lire un livre"], "minutes": 45,
		"needs": {}, "skills": {"logique": 12.0}, "verbe": "lit un livre", "achat": "lecture"},
	"jeu": {"anim": "sit_play", "label": "Jouer à un jeu de société", "texts": ["jeu", "un jeu", "jouer à un jeu"], "minutes": 60,
		"needs": {"social": 50.0}, "skills": {"sociabilite": 10.0, "logique": 8.0, "humour": 8.0}, "verbe": "joue avec un ami", "achat": "jeux"},
	"musique": {"anim": "guitar", "label": "Jouer de la guitare", "texts": ["guitare", "la guitare", "jouer de la guitare"], "minutes": 45,
		"needs": {}, "skills": {"creativite": 10.0, "charisme": 8.0}, "verbe": "joue de la guitare", "achat": "guitare"},
	"jardiner": {"anim": "garden", "label": "Jardiner", "texts": ["potager", "le potager", "arroser le potager"], "minutes": 45,
		"needs": {"hygiene": -15.0}, "skills": {"patience": 12.0, "physique": 6.0}, "verbe": "jardine", "achat": "terrasse"},
	"animal": {"anim": "pet", "label": "S'occuper du chat", "texts": ["chat", "le chat", "caresser le chat"], "minutes": 30,
		"needs": {"social": 25.0}, "skills": {"douceur": 10.0, "responsabilite": 10.0, "patience": 6.0}, "verbe": "s'occupe du chat", "achat": "chat"},
}

const WORDS_PER_SERIES := 5

# --- Champs lexicaux ---------------------------------------------------------
# Pour chaque activité : 3 listes de mots, de plus en plus longs ou difficiles.
# (Pas de « œ » ni d'apostrophe : trop difficiles à trouver sur le clavier.)
const LEXIQUE := {
	"sport": [
		["saut", "course", "ballon", "vélo", "force", "jambe", "bras", "match", "but", "corde"],
		["muscle", "courir", "sauter", "baskets", "vitesse", "équipe", "énergie", "nager", "effort", "tapis"],
		["endurance", "étirement", "entraînement", "échauffement", "respiration", "champion", "gymnastique", "équilibre", "athlète"],
	],
	"peindre": [
		["bleu", "rouge", "vert", "jaune", "toile", "trait", "rose", "noir", "pot", "art"],
		["pinceau", "couleur", "dessin", "tableau", "peinture", "palette", "crayon", "tache", "modèle", "orange"],
		["aquarelle", "chevalet", "portrait", "paysage", "mélange", "artiste", "lumière", "imagination", "exposition"],
	],
	"miroir": [
		["voix", "mot", "regard", "salut", "joie", "oui", "merci", "geste", "calme", "idée"],
		["sourire", "parler", "bonjour", "discours", "écouter", "phrase", "courage", "public", "confiant", "humour"],
		["confiance", "présenter", "expliquer", "convaincre", "articuler", "politesse", "expression", "compliment", "applaudir"],
	],
	"bois": [
		["bois", "clou", "scie", "vis", "lime", "colle", "règle", "banc", "trou", "outil"],
		["marteau", "planche", "mesure", "poncer", "vernis", "atelier", "bûche", "étagère", "tabouret", "copeau"],
		["tournevis", "perceuse", "assembler", "menuisier", "établi", "découper", "fabriquer", "équerre", "construction"],
	],
	"planning": [
		["jour", "heure", "liste", "lundi", "mardi", "date", "soir", "matin", "midi", "note"],
		["agenda", "semaine", "horaire", "devoirs", "cartable", "montre", "minute", "prévoir", "ranger", "jeudi"],
		["calendrier", "organiser", "planifier", "priorité", "rendez-vous", "préparer", "mercredi", "vendredi", "anticiper"],
	],
	"cuisiner": [
		["sel", "lait", "riz", "pain", "plat", "bol", "four", "pâte", "miel", "soupe"],
		["farine", "beurre", "sucre", "recette", "couper", "mélanger", "légumes", "tomate", "carotte", "fromage"],
		["casserole", "ingrédient", "éplucher", "assiette", "fourchette", "délicieux", "saladier", "spatule", "cuisinier"],
	],
	"appeler": [
		["allô", "ami", "appel", "salut", "rire", "copain", "bisou", "bien", "voix", "merci"],
		["message", "bonjour", "raconter", "écouter", "nouvelle", "bavarder", "répondre", "sonnerie", "copine", "discuter"],
		["téléphone", "conversation", "au revoir", "à bientôt", "rappeler", "messagerie", "bonne journée", "décrocher", "numéro"],
	],
	"inviter": [
		["jeu", "fête", "ami", "rire", "jus", "carte", "dés", "bravo", "goûter", "joie"],
		["inviter", "partage", "gâteau", "musique", "accueil", "danser", "blague", "cadeau", "ensemble", "bienvenue"],
		["invitation", "anniversaire", "amusement", "discussion", "chaleureux", "convivial", "partager", "surprise", "jeu de société"],
	],
	"lire": [
		["page", "mot", "livre", "conte", "titre", "héros", "texte", "roman", "ligne", "fée"],
		["histoire", "chapitre", "lecture", "auteur", "dragon", "enquête", "poème", "phrase", "image", "album"],
		["bibliothèque", "aventure", "personnage", "imaginer", "comprendre", "détective", "dictionnaire", "bande dessinée", "magazine"],
	],
	"jeu": [
		["dé", "pion", "carte", "tour", "case", "règle", "jeu", "point", "duel", "gagné"],
		["plateau", "joueur", "partie", "équipe", "lancer", "piocher", "avancer", "énigme", "puzzle", "domino"],
		["stratégie", "réfléchir", "adversaire", "fair-play", "rigolade", "échiquier", "devinette", "partenaire", "à ton tour"],
	],
	"musique": [
		["note", "son", "air", "voix", "corde", "chant", "duo", "solo", "ton", "rock"],
		["guitare", "musique", "chanson", "rythme", "accord", "mélodie", "chanter", "concert", "refrain", "tempo"],
		["instrument", "musicien", "répétition", "partition", "guitariste", "spectacle", "harmonie", "composer", "applaudir"],
	],
	"jardiner": [
		["eau", "terre", "fleur", "pot", "herbe", "fruit", "trou", "rose", "tige", "seau"],
		["graine", "arroser", "plante", "tomate", "pousser", "feuille", "racine", "jardin", "salade", "râteau"],
		["arrosoir", "potager", "récolter", "légumes", "jardinier", "patience", "citrouille", "tournesol", "printemps"],
	],
	"animal": [
		["chat", "poil", "bol", "eau", "jeu", "doux", "câlin", "miaou", "lait", "nez"],
		["caresse", "gamelle", "brosser", "ronron", "panier", "coussin", "nourrir", "moustache", "pattes", "chaton"],
		["croquettes", "vétérinaire", "responsable", "ronronner", "tendresse", "compagnon", "attention", "délicatement", "confiance"],
	],
}


static func is_series(action_id: String) -> bool:
	return LEXIQUE.has(action_id)


## Mots à taper pour une série : `level` = niveau de texte de l'enfant (1 à 3).
## Niveau 1 : mots courts. Niveau 2 : surtout des mots moyens. Niveau 3 : moyens et longs.
static func series_words(action_id: String, level: int, count: int, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var lists: Array = LEXIQUE[action_id]
	var result := []
	var guard := 0
	while result.size() < count and guard < 200:
		guard += 1
		var tier := 0
		match clampi(level, 1, 3):
			2:
				tier = 1 if rng.randf() < 0.7 else 0
			3:
				tier = 2 if rng.randf() < 0.6 else 1
		var words: Array = lists[tier]
		var w: String = words[rng.randi() % words.size()]
		if not w in result:
			result.append(w)
	return result


## XP gagnée pour un mot réussi (les mots longs rapportent plus).
static func word_xp(word: String) -> float:
	return 4.0 + 0.5 * word.length()


## Part de chaque compétence pour une activité (la compétence principale vaut 1).
static func skill_weights(action_id: String) -> Dictionary:
	var skills: Dictionary = ACTIONS[action_id]["skills"]
	var best := 0.0
	for s in skills:
		best = maxf(best, skills[s])
	var result := {}
	for s in skills:
		result[s] = skills[s] / best
	return result


static func main_skill(action_id: String) -> String:
	var skills: Dictionary = ACTIONS[action_id]["skills"]
	var best := ""
	for s in skills:
		if best == "" or skills[s] > skills[best]:
			best = s
	return best


# --- Magasin : agrandir la maison ---------------------------------------------------
# Chaque achat (payé avec les pièces) ajoute un objet dans la maison et une
# nouvelle activité. « objet » = identifiant de l'objet construit par studio.gd.
const SHOP := {
	"lecture": {"label": "Coin lecture", "prix": 40, "action": "lire", "objet": "lecture", "icone": "logique",
		"description": "Un fauteuil et des livres sous la fenêtre, pour lire tranquillement."},
	"jeux": {"label": "Table de jeux", "prix": 60, "action": "jeu", "objet": "jeux", "icone": "sociabilite",
		"description": "Une table et un jeu de société. Un ami vient jouer avec toi."},
	"guitare": {"label": "Guitare", "prix": 80, "action": "musique", "objet": "guitare", "icone": "creativite",
		"description": "Une guitare pour jouer de la musique dans le salon."},
	"terrasse": {"label": "Terrasse et potager", "prix": 120, "action": "jardiner", "objet": "potager", "icone": "patience",
		"description": "La maison s'agrandit ! Une terrasse en bois mène au potager, pour jardiner."},
	"chat": {"label": "Un chat", "prix": 150, "action": "animal", "objet": "chat", "icone": "douceur",
		"description": "Un chat vient vivre avec toi. Il aime les caresses et compte sur toi."},
}
const SHOP_ORDER := ["lecture", "jeux", "guitare", "terrasse", "chat"]


## Achats du profil (liste d'identifiants de SHOP).
static func purchases(profile: Dictionary) -> Array:
	var list = profile.get("achats", [])
	return list if list is Array else []


## L'action est-elle possible pour ce profil ? (objet de base, ou objet acheté)
static func is_available(action_id: String, profile: Dictionary) -> bool:
	var item: String = ACTIONS[action_id].get("achat", "")
	return item == "" or item in purchases(profile)


## Compétences que l'enfant peut entraîner avec ce qu'il possède (dans l'ordre de SKILLS).
static func available_skills(profile: Dictionary) -> Array:
	var trained := {}
	for id in ACTIONS:
		if is_available(id, profile):
			for s in ACTIONS[id]["skills"]:
				trained[s] = true
	var result := []
	for s in SKILLS:
		if trained.has(s):
			result.append(s)
	return result


## Compétences à montrer à l'enfant : celles qu'il peut entraîner chez lui, celles
## de son travail et celles où il a déjà des points (dans l'ordre de SKILLS).
static func visible_skills(profile: Dictionary) -> Array:
	var shown := {}
	for s in available_skills(profile):
		shown[s] = true
	var career: String = profile.get("career", {}).get("current", "")
	if career != "":
		for s in CAREERS[career]["mission_skills"]:
			shown[s] = true
	var xp: Dictionary = profile.get("skills_xp", {})
	for s in xp:
		if float(xp[s]) > 0.0:
			shown[s] = true
	var result := []
	for s in SKILLS:
		if shown.has(s):
			result.append(s)
	return result


## Conseil pour progresser : les activités que l'enfant possède et qui entraînent la
## compétence, ses missions de travail, et sinon ce qu'il peut acheter au magasin.
static func skill_help(skill: String, profile: Dictionary) -> String:
	var names := []
	for id in ACTIONS:
		if ACTIONS[id]["skills"].has(skill) and is_available(id, profile):
			names.append(ACTIONS[id]["label"].to_lower())
	var career: String = profile.get("career", {}).get("current", "")
	var missions: bool = career != "" and CAREERS[career]["mission_skills"].has(skill)
	if names.is_empty():
		var to_buy := []
		for item in shop_items_for_skill(skill):
			to_buy.append(SHOP[item]["label"].to_lower())
		var text := "Pour progresser : tes missions de travail." if missions else "Pour progresser :"
		if not to_buy.is_empty():
			text += " Au magasin : %s." % ", ".join(to_buy)
		return text
	var help := "Pour progresser : %s." % ", ".join(names)
	if missions:
		help += " Tes missions de travail aident aussi."
	return help


## Achats du magasin qui entraînent cette compétence.
static func shop_items_for_skill(skill: String) -> Array:
	var result := []
	for id in SHOP_ORDER:
		if ACTIONS[SHOP[id]["action"]]["skills"].has(skill):
			result.append(id)
	return result


# --- Carrières -----------------------------------------------------------------
const CAREERS := {
	"organisateur": {
		"label": "Organisateur d'événements",
		"icone": "organisation",
		"description": "Prépare des fêtes et des réunions : anniversaires, baby showers, séminaires.",
		"mission_skills": {"organisation": 18.0, "charisme": 10.0, "creativite": 6.0},
		"tiers": [
			{"title": "Assistant d'organisation", "salary": 20, "req": {}},
			{"title": "Organisateur débutant", "salary": 35, "req": {"organisation": 2, "charisme": 1}},
			{"title": "Organisateur confirmé", "salary": 50, "req": {"organisation": 4, "charisme": 3, "creativite": 2}},
			{"title": "Chef de projet", "salary": 70, "req": {"organisation": 6, "charisme": 5, "creativite": 4}},
			{"title": "Grand organisateur", "salary": 100, "req": {"organisation": 8, "charisme": 7, "creativite": 6}},
		],
	},
	"artisan": {
		"label": "Artisan",
		"icone": "marteau",
		"description": "Récolte du bois, achète des outils, entraîne-toi et construis des objets.",
		"mission_skills": {"physique": 18.0, "creativite": 10.0, "organisation": 6.0},
		"tiers": [
			{"title": "Apprenti artisan", "salary": 20, "req": {}},
			{"title": "Artisan débutant", "salary": 35, "req": {"physique": 2, "creativite": 1}},
			{"title": "Artisan", "salary": 50, "req": {"physique": 4, "creativite": 3, "organisation": 2}},
			{"title": "Artisan confirmé", "salary": 70, "req": {"physique": 6, "creativite": 5, "organisation": 4}},
			{"title": "Maître artisan", "salary": 100, "req": {"physique": 8, "creativite": 7, "organisation": 6}},
		],
	},
	"sportif": {
		"label": "Sportif",
		"icone": "physique",
		"description": "Entraîne-toi, prépare tes matchs et deviens un champion.",
		"mission_skills": {"physique": 18.0, "organisation": 8.0, "patience": 8.0},
		"tiers": [
			{"title": "Sportif débutant", "salary": 20, "req": {}},
			{"title": "Sportif de club", "salary": 35, "req": {"physique": 3}},
			{"title": "Sportif régional", "salary": 50, "req": {"physique": 5, "organisation": 2}},
			{"title": "Sportif national", "salary": 70, "req": {"physique": 8, "organisation": 3, "patience": 2}},
			{"title": "Champion", "salary": 100, "req": {"physique": 10, "organisation": 5, "patience": 4}},
		],
	},
	"chanteur": {
		"label": "Chanteur",
		"icone": "charisme",
		"description": "Répète tes chansons, monte sur scène et fais chanter le public.",
		"mission_skills": {"charisme": 18.0, "creativite": 10.0, "humour": 6.0},
		"tiers": [
			{"title": "Chanteur débutant", "salary": 20, "req": {}},
			{"title": "Chanteur de quartier", "salary": 35, "req": {"charisme": 2, "creativite": 1}},
			{"title": "Chanteur de scène", "salary": 50, "req": {"charisme": 4, "creativite": 3, "humour": 2}},
			{"title": "Artiste reconnu", "salary": 70, "req": {"charisme": 6, "creativite": 5, "humour": 4}},
			{"title": "Star de la chanson", "salary": 100, "req": {"charisme": 8, "creativite": 7, "humour": 6}},
		],
	},
	"scientifique": {
		"label": "Scientifique",
		"icone": "fiole",
		"description": "Observe, mesure et fais des expériences pour comprendre le monde.",
		"mission_skills": {"logique": 18.0, "organisation": 10.0, "patience": 6.0},
		"tiers": [
			{"title": "Assistant de laboratoire", "salary": 20, "req": {}},
			{"title": "Jeune chercheur", "salary": 35, "req": {"logique": 2, "organisation": 1}},
			{"title": "Chercheur", "salary": 50, "req": {"logique": 4, "organisation": 3, "patience": 2}},
			{"title": "Chercheur confirmé", "salary": 70, "req": {"logique": 6, "organisation": 5, "patience": 4}},
			{"title": "Grand savant", "salary": 100, "req": {"logique": 8, "organisation": 7, "patience": 6}},
		],
	},
	"ingenieur": {
		"label": "Ingénieur",
		"icone": "reglages",
		"description": "Imagine des ponts, des robots et des machines, puis construis-les.",
		"mission_skills": {"logique": 18.0, "creativite": 10.0, "organisation": 6.0},
		"tiers": [
			{"title": "Apprenti ingénieur", "salary": 20, "req": {}},
			{"title": "Technicien", "salary": 35, "req": {"logique": 2, "creativite": 1}},
			{"title": "Ingénieur", "salary": 50, "req": {"logique": 4, "creativite": 3, "organisation": 2}},
			{"title": "Ingénieur en chef", "salary": 70, "req": {"logique": 6, "creativite": 5, "organisation": 4}},
			{"title": "Grand inventeur", "salary": 100, "req": {"logique": 8, "creativite": 7, "organisation": 6}},
		],
	},
	"nature": {
		"label": "Vie dans la nature",
		"icone": "feuille",
		"description": "Occupe-toi des plantes, des animaux et de la forêt.",
		"mission_skills": {"patience": 18.0, "physique": 8.0, "douceur": 8.0},
		"tiers": [
			{"title": "Promeneur curieux", "salary": 20, "req": {}},
			{"title": "Apprenti jardinier", "salary": 35, "req": {"physique": 2, "patience": 1}},
			{"title": "Soigneur d'animaux", "salary": 50, "req": {"patience": 3, "physique": 3, "douceur": 1}},
			{"title": "Garde forestier", "salary": 70, "req": {"patience": 5, "physique": 5, "douceur": 3}},
			{"title": "Gardien de la nature", "salary": 100, "req": {"patience": 8, "physique": 6, "douceur": 5}},
		],
	},
}
const CAREER_ORDER := ["organisateur", "artisan", "sportif", "chanteur", "scientifique", "ingenieur", "nature"]
const MISSIONS_PER_TIER := 3
const CAREER_CHANGE_MIN_TIER := 2 # palier à atteindre avant de pouvoir changer

# --- Objectif de vie (« Mon rêve ») ----------------------------------------------
# Choisi en début de partie, il donne un but à toute la partie. Un rêve de métier
# se réalise en atteignant le palier 5 de la carrière ; le rêve « maison » en
# achetant tout le magasin. Voir scripts/core/dreams.gd.
const DREAMS := {
	"organisateur": {"label": "Organiser de grandes fêtes", "description": "Devenir un grand organisateur d'événements.", "career": "organisateur"},
	"artisan": {"label": "Devenir maître artisan", "description": "Construire de beaux objets de tes mains.", "career": "artisan"},
	"sportif": {"label": "Devenir champion", "description": "T'entraîner et gagner le championnat.", "career": "sportif"},
	"chanteur": {"label": "Devenir une star de la chanson", "description": "Chanter sur scène devant un grand public.", "career": "chanteur"},
	"scientifique": {"label": "Devenir un grand savant", "description": "Faire des expériences et des découvertes.", "career": "scientifique"},
	"ingenieur": {"label": "Devenir un grand inventeur", "description": "Imaginer et construire des machines.", "career": "ingenieur"},
	"nature": {"label": "Vivre dans la nature", "description": "Prendre soin des plantes et des animaux.", "career": "nature"},
	"maison": {"label": "Avoir une belle maison", "description": "Acheter tout ce qu'il y a au magasin.", "career": ""},
}
const DREAM_ORDER := ["organisateur", "artisan", "sportif", "chanteur", "scientifique", "ingenieur", "nature", "maison"]
const DREAM_REWARD_PIECES := 100
const DREAM_REWARD_STARS := 3


static func dream_icon(dream: String) -> String:
	var career: String = DREAMS[dream]["career"]
	return CAREERS[career]["icone"] if career != "" else "maison"


# --- Missions -----------------------------------------------------------------
# min_tier : palier (1 à 5) à partir duquel la mission peut apparaître.
# questions : choix à faire après avoir lu la consigne (un seul bon choix).
# items : liste à taper, chaque élément a 3 niveaux de texte.
const MISSIONS := [
	{
		"id": "anniversaire", "career": "organisateur", "min_tier": 1,
		"title": "L'anniversaire de Léa",
		"consigne": "Léa fête ses 9 ans. Elle adore les dinosaures. Elle n'aime pas le chocolat.",
		"questions": [
			{"q": "Quel gâteau choisis-tu ?", "choices": ["Un gâteau au chocolat", "Un gâteau à la fraise", "Pas de gâteau"], "good": 1,
				"aide": "Relis la consigne : Léa n'aime pas le chocolat."},
			{"q": "Quelle décoration choisis-tu ?", "choices": ["Des princesses", "Des voitures", "Des dinosaures"], "good": 2,
				"aide": "Relis la consigne : Léa adore les dinosaures."},
		],
		"items": [["ballons", "des ballons", "gonfler des ballons"], ["bougies", "neuf bougies", "poser neuf bougies"], ["gâteau", "le gâteau", "acheter le gâteau"]],
	},
	{
		"id": "baby_shower", "career": "organisateur", "min_tier": 1,
		"title": "La baby shower de Sarah",
		"consigne": "Sarah attend un bébé. La fête a lieu dimanche à 15 h, dans le jardin. Il y aura 12 invités.",
		"questions": [
			{"q": "Quand a lieu la fête ?", "choices": ["Samedi à 15 h", "Dimanche à 15 h", "Dimanche à 10 h"], "good": 1,
				"aide": "Relis la consigne : c'est dimanche à 15 h."},
			{"q": "Combien de chaises faut-il ?", "choices": ["6 chaises", "20 chaises", "12 chaises"], "good": 2,
				"aide": "Relis la consigne : il y a 12 invités."},
		],
		"items": [["chaises", "des chaises", "installer des chaises"], ["jus", "du jus", "servir du jus"], ["cadeau", "un cadeau", "emballer un cadeau"]],
	},
	{
		"id": "seminaire", "career": "organisateur", "min_tier": 1,
		"title": "Le séminaire d'entreprise",
		"consigne": "Une entreprise fait une réunion de 30 personnes. Il faut un micro et un écran. Le repas doit être sans viande.",
		"questions": [
			{"q": "Quel matériel prépares-tu ?", "choices": ["Un micro et un écran", "Une guitare et un tambour", "Des ballons"], "good": 0,
				"aide": "Relis la consigne : il faut un micro et un écran."},
			{"q": "Quel repas commandes-tu ?", "choices": ["Du poulet frites", "Des pâtes aux légumes", "Un burger au bœuf"], "good": 1,
				"aide": "Relis la consigne : le repas doit être sans viande."},
		],
		"items": [["micro", "un micro", "brancher le micro"], ["écran", "un écran", "allumer l'écran"], ["badges", "des badges", "imprimer des badges"]],
	},
	{
		"id": "fete_ecole", "career": "organisateur", "min_tier": 2,
		"title": "La fête de l'école",
		"consigne": "La fête commence à 14 h. Il faut 1 heure pour installer les stands.",
		"questions": [
			{"q": "À quelle heure commences-tu l'installation ?", "choices": ["À 13 h", "À 14 h", "À 15 h"], "good": 0,
				"aide": "Il faut 1 heure avant 14 h : donc 13 h."},
			{"q": "Que fais-tu en premier ?", "choices": ["Ranger les tables", "Installer les tables", "Rentrer chez moi"], "good": 1,
				"aide": "Avant la fête, on installe."},
		],
		"items": [["tables", "les tables", "installer les tables"], ["stands", "les stands", "monter les stands"], ["affiches", "des affiches", "coller des affiches"]],
	},
	{
		"id": "mariage", "career": "organisateur", "min_tier": 3,
		"title": "Un mariage au jardin",
		"consigne": "Les mariés veulent des fleurs blanches et une musique douce. Le budget pour les fleurs est de 50 pièces.",
		"questions": [
			{"q": "Quelles fleurs choisis-tu ?", "choices": ["Roses rouges : 40 pièces", "Lys blancs : 70 pièces", "Roses blanches : 45 pièces"], "good": 2,
				"aide": "Il faut des fleurs blanches qui coûtent moins de 50 pièces."},
			{"q": "Quelle musique choisis-tu ?", "choices": ["Du piano", "De la batterie", "Une sirène"], "good": 0,
				"aide": "Relis la consigne : une musique douce."},
		],
		"items": [["fleurs", "les fleurs", "livrer les fleurs"], ["musique", "la musique", "choisir la musique"], ["invitations", "les invitations", "envoyer les invitations"]],
	},
	{
		"id": "bois", "career": "artisan", "min_tier": 1,
		"title": "Récolter du bois",
		"consigne": "Pour fabriquer un tabouret, il faut 4 planches. Une bûche donne 2 planches.",
		"questions": [
			{"q": "Combien de bûches dois-tu couper ?", "choices": ["2 bûches", "4 bûches", "8 bûches"], "good": 0,
				"aide": "2 bûches donnent 2 + 2 = 4 planches."},
			{"q": "Quel outil prends-tu pour couper ?", "choices": ["Un pinceau", "Une hache", "Une cuillère"], "good": 1,
				"aide": "Pour couper du bois, on utilise une hache."},
		],
		"items": [["bois", "du bois", "couper du bois"], ["bûches", "deux bûches", "porter deux bûches"], ["planches", "des planches", "scier des planches"]],
	},
	{
		"id": "outils", "career": "artisan", "min_tier": 1,
		"title": "Acheter des outils",
		"consigne": "Tu as 30 pièces. Il te faut un marteau et des clous. Le marteau coûte 12 pièces, les clous 5 pièces, une perceuse 40 pièces.",
		"questions": [
			{"q": "Que peux-tu acheter ?", "choices": ["Le marteau et les clous", "La perceuse", "Le marteau et la perceuse"], "good": 0,
				"aide": "Il te faut un marteau et des clous, et la perceuse coûte trop cher."},
			{"q": "Combien de pièces te reste-t-il ?", "choices": ["17 pièces", "13 pièces", "7 pièces"], "good": 1,
				"aide": "30 - 12 - 5 = 13."},
		],
		"items": [["marteau", "un marteau", "acheter un marteau"], ["clous", "des clous", "compter des clous"]],
	},
	{
		"id": "poncer", "career": "artisan", "min_tier": 1,
		"title": "S'entraîner à poncer",
		"consigne": "Le maître artisan explique : d'abord on ponce avec le papier à gros grain, ensuite avec le papier fin. On met le vernis à la fin.",
		"questions": [
			{"q": "Quel papier utilises-tu en premier ?", "choices": ["Le papier fin", "Le papier à gros grain", "Aucun papier"], "good": 1,
				"aide": "Relis la consigne : d'abord le gros grain."},
			{"q": "Quand mets-tu le vernis ?", "choices": ["Au début", "Au milieu", "À la fin"], "good": 2,
				"aide": "Relis la consigne : le vernis, c'est à la fin."},
		],
		"items": [["ponçage", "le ponçage", "poncer la planche"], ["vernis", "le vernis", "passer le vernis"]],
	},
	{
		"id": "cabane", "career": "artisan", "min_tier": 2,
		"title": "Une cabane à oiseaux",
		"consigne": "La cabane doit avoir un trou rond pour entrer et un toit penché pour que la pluie coule.",
		"questions": [
			{"q": "Quel toit construis-tu ?", "choices": ["Un toit plat", "Un toit penché", "Pas de toit"], "good": 1,
				"aide": "Relis la consigne : un toit penché pour la pluie."},
			{"q": "Quelle forme a le trou ?", "choices": ["Rond", "Carré", "Triangle"], "good": 0,
				"aide": "Relis la consigne : un trou rond."},
		],
		"items": [["toit", "le toit", "clouer le toit"], ["trou", "un trou", "percer un trou"], ["perchoir", "un perchoir", "coller un perchoir"]],
	},
	{
		"id": "table", "career": "artisan", "min_tier": 3,
		"title": "Une table pour un client",
		"consigne": "Le client veut une table pour 6 personnes, en bois de chêne. Il faut la livrer vendredi.",
		"questions": [
			{"q": "Quel bois choisis-tu ?", "choices": ["Du sapin", "Du carton", "Du chêne"], "good": 2,
				"aide": "Relis la consigne : en bois de chêne."},
			{"q": "Quel jour livres-tu la table ?", "choices": ["Lundi", "Vendredi", "Jeudi"], "good": 1,
				"aide": "Relis la consigne : il faut la livrer vendredi."},
		],
		"items": [["pieds", "quatre pieds", "visser quatre pieds"], ["plateau", "le plateau", "poser le plateau"], ["livraison", "la livraison", "préparer la livraison"]],
	},
	{
		"id": "echauffement", "career": "sportif", "min_tier": 1,
		"title": "L'échauffement",
		"consigne": "Avant de courir, le coach demande 10 minutes d'échauffement. On commence par les chevilles, puis les genoux, puis les épaules.",
		"questions": [
			{"q": "Combien de temps dure l'échauffement ?", "choices": ["5 minutes", "10 minutes", "20 minutes"], "good": 1,
				"aide": "Relis la consigne : 10 minutes d'échauffement."},
			{"q": "Par quoi commences-tu ?", "choices": ["Les épaules", "Les genoux", "Les chevilles"], "good": 2,
				"aide": "Relis la consigne : on commence par les chevilles."},
		],
		"items": [["chevilles", "les chevilles", "tourner les chevilles"], ["genoux", "les genoux", "plier les genoux"], ["épaules", "les épaules", "rouler les épaules"]],
	},
	{
		"id": "sac_sport", "career": "sportif", "min_tier": 1,
		"title": "Préparer son sac",
		"consigne": "Demain, tu as un match de foot à 10 h. Il fera chaud. Il te faut tes crampons, ton maillot bleu et une gourde.",
		"questions": [
			{"q": "Que mets-tu dans ton sac ?", "choices": ["Des crampons, un maillot bleu et une gourde", "Des skis et des gants", "Un maillot rouge et une raquette"], "good": 0,
				"aide": "Relis la consigne : crampons, maillot bleu et gourde."},
			{"q": "Pourquoi prends-tu une gourde ?", "choices": ["Parce qu'il va neiger", "Parce qu'il fera chaud", "Pour faire joli"], "good": 1,
				"aide": "Relis la consigne : il fera chaud, il faudra boire."},
		],
		"items": [["crampons", "les crampons", "ranger les crampons"], ["maillot", "le maillot", "plier le maillot"], ["gourde", "la gourde", "remplir la gourde"]],
	},
	{
		"id": "programme", "career": "sportif", "min_tier": 1,
		"title": "Le programme de la semaine",
		"consigne": "Le coach dit : entraînement lundi, mercredi et vendredi. Samedi, repos. Le match est dimanche.",
		"questions": [
			{"q": "Quel jour te reposes-tu ?", "choices": ["Samedi", "Mercredi", "Dimanche"], "good": 0,
				"aide": "Relis la consigne : samedi, repos."},
			{"q": "Combien d'entraînements as-tu cette semaine ?", "choices": ["2 entraînements", "3 entraînements", "5 entraînements"], "good": 1,
				"aide": "Lundi, mercredi et vendredi : cela fait 3."},
		],
		"items": [["lundi", "le lundi", "courir le lundi"], ["repos", "le repos", "prendre du repos"], ["match", "le match", "jouer le match"]],
	},
	{
		"id": "relais", "career": "sportif", "min_tier": 2,
		"title": "La course de relais",
		"consigne": "Vous êtes 4 coureurs. Chacun court 100 mètres. Tu es le dernier : tu reçois le bâton et tu le gardes jusqu'à la ligne.",
		"questions": [
			{"q": "Quelle distance court l'équipe en tout ?", "choices": ["100 mètres", "400 mètres", "1 000 mètres"], "good": 1,
				"aide": "4 coureurs qui courent 100 mètres : 400 mètres."},
			{"q": "Que fais-tu du bâton ?", "choices": ["Je le donne à un autre coureur", "Je le pose par terre", "Je le garde jusqu'à la ligne"], "good": 2,
				"aide": "Tu es le dernier coureur : tu gardes le bâton jusqu'à la ligne."},
		],
		"items": [["relais", "le relais", "courir le relais"], ["bâton", "le bâton", "tenir le bâton"], ["ligne", "la ligne", "passer la ligne"]],
	},
	{
		"id": "championnat", "career": "sportif", "min_tier": 3,
		"title": "Le championnat",
		"consigne": "Le championnat est dans 3 semaines. Le coach veut 4 entraînements par semaine. La veille du match, il faut se coucher avant 22 h.",
		"questions": [
			{"q": "Combien d'entraînements feras-tu avant le championnat ?", "choices": ["7 entraînements", "12 entraînements", "3 entraînements"], "good": 1,
				"aide": "3 semaines avec 4 entraînements chacune : 12."},
			{"q": "La veille du match, à quelle heure te couches-tu ?", "choices": ["À 23 h 30", "À minuit", "À 21 h 30"], "good": 2,
				"aide": "Il faut se coucher avant 22 h."},
		],
		"items": [["médaille", "la médaille", "gagner la médaille"], ["podium", "le podium", "monter sur le podium"], ["équipe", "mon équipe", "féliciter mon équipe"]],
	},
	{
		"id": "repetition", "career": "chanteur", "min_tier": 1,
		"title": "La répétition",
		"consigne": "La répétition a lieu mardi à 17 h, dans la salle de musique. Il faut apporter les paroles de la chanson et une bouteille d'eau.",
		"questions": [
			{"q": "Quand a lieu la répétition ?", "choices": ["Mardi à 17 h", "Jeudi à 17 h", "Mardi à 7 h"], "good": 0,
				"aide": "Relis la consigne : mardi à 17 h."},
			{"q": "Qu'apportes-tu ?", "choices": ["Un ballon et des baskets", "Les paroles et de l'eau", "Un pinceau et de la peinture"], "good": 1,
				"aide": "Relis la consigne : les paroles et une bouteille d'eau."},
		],
		"items": [["paroles", "les paroles", "lire les paroles"], ["micro", "le micro", "régler le micro"], ["chanson", "la chanson", "répéter la chanson"]],
	},
	{
		"id": "voix", "career": "chanteur", "min_tier": 1,
		"title": "Chauffer sa voix",
		"consigne": "La professeure explique : d'abord on respire lentement, ensuite on fait des sons graves, et à la fin des sons aigus.",
		"questions": [
			{"q": "Que fais-tu en premier ?", "choices": ["Des sons aigus", "Je respire lentement", "Je crie très fort"], "good": 1,
				"aide": "Relis la consigne : d'abord on respire lentement."},
			{"q": "Que fais-tu à la fin ?", "choices": ["Des sons aigus", "Des sons graves", "Je respire lentement"], "good": 0,
				"aide": "Relis la consigne : à la fin, des sons aigus."},
		],
		"items": [["souffle", "le souffle", "garder son souffle"], ["voix", "la voix", "chauffer la voix"], ["notes", "les notes", "chanter les notes"]],
	},
	{
		"id": "mamie", "career": "chanteur", "min_tier": 1,
		"title": "Chanter pour un anniversaire",
		"consigne": "Mamie Rose fête ses 70 ans. Elle aime les chansons douces. Elle n'aime pas le bruit fort.",
		"questions": [
			{"q": "Quelle chanson choisis-tu ?", "choices": ["Une chanson douce", "Du rock très fort", "Une chanson avec des tambours"], "good": 0,
				"aide": "Relis la consigne : elle aime les chansons douces."},
			{"q": "Comment chantes-tu ?", "choices": ["En criant", "Avec une voix calme", "Dans un mégaphone"], "good": 1,
				"aide": "Relis la consigne : elle n'aime pas le bruit fort."},
		],
		"items": [["refrain", "le refrain", "chanter le refrain"], ["sourire", "un sourire", "offrir un sourire"], ["bravo", "un bravo", "recevoir un bravo"]],
	},
	{
		"id": "concert", "career": "chanteur", "min_tier": 2,
		"title": "Le concert de l'école",
		"consigne": "Le concert commence à 18 h. Tu chantes 3 chansons de 4 minutes. Tu dois arriver 30 minutes avant pour te préparer.",
		"questions": [
			{"q": "À quelle heure arrives-tu ?", "choices": ["À 18 h", "À 17 h 30", "À 18 h 30"], "good": 1,
				"aide": "30 minutes avant 18 h : c'est 17 h 30."},
			{"q": "Combien de temps chantes-tu en tout ?", "choices": ["4 minutes", "7 minutes", "12 minutes"], "good": 2,
				"aide": "3 chansons de 4 minutes : 12 minutes."},
		],
		"items": [["scène", "la scène", "monter sur scène"], ["public", "le public", "saluer le public"], ["lumières", "les lumières", "allumer les lumières"]],
	},
	{
		"id": "disque", "career": "chanteur", "min_tier": 3,
		"title": "Enregistrer un disque",
		"consigne": "Le studio est réservé jeudi de 14 h à 16 h. Le disque doit avoir 5 chansons : 3 joyeuses et 2 calmes.",
		"questions": [
			{"q": "Combien de temps as-tu au studio ?", "choices": ["1 heure", "2 heures", "4 heures"], "good": 1,
				"aide": "De 14 h à 16 h : cela fait 2 heures."},
			{"q": "Quelles chansons choisis-tu ?", "choices": ["5 chansons joyeuses", "2 joyeuses et 3 calmes", "3 joyeuses et 2 calmes"], "good": 2,
				"aide": "Relis la consigne : 3 joyeuses et 2 calmes."},
		],
		"items": [["studio", "le studio", "réserver le studio"], ["casque", "le casque", "mettre le casque"], ["disque", "le disque", "enregistrer le disque"]],
	},
	{
		"id": "plantes", "career": "scientifique", "min_tier": 1,
		"title": "L'expérience des plantes",
		"consigne": "Tu as deux plantes. La plante A reçoit de l'eau chaque jour. La plante B ne reçoit pas d'eau. Après une semaine, tu compares.",
		"questions": [
			{"q": "Quelle plante reçoit de l'eau ?", "choices": ["La plante A", "La plante B", "Aucune des deux"], "good": 0,
				"aide": "Relis la consigne : la plante A reçoit de l'eau."},
			{"q": "Quand compares-tu les plantes ?", "choices": ["Après un jour", "Après une semaine", "Après un an"], "good": 1,
				"aide": "Relis la consigne : après une semaine."},
		],
		"items": [["arrosoir", "un arrosoir", "remplir un arrosoir"], ["plante", "la plante", "mesurer la plante"], ["cahier", "le cahier", "noter dans le cahier"]],
	},
	{
		"id": "laboratoire", "career": "scientifique", "min_tier": 1,
		"title": "Les règles du laboratoire",
		"consigne": "Au laboratoire, on met toujours des lunettes de protection et une blouse. On ne goûte jamais les produits.",
		"questions": [
			{"q": "Que mets-tu avant de commencer ?", "choices": ["Un bonnet et des gants de ski", "Des lunettes et une blouse", "Rien du tout"], "good": 1,
				"aide": "Relis la consigne : des lunettes de protection et une blouse."},
			{"q": "Un produit sent bon. Que fais-tu ?", "choices": ["Je le goûte", "Je le bois", "Je ne le goûte pas"], "good": 2,
				"aide": "Relis la consigne : on ne goûte jamais les produits."},
		],
		"items": [["blouse", "la blouse", "mettre la blouse"], ["lunettes", "les lunettes", "porter les lunettes"], ["flacon", "le flacon", "fermer le flacon"]],
	},
	{
		"id": "temperature", "career": "scientifique", "min_tier": 1,
		"title": "Mesurer la température",
		"consigne": "Tu notes la température chaque matin. Lundi : 12 degrés. Mardi : 15 degrés. Mercredi : 9 degrés.",
		"questions": [
			{"q": "Quel jour a-t-il fait le plus chaud ?", "choices": ["Lundi", "Mardi", "Mercredi"], "good": 1,
				"aide": "15 degrés, c'est le plus chaud : mardi."},
			{"q": "Quel jour a-t-il fait le plus froid ?", "choices": ["Lundi", "Mardi", "Mercredi"], "good": 2,
				"aide": "9 degrés, c'est le plus froid : mercredi."},
		],
		"items": [["thermomètre", "le thermomètre", "lire le thermomètre"], ["degrés", "les degrés", "noter les degrés"], ["tableau", "un tableau", "remplir un tableau"]],
	},
	{
		"id": "microscope", "career": "scientifique", "min_tier": 2,
		"title": "Observer au microscope",
		"consigne": "Pour observer une feuille : d'abord on pose la feuille sur la lame, ensuite on règle la lumière, enfin on tourne la molette pour voir net.",
		"questions": [
			{"q": "Que fais-tu en premier ?", "choices": ["Je règle la lumière", "Je pose la feuille sur la lame", "Je tourne la molette"], "good": 1,
				"aide": "Relis la consigne : d'abord on pose la feuille sur la lame."},
			{"q": "L'image est floue. Que fais-tu ?", "choices": ["Je tourne la molette", "J'éteins la lumière", "Je range le microscope"], "good": 0,
				"aide": "On tourne la molette pour voir net."},
		],
		"items": [["feuille", "la feuille", "poser la feuille"], ["lumière", "la lumière", "régler la lumière"], ["microscope", "le microscope", "regarder au microscope"]],
	},
	{
		"id": "expose", "career": "scientifique", "min_tier": 3,
		"title": "Présenter une découverte",
		"consigne": "Tu présentes ton exposé sur les volcans vendredi à 10 h. Tu as 15 minutes pour 3 parties : la question, l'expérience et le résultat.",
		"questions": [
			{"q": "Dans quel ordre présentes-tu ?", "choices": ["Le résultat, la question, l'expérience", "La question, l'expérience, le résultat", "L'expérience, le résultat, la question"], "good": 1,
				"aide": "Relis la consigne : la question, l'expérience et le résultat."},
			{"q": "Chaque partie dure le même temps. Combien de minutes par partie ?", "choices": ["3 minutes", "5 minutes", "15 minutes"], "good": 1,
				"aide": "15 minutes pour 3 parties : 5 minutes chacune."},
		],
		"items": [["question", "la question", "poser la question"], ["expérience", "mon expérience", "montrer mon expérience"], ["résultat", "le résultat", "expliquer le résultat"]],
	},
	{
		"id": "pont", "career": "ingenieur", "min_tier": 1,
		"title": "Un pont en bois",
		"consigne": "La rivière mesure 6 mètres de large. Le pont doit être plus long que la rivière. Il doit porter 2 personnes en même temps.",
		"questions": [
			{"q": "Quelle longueur de pont choisis-tu ?", "choices": ["4 mètres", "5 mètres", "8 mètres"], "good": 2,
				"aide": "Le pont doit être plus long que 6 mètres."},
			{"q": "Combien de personnes le pont doit-il porter ?", "choices": ["1 personne", "2 personnes", "10 personnes"], "good": 1,
				"aide": "Relis la consigne : 2 personnes en même temps."},
		],
		"items": [["plan", "le plan", "dessiner le plan"], ["pont", "le pont", "mesurer le pont"], ["planches", "des planches", "fixer des planches"]],
	},
	{
		"id": "robot", "career": "ingenieur", "min_tier": 1,
		"title": "Programmer un robot",
		"consigne": "Le robot doit aller jusqu'à la porte. Il avance de 3 cases, il tourne à droite, puis il avance de 2 cases.",
		"questions": [
			{"q": "Que fait le robot en premier ?", "choices": ["Il tourne à droite", "Il avance de 3 cases", "Il recule"], "good": 1,
				"aide": "Relis la consigne : il avance d'abord de 3 cases."},
			{"q": "De combien de cases avance-t-il en tout ?", "choices": ["3 cases", "5 cases", "6 cases"], "good": 1,
				"aide": "3 cases + 2 cases = 5 cases."},
		],
		"items": [["robot", "le robot", "allumer le robot"], ["bouton", "le bouton", "appuyer sur le bouton"], ["programme", "le programme", "lancer le programme"]],
	},
	{
		"id": "maquette", "career": "ingenieur", "min_tier": 1,
		"title": "La maquette de maison",
		"consigne": "Le client veut la maquette d'une maison avec 2 étages, un toit rouge et 4 fenêtres.",
		"questions": [
			{"q": "Quel toit dessines-tu ?", "choices": ["Un toit bleu", "Un toit rouge", "Un toit vert"], "good": 1,
				"aide": "Relis la consigne : un toit rouge."},
			{"q": "Combien de fenêtres dessines-tu ?", "choices": ["2 fenêtres", "4 fenêtres", "6 fenêtres"], "good": 1,
				"aide": "Relis la consigne : 4 fenêtres."},
		],
		"items": [["règle", "la règle", "prendre la règle"], ["maquette", "la maquette", "coller la maquette"], ["fenêtres", "les fenêtres", "tracer les fenêtres"]],
	},
	{
		"id": "eoliennes", "career": "ingenieur", "min_tier": 2,
		"title": "Des éoliennes pour le village",
		"consigne": "Une éolienne donne du courant à 50 maisons. Le village compte 150 maisons. On installe les éoliennes sur la colline, là où il y a du vent.",
		"questions": [
			{"q": "Combien d'éoliennes faut-il ?", "choices": ["2 éoliennes", "3 éoliennes", "5 éoliennes"], "good": 1,
				"aide": "50 + 50 + 50 = 150 : il en faut 3."},
			{"q": "Où installes-tu les éoliennes ?", "choices": ["Dans la vallée, à l'abri", "Dans un garage", "Sur la colline"], "good": 2,
				"aide": "Relis la consigne : sur la colline, là où il y a du vent."},
		],
		"items": [["vent", "le vent", "mesurer le vent"], ["hélice", "une hélice", "monter une hélice"], ["courant", "le courant", "brancher le courant"]],
	},
	{
		"id": "fusee", "career": "ingenieur", "min_tier": 3,
		"title": "La fusée à eau",
		"consigne": "La fusée doit peser moins de 500 grammes. La bouteille pèse 100 grammes et les ailerons 50 grammes. Avant le lancement, on vérifie que personne n'est devant.",
		"questions": [
			{"q": "Combien d'eau peux-tu ajouter ?", "choices": ["Moins de 350 grammes", "600 grammes", "1 kilo"], "good": 0,
				"aide": "500 - 100 - 50 = 350 grammes."},
			{"q": "Que fais-tu juste avant le lancement ?", "choices": ["Je vérifie que personne n'est devant", "Je ferme les yeux", "Je lance tout de suite"], "good": 0,
				"aide": "Relis la consigne : on vérifie que personne n'est devant."},
		],
		"items": [["fusée", "la fusée", "construire la fusée"], ["ailerons", "les ailerons", "coller les ailerons"], ["décollage", "le décollage", "préparer le décollage"]],
	},
	{
		"id": "oiseaux", "career": "nature", "min_tier": 1,
		"title": "Nourrir les oiseaux",
		"consigne": "En hiver, les oiseaux ont faim. Ils mangent des graines. Il ne faut pas leur donner de pain. La mangeoire se place en hauteur, loin des chats.",
		"questions": [
			{"q": "Que donnes-tu aux oiseaux ?", "choices": ["Du pain", "Des graines", "Des bonbons"], "good": 1,
				"aide": "Relis la consigne : des graines, pas de pain."},
			{"q": "Où places-tu la mangeoire ?", "choices": ["Par terre", "En hauteur", "Dans la maison"], "good": 1,
				"aide": "Relis la consigne : en hauteur, loin des chats."},
		],
		"items": [["graines", "des graines", "verser des graines"], ["mangeoire", "la mangeoire", "remplir la mangeoire"], ["oiseaux", "les oiseaux", "observer les oiseaux"]],
	},
	{
		"id": "tomates", "career": "nature", "min_tier": 1,
		"title": "Planter des tomates",
		"consigne": "On plante les tomates au printemps, au soleil. On les arrose le soir, 2 fois par semaine.",
		"questions": [
			{"q": "Quand plantes-tu les tomates ?", "choices": ["En hiver", "Au printemps", "La nuit"], "good": 1,
				"aide": "Relis la consigne : au printemps."},
			{"q": "Quand arroses-tu les tomates ?", "choices": ["Le soir", "À midi", "Jamais"], "good": 0,
				"aide": "Relis la consigne : on les arrose le soir."},
		],
		"items": [["graine", "une graine", "semer une graine"], ["terre", "la terre", "creuser la terre"], ["tomates", "les tomates", "arroser les tomates"]],
	},
	{
		"id": "foret", "career": "nature", "min_tier": 1,
		"title": "La promenade en forêt",
		"consigne": "En forêt, on reste sur le chemin. On ne cueille pas les champignons inconnus. On rapporte ses déchets.",
		"questions": [
			{"q": "Tu vois un champignon inconnu. Que fais-tu ?", "choices": ["Je le mange", "Je le laisse", "Je le cueille"], "good": 1,
				"aide": "Relis la consigne : on ne cueille pas les champignons inconnus."},
			{"q": "Que fais-tu de tes déchets ?", "choices": ["Je les rapporte", "Je les cache sous les feuilles", "Je les jette dans la rivière"], "good": 0,
				"aide": "Relis la consigne : on rapporte ses déchets."},
		],
		"items": [["chemin", "le chemin", "suivre le chemin"], ["arbres", "les arbres", "regarder les arbres"], ["déchets", "mes déchets", "rapporter mes déchets"]],
	},
	{
		"id": "poules", "career": "nature", "min_tier": 2,
		"title": "S'occuper des poules",
		"consigne": "Il y a 6 poules. Chaque poule mange 2 poignées de grain le matin. Le soir, on ferme le poulailler pour les protéger du renard.",
		"questions": [
			{"q": "Combien de poignées de grain faut-il le matin ?", "choices": ["6 poignées", "8 poignées", "12 poignées"], "good": 2,
				"aide": "6 poules qui mangent 2 poignées : 12 poignées."},
			{"q": "Que fais-tu le soir ?", "choices": ["J'ouvre le poulailler", "Je ferme le poulailler", "Je fais du bruit"], "good": 1,
				"aide": "Relis la consigne : le soir, on ferme le poulailler."},
		],
		"items": [["poules", "les poules", "nourrir les poules"], ["grain", "le grain", "donner le grain"], ["poulailler", "le poulailler", "fermer le poulailler"]],
	},
	{
		"id": "abri", "career": "nature", "min_tier": 3,
		"title": "Un abri pour la nuit",
		"consigne": "Tu dors en forêt. Le soleil se couche à 20 h. Il faut 2 heures pour construire l'abri, et il doit être fini avant la nuit. On le construit loin de la rivière.",
		"questions": [
			{"q": "À quelle heure commences-tu au plus tard ?", "choices": ["À 18 h", "À 19 h", "À 20 h"], "good": 0,
				"aide": "2 heures avant 20 h : c'est 18 h."},
			{"q": "Où construis-tu l'abri ?", "choices": ["Au bord de la rivière", "Loin de la rivière", "Dans la rivière"], "good": 1,
				"aide": "Relis la consigne : loin de la rivière."},
		],
		"items": [["branches", "des branches", "ramasser des branches"], ["abri", "un abri", "construire un abri"], ["feu", "le feu", "surveiller le feu"]],
	},
]


static func missions_for(career: String, tier: int) -> Array:
	var result := []
	for m in MISSIONS:
		if m["career"] == career and m["min_tier"] <= tier:
			result.append(m)
	return result


# --- Apparence ---------------------------------------------------------------
# Les 4 premières couleurs de peau, les 5 premières de cheveux et de tenue et les
# 3 premières coiffures gardent leur numéro de la version 1 (anciennes sauvegardes).
const SKIN_COLORS := [Color(1.0, 0.86, 0.74), Color(0.93, 0.74, 0.58), Color(0.76, 0.55, 0.38), Color(0.5, 0.34, 0.24),
	Color(0.98, 0.8, 0.66), Color(0.36, 0.24, 0.18)]
const HAIR_COLORS := [Color(0.15, 0.1, 0.08), Color(0.45, 0.28, 0.15), Color(0.9, 0.75, 0.4), Color(0.75, 0.3, 0.15), Color(0.35, 0.45, 0.85),
	Color(0.62, 0.42, 0.24), Color(0.8, 0.8, 0.82), Color(0.9, 0.5, 0.65)]
const OUTFIT_COLORS := [Color(0.35, 0.55, 0.9), Color(0.95, 0.5, 0.45), Color(0.45, 0.75, 0.5), Color(0.95, 0.75, 0.3), Color(0.65, 0.5, 0.85),
	Color(0.96, 0.96, 0.94), Color(0.25, 0.3, 0.42), Color(0.3, 0.7, 0.72)]
const BOTTOM_COLORS := [Color(0.27, 0.36, 0.58), Color(0.2, 0.22, 0.28), Color(0.72, 0.62, 0.48), Color(0.5, 0.33, 0.25), Color(0.4, 0.6, 0.45), Color(0.85, 0.45, 0.5)]
const SHOE_COLORS := [Color(0.95, 0.95, 0.93), Color(0.22, 0.23, 0.28), Color(0.9, 0.4, 0.36), Color(0.38, 0.55, 0.85), Color(0.55, 0.38, 0.26)]
const EYE_COLORS := [Color(0.36, 0.22, 0.12), Color(0.58, 0.4, 0.2), Color(0.3, 0.58, 0.38), Color(0.28, 0.52, 0.85), Color(0.5, 0.56, 0.62), Color(0.1, 0.09, 0.09)]
const HAIR_STYLES := ["Courts", "Longs", "Chignon", "Carré", "Queue de cheval", "Couettes", "Bouclés", "Très courts", "Mèche"]
const BODIES := ["Femme", "Homme"]
const HEIGHTS := ["Très petite", "Petite", "Moyenne", "Grande", "Très grande"]
const HEIGHT_SCALES := [0.88, 0.94, 1.0, 1.06, 1.12]
const BUILDS := ["Très fine", "Fine", "Moyenne", "Ronde", "Très ronde"]
const BUILD_FACTORS := [0.86, 0.93, 1.0, 1.1, 1.22]
const FACES := ["Rond", "Ovale", "Carré"]
const CHEEKS := ["Fines", "Normales", "Rondes"]
const BLUSHES := ["Sans", "Un peu roses", "Très roses"]
const EYE_SHAPES := ["Ronds", "En amande", "Grands", "Petits"]
const BROWS := ["Fins", "Épais", "Arqués"]
const NOSES := ["Petit", "Moyen", "Grand"]
const MOUTHS := ["Sourire", "Grand sourire", "Petite bouche"]
const FRECKLES := ["Sans", "Avec"]
const GLASSES := ["Sans", "Rondes", "Carrées"]
const BEARDS := ["Sans", "Barbe", "Moustache"]
const OUTFIT_STYLES := ["T-shirt", "Pull", "Chemise et short", "Robe", "Salopette"]

## Toutes les options d'apparence : clé → nombre de choix.
const APPEARANCE_COUNTS := {
	"body": 2, "height": 5, "build": 5, "skin": 6, "face": 3, "cheeks": 3, "blush": 3,
	"eye_color": 6, "eye_shape": 4, "brows": 3, "nose": 3, "mouth": 3, "freckles": 2, "glasses": 3,
	"hair_style": 9, "hair": 8, "beard": 3, "outfit_style": 5, "outfit": 8, "bottom": 6, "shoes": 5,
}
const APPEARANCE_DEFAULTS := {
	"body": 0, "height": 2, "build": 2, "skin": 0, "face": 0, "cheeks": 1, "blush": 1,
	"eye_color": 0, "eye_shape": 0, "brows": 0, "nose": 0, "mouth": 0, "freckles": 0, "glasses": 0,
	"hair_style": 0, "hair": 1, "beard": 0, "outfit_style": 0, "outfit": 0, "bottom": 0, "shoes": 0,
}


## Apparence complète et valide (les sauvegardes de la version 1 n'ont que 4 clés).
static func complete_appearance(appearance: Dictionary) -> Dictionary:
	var result := {}
	for key in APPEARANCE_DEFAULTS:
		var v: int = int(appearance.get(key, APPEARANCE_DEFAULTS[key]))
		result[key] = clampi(v, 0, APPEARANCE_COUNTS[key] - 1)
	return result


static func random_appearance(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var result := {}
	for key in APPEARANCE_COUNTS:
		result[key] = rng.randi() % APPEARANCE_COUNTS[key]
	# Rien d'extrême par hasard : taille et corpulence proches de la moyenne, barbe rare.
	result["height"] = 1 + rng.randi() % 3
	result["build"] = 1 + rng.randi() % 3
	if result["body"] == 0 or rng.randf() < 0.6:
		result["beard"] = 0
	if rng.randf() < 0.6:
		result["glasses"] = 0
	if rng.randf() < 0.7:
		result["freckles"] = 0
	if result["hair"] >= 6 and rng.randf() < 0.7:
		result["hair"] = rng.randi() % 6
	return result
