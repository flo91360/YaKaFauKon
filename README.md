# YaKaFauKon

Jeu de simulation de vie original pour apprendre la frappe au clavier en s'amusant,
utilisé 5 à 10 minutes en fin de séance d'ergothérapie (enfants de 8 à 16 ans,
souvent dyslexiques, dysorthographiques ou TDAH).

Chaque action du personnage se déclenche en **recopiant un texte modèle**.
L'enfant gère aussi la vie de son personnage (double tâche), fait des choix
après avoir lu une consigne, et progresse dans une carrière.

## Jouer (version 2)

Double-cliquer sur **`YaKaFauKon.exe`**. Rien à installer : le jeu tient dans ce seul fichier
(Windows 10 ou 11, 64 bits). Le fichier n'est pas rangé dans le dépôt (il pèse 106 Mo) : il se fabrique
avec la commande ci-dessous. Chaque nouvelle version est publiée automatiquement dans les
[Releases](https://github.com/flo91360/YaKaFauKon/releases) du dépôt, avec `YaKaFauKon.exe`.

- Au premier lancement, Windows peut afficher « Windows a protégé votre ordinateur » car le fichier
  n'est pas signé : cliquer sur **Informations complémentaires** puis **Exécuter quand même**.
- Les sauvegardes restent sur l'ordinateur, dans `%APPDATA%\Godot\app_userdata\YaKaFauKon\profils`.
  Les joueurs créés avec la version 1 sont repris tels quels.
- Si le jeu saccade : touche **Échap** → Graphismes → **Léger** (le jeu le fait aussi tout seul
  s'il détecte qu'il est trop lent).

### Depuis le code source

1. Ouvrir Godot 4.7.2, « Importer » → choisir le dossier du projet (fichier `project.godot`).
2. Appuyer sur **F5**.

Fabriquer l'exe (les modèles d'exportation Godot 4.7.2 doivent être installés) :

```bash
godot --headless --path . --export-release "Windows" build/YaKaFauKon.exe
```

## Ce que contient le jeu

- **Objectif de vie (« Mon rêve »)** : en début de partie, l'enfant choisit son grand rêve parmi 8
  (devenir champion, star de la chanson, grand savant, grand inventeur, maître artisan, organiser de
  grandes fêtes, vivre dans la nature, avoir une belle maison). Le jeu montre les étapes, signale les
  objectifs qui en rapprochent, et fête le rêve réalisé (100 pièces, 3 étoiles). On peut en changer.
- **Profils** : plusieurs enfants sur le même PC. Sauvegarde automatique locale (toutes les 20 s et en quittant).
- **Création du personnage** par onglets : femme ou homme, taille, corpulence, peau, forme du visage,
  joues, nez, bouche, taches de rousseur, yeux (couleur, forme, sourcils, lunettes), 9 coiffures,
  barbe, 5 tenues et leurs couleurs. Bouton « Au hasard ». Le **miroir** du studio permet de changer de look.
- **Studio en 3D** avec jardin, cycle jour / nuit, lampes qui s'allument le soir. Lit, cuisine, lavabo,
  toilettes, douche, bureau, miroir, canapé, tapis de course, chevalet, établi.
- **Magasin** : les pièces gagnées (objectifs, missions) achètent de quoi agrandir la maison. Chaque achat
  ajoute un objet et une activité : coin lecture (40 pièces, lire), table de jeux (60, jeu de société avec
  un ami), guitare (80), terrasse et potager (120, jardiner), un chat (150, s'en occuper).
- **Personnage animé** : il marche, court, dort, mange, cuisine, se brosse les dents, se douche,
  téléphone, reçoit des amis, peint, parle au miroir, bricole, écrit, lit, joue à un jeu de société,
  joue de la guitare, arrose le potager, caresse le chat… La caméra se rapproche pendant l'activité.
- **5 jauges** : faim, sommeil, toilettes, hygiène, vie sociale. Alerte quand une jauge passe au rouge.
- **Frappe** : 3 niveaux de texte (« toilettes » → « les toilettes » → « aller aux toilettes »).
  Accents et majuscules ignorés, 1 faute admise sur un mot seul, 2 sur plusieurs mots.
  Les lettres bien tapées passent en vert, la première lettre différente en rouge (réglable).
- **10 compétences** : physique, créativité, charisme, organisation et humour dès le départ ; logique,
  sociabilité, patience, responsabilité et douceur avec les achats du magasin ou les missions de certains métiers.
- **Compétences par champ lexical** : dans une activité (sport, peinture, cuisine, planning, bois,
  miroir, téléphone, invités, puis lecture, jeu de société, guitare, jardinage, chat), l'enfant tape une **série de 5 mots** du champ lexical de l'activité.
  Chaque mot réussi fait monter la **barre de la compétence** ; barre pleine = un niveau de plus.
  Les mots s'adaptent au niveau de texte de l'enfant (courts, moyens, longs). Bouton « Arrêter » :
  les points déjà gagnés sont gardés.
- **Vitesse adaptative** : 6 premières frappes sans chronomètre pour mesurer la vitesse de base,
  puis un chronomètre régulier ; l'exigence suit les progrès puis se stabilise (au plus 2 × la vitesse de départ).
- **Objectifs à choix** : le jeu propose 3 objectifs (monter une compétence, taper des mots, prendre soin
  de soi, choisir un métier, réussir une mission, acheter au magasin…). L'enfant en choisit un, suit sa barre d'avancement
  et gagne des pièces et une étoile.
- **Tutoriel** au premier lancement (on peut le passer et le revoir depuis la pause) et **Guide**
  qui présente toutes les actions possibles avec chaque objet.
- **7 carrières** : organisateur d'événements, artisan, sportif, chanteur, scientifique, ingénieur et
  vie dans la nature. 5 paliers chacune, changement possible à partir du palier 2. Missions régulières
  (35 en tout) avec consigne, choix et liste à taper.
- **Accessibilité** : police Lexend, gros texte, pictogrammes, bouton « Écouter » (voix du système),
  sons doux et musique réglables ou coupables.
- **Réglages** (touche Échap) : volume des sons, de la musique, qualité des graphismes, plein écran.

## Espace ergothérapeute

Sur l'écran « Qui joue ? », bouton en bas à droite. **Mot d'accès : `ergo`**
(modifiable dans `scripts/screens/profile_screen.gd`, constante `ERGO_CODE`).

- **Réglages par enfant** : fréquence et exigence du chronomètre, tolérance aux fautes,
  niveau des textes (auto ou forcé), vitesse des besoins, minutes entre deux missions,
  lettres en couleur pendant la frappe,
  nouvelle mesure de la vitesse, suppression du profil.
- **Récapitulatif** : par séance datée (vitesse moyenne, types d'erreurs, temps de jeu,
  missions, tâches terminées/abandonnées, mots de champ lexical par activité, séries terminées ou
  arrêtées, objectifs choisis/atteints, achats au magasin, rêve réalisé ou changé, temps dans le rouge) et sur la durée
  (évolution de la vitesse, persévérance, gestion de vie, compétences), avec un résumé en mots-clés.
  Rien n'est envoyé en ligne.

## Tests

521 vérifications automatiques (logique, parcours de jeu, sauvegardes dont celles de la version 1, écrans) :

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/gameplay_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/profile_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/flow_test.gd
```

La CI GitHub (`.github/workflows/build.yml`, « Construire le jeu ») rejoue ces tests sous Linux,
fabrique `YaKaFauKon.exe` et, quand `config/version` de `project.godot` change sur `main`, publie la
Release avec la section correspondante de `CHANGELOG.md`.

## Organisation du code

- `scripts/core/` : données (`data.gd`), frappe tolérante, progression, objectifs, objectif de vie (`dreams.gd`), magasin, sauvegarde, récapitulatif.
- `scripts/world/` : studio (décor, lumière, caméra, effets), meubles, personnage articulé, formes 3D.
- `scripts/ui/` : thème, interface de jeu, panneaux (frappe, compétences, travail, mission, objectifs, rêve, magasin, guide, tutoriel, pause).
- `scripts/screens/` : écrans (joueurs, création, jeu, ergothérapeute).
- `tools/` : scripts Python qui fabriquent les textures, les pictogrammes, les sons et la musique.
- Pour ajouter une activité, des mots, une compétence, une mission ou une carrière : `scripts/core/data.gd`
  (les listes de mots sont dans `LEXIQUE`, les carrières dans `CAREERS` et `CAREER_ORDER`, les rêves dans `DREAMS`). Pour un nouvel achat du magasin : `SHOP` dans `data.gd`
  et son décor dans `add_purchase` de `scripts/world/studio.gd`.

Pas encore dans le jeu : ressources à récolter, relations et famille (et le rêve « fonder une famille »), plateforme en ligne.
