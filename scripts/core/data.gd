extends RefCounted
## Données du jeu (besoins, actions, compétences, carrières, missions).
## Tout est décrit ici sous forme de dictionnaires pour pouvoir ajouter
## facilement de nouvelles activités, compétences ou carrières.

# --- Besoins --------------------------------------------------------------
# decay = points perdus par heure de jeu (1 heure de jeu = 1 minute réelle).
const NEEDS := {
	"faim": {"label": "Faim", "decay": 14.0, "alerte": "a très faim !", "conseil": "Va à la cuisine pour manger."},
	"sommeil": {"label": "Sommeil", "decay": 7.0, "alerte": "est très fatigué !", "conseil": "Va dormir dans le lit."},
	"toilettes": {"anim": "sit_read", "label": "Toilettes", "decay": 16.0, "alerte": "doit aller aux toilettes !", "conseil": "Va aux toilettes."},
	"hygiene": {"label": "Hygiène", "decay": 9.0, "alerte": "a besoin de se laver !", "conseil": "Prends une douche ou brosse-toi les dents."},
	"social": {"label": "Vie sociale", "decay": 8.0, "alerte": "se sent seul !", "conseil": "Appelle un ami ou invite des amis."},
}
const NEED_ORDER := ["faim", "sommeil", "toilettes", "hygiene", "social"]
const RED_THRESHOLD := 25.0
const ORANGE_THRESHOLD := 50.0

# --- Compétences -------------------------------------------------------------
# "active" = utilisée dans la V1. Les autres sont prêtes pour la suite.
const SKILLS := {
	"physique": {"label": "Physique", "active": true,
		"aide": "Fais du sport sur le tapis de course ou travaille le bois à l'établi. Les missions d'artisan aident aussi."},
	"creativite": {"label": "Créativité", "active": true,
		"aide": "Peins au chevalet, fais la cuisine ou travaille le bois. Les missions aident aussi."},
	"charisme": {"label": "Charisme", "active": true,
		"aide": "Parle devant le miroir, appelle un ami ou invite des amis. Les missions d'organisateur aident aussi."},
	"organisation": {"label": "Organisation", "active": true,
		"aide": "Fais ton planning au bureau ou fais la cuisine. Les missions d'organisateur aident beaucoup."},
	"logique": {"label": "Logique", "active": false, "aide": "Lire, jouer à des jeux de société."},
	"humour": {"label": "Humour", "active": false, "aide": "Jouer à des jeux de société, inviter des gens."},
	"sociabilite": {"label": "Sociabilité", "active": false, "aide": "Jouer à des jeux de société."},
	"patience": {"label": "Patience", "active": false, "aide": "Jardiner, s'occuper des animaux."},
	"responsabilite": {"label": "Responsabilité", "active": false, "aide": "S'occuper des animaux."},
	"douceur": {"label": "Douceur", "active": false, "aide": "S'occuper des animaux."},
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
# anim = animation du personnage pendant l'action.
# Les actions qui donnent de la compétence se jouent en « série de mots » : après le
# mot de départ, l'enfant tape WORDS_PER_SERIES mots du champ lexical (voir LEXIQUE).
const ACTIONS := {
	"dormir": {"anim": "sleep", "label": "Dormir", "texts": ["lit", "le lit", "aller au lit"], "minutes": 480,
		"needs": {"sommeil": 100.0}, "skills": {}, "sleep": true, "verbe": "dort"},
	"manger": {"anim": "eat", "label": "Manger", "texts": ["repas", "un repas", "manger un repas"], "minutes": 30,
		"needs": {"faim": 70.0}, "skills": {}, "verbe": "mange"},
	"cuisiner": {"anim": "cook", "label": "Faire la cuisine", "texts": ["cuisine", "la cuisine", "faire la cuisine"], "minutes": 60,
		"needs": {"faim": 45.0, "hygiene": -5.0}, "skills": {"organisation": 10.0, "creativite": 6.0}, "verbe": "cuisine"},
	"toilettes": {"label": "Aller aux toilettes", "texts": ["toilettes", "les toilettes", "aller aux toilettes"], "minutes": 10,
		"needs": {"toilettes": 100.0}, "skills": {}, "verbe": "est aux toilettes"},
	"douche": {"anim": "shower", "label": "Prendre une douche", "texts": ["douche", "la douche", "prendre une douche"], "minutes": 20,
		"needs": {"hygiene": 75.0}, "skills": {}, "verbe": "se douche"},
	"dents": {"anim": "brush", "label": "Se brosser les dents", "texts": ["dents", "les dents", "se brosser les dents"], "minutes": 5,
		"needs": {"hygiene": 30.0}, "skills": {}, "verbe": "se brosse les dents"},
	"appeler": {"anim": "sit_phone", "label": "Appeler un ami", "texts": ["ami", "un ami", "appeler un ami"], "minutes": 30,
		"needs": {"social": 45.0}, "skills": {"charisme": 4.0}, "verbe": "téléphone"},
	"inviter": {"anim": "sit_chat", "label": "Inviter des amis", "texts": ["amis", "des amis", "inviter des amis"], "minutes": 90,
		"needs": {"social": 80.0, "faim": -10.0}, "skills": {"charisme": 8.0}, "verbe": "reçoit des amis"},
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


# --- Carrières -----------------------------------------------------------------
const CAREERS := {
	"organisateur": {
		"label": "Organisateur d'événements",
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
}
const MISSIONS_PER_TIER := 3
const CAREER_CHANGE_MIN_TIER := 2 # palier à atteindre avant de pouvoir changer

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
