# YaKaFauKon

Jeu de simulation de vie original pour apprendre la frappe au clavier en s'amusant,
utilisé 5 à 10 minutes en fin de séance d'ergothérapie (enfants de 8 à 16 ans,
souvent dyslexiques, dysorthographiques ou TDAH).

Chaque action du personnage se déclenche en **recopiant un texte modèle**.
L'enfant gère aussi la vie de son personnage (double tâche), fait des choix
après avoir lu une consigne, et progresse dans une carrière.

## Lancer le jeu

1. Ouvrir `Documents\Godot\Godot_v4.7.2-stable_win64.exe`.
2. « Importer » → choisir le dossier `Documents\Jeu-ergo` (fichier `project.godot`).
3. Appuyer sur **F5** (ou le bouton ▶ en haut à droite).

En ligne de commande :

```bash
Godot_v4.7.2-stable_win64.exe --path C:\Users\flori\Documents\Jeu-ergo
```

## Ce que contient la V1

- **Profils** : plusieurs enfants sur le même PC, création d'un personnage
  (prénom, peau, cheveux, coiffure, tenue). Sauvegarde automatique locale
  (toutes les 20 s et en quittant), dans `%APPDATA%\Godot\app_userdata\YaKaFauKon\profils`.
- **Studio en 3D** : lit, cuisine, lavabo, toilettes, douche, bureau, miroir, canapé,
  tapis de course, chevalet, établi. Rendu « Compatibility » pour les PC sans carte graphique.
- **5 jauges** : faim, sommeil, toilettes, hygiène, vie sociale. Alerte quand une jauge
  passe au rouge. Le sommeil est accéléré (environ 20 secondes).
- **Frappe** : 3 niveaux de texte (« toilettes » → « les toilettes » → « aller aux toilettes »).
  Accents et majuscules ignorés, 1 faute admise sur un mot seul, 2 sur plusieurs mots.
- **Vitesse adaptative** : 6 premières frappes sans chronomètre pour mesurer la vitesse de base,
  puis un chronomètre régulier ; l'exigence suit les progrès puis se stabilise (au plus 2 × la vitesse de départ).
- **Compétences** sur 10 (physique, créativité, charisme, organisation) avec un panneau
  « Comment progresser ». Les autres compétences (logique, humour, patience…) sont prêtes dans les données.
- **Carrières** : organisateur d'événements et artisan, 5 paliers chacune, changement possible
  à partir du palier 2. Missions régulières avec consigne, choix et liste à taper.
- **Accessibilité** : police Lexend, gros texte, interface épurée, bouton « Écouter » (voix du système).

## Espace ergothérapeute

Sur l'écran « Qui joue ? », bouton en bas à droite. **Mot d'accès : `ergo`**
(modifiable dans `scripts/screens/profile_screen.gd`, constante `ERGO_CODE`).

- **Réglages par enfant** : fréquence et exigence du chronomètre, tolérance aux fautes,
  niveau des textes (auto ou forcé), vitesse des besoins, minutes entre deux missions,
  nouvelle mesure de la vitesse, suppression du profil.
- **Récapitulatif** : par séance datée (vitesse moyenne, types d'erreurs, temps de jeu,
  missions, tâches terminées/abandonnées, temps dans le rouge) et sur la durée
  (évolution de la vitesse, persévérance, gestion de vie, compétences), avec un résumé en mots-clés.
  Rien n'est envoyé en ligne.

## Tests

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/gameplay_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/profile_test.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/flow_test.gd
```

## Organisation du code

- `scripts/core/` : données (`data.gd`), frappe tolérante, progression, sauvegarde, récapitulatif.
- `scripts/world/` : studio, meubles, personnage.
- `scripts/ui/` : thème, interface de jeu, panneaux (frappe, compétences, travail, mission).
- `scripts/screens/` : écrans (joueurs, création, jeu, ergothérapeute).
- Pour ajouter une activité, une compétence, une mission ou une carrière : `scripts/core/data.gd`.

Hors V1 : autres carrières, agrandissement du logement, relations et famille, plateforme en ligne.
