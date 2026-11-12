# Journal des modifications

Toutes les versions publiées de YaKaFauKon, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/YaKaFauKon/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [2.0.1] - 2026-11-13

### Corrigé

- Tutoriel : la bulle d'explication passe en bas de l'écran quand elle
  cacherait la flèche dorée (étapes « lavabo » et « tapis de course »).
- Création du personnage : le visage « Carré » ne colle plus un bloc sous le
  visage, c'est la mâchoire elle-même qui devient carrée. Les joues rondes
  font aussi partie du visage (plus de bosses visibles).
- Lumière : le soleil n'éclaire plus l'intérieur de la maison et ne tourne
  plus, donc les ombres ne bougent plus en permanence (murs, douche). La pièce
  a sa propre lumière douce, plus faible la nuit quand les lampes s'allument.

## [2.0.0] - 2026-11-12

### Ajouté

- `YaKaFauKon.exe` est fabriqué et vérifié à chaque modification, puis publié
  dans une Release GitHub à chaque nouvelle version : il se télécharge sans
  rien installer.
- Version 2 du jeu : graphismes, séries de mots par champ lexical, objectifs à
  choix, tutoriel et guide.
