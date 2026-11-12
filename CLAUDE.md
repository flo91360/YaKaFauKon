# YaKaFauKon — consignes pour Claude

Jeu Godot 4.7.2 (voir README.md). Textes, commentaires et messages de commit
en français.

## Avant de pousser

- `godot --headless --import`
- `godot --headless --path . --script res://tests/run_tests.gd`
- `godot --headless --path . --script res://tests/gameplay_test.gd`
- `godot --headless --path . --script res://tests/profile_test.gd`
- `godot --headless --path . --script res://tests/flow_test.gd`

## Livraison

- Chaque changement passe par une pull request vers `main`, fusionnée
  automatiquement dès que la CI (« Construire le jeu », job `export`) est
  verte : ne pas demander d'approbation.
- Une modification visible pour l'enfant ou l'adulte augmente `config/version`
  dans `project.godot` (format X.Y.Z) et ajoute la section
  `## [X.Y.Z] - AAAA-MM-JJ` en tête de `CHANGELOG.md`. La fusion dans `main`
  publie alors la version (tag + Release GitHub avec `YaKaFauKon.exe`).
- Dans `export_presets.cfg`, laisser `file_version` et `product_version` vides :
  l'exe prend la version de `project.godot`.
- Les cartes PlaniFiKateur : le worker augmente lui-même la version et écrit
  le changelog.
