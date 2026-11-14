# Journal des modifications

Toutes les versions publiées de YaKaFauKon, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/YaKaFauKon/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [2.2.0] - 2026-11-14

### Ajouté

- **Mon rêve**, l'objectif de vie : en début de partie, l'enfant choisit son
  grand rêve parmi 8 (devenir champion, star de la chanson, grand savant, grand
  inventeur, maître artisan, organiser de grandes fêtes, vivre dans la nature,
  avoir une belle maison). Un nouveau cadre « Mon rêve », sous l'objectif,
  montre où il en est ; un clic affiche les étapes et un conseil pour la
  prochaine. Les joueurs déjà créés choisissent leur rêve à la prochaine partie.
- Les objectifs qui rapprochent du rêve portent la mention « Pour ton rêve »,
  et le jeu en propose toujours un quand c'est possible.
- Rêve réalisé : une fête, 100 pièces et 3 étoiles, puis l'enfant peut choisir
  un nouveau rêve. Il peut aussi en changer en cours de route.
- **5 nouvelles carrières**, avec 5 paliers et 5 missions chacune (25 nouvelles
  missions : consigne à lire, deux choix, liste à taper) : sportif, chanteur,
  scientifique, ingénieur, vie dans la nature. Le choix du travail présente
  les 7 métiers avec leur pictogramme et signale celui du rêve.
- Espace ergothérapeute : le rêve de l'enfant, son avancement, les rêves
  réalisés et le nombre de changements de rêve (par séance et sur la durée).

### Modifié

- Une compétence entraînée par les missions du métier (par exemple la patience
  pour la vie dans la nature) apparaît dans « Compétences » même sans achat au
  magasin, avec un conseil adapté.
- Le guide présente « Mon rêve ».

## [2.1.0] - 2026-11-13

### Ajouté

- **Magasin** (nouveau bouton en haut à droite) : les pièces gagnées servent
  enfin à quelque chose. L'enfant achète de quoi agrandir sa maison, et chaque
  achat apporte une nouvelle activité :
  - coin lecture (40 pièces) : lire un livre dans le fauteuil ;
  - table de jeux (60 pièces) : jouer à un jeu de société, un ami vient jouer ;
  - guitare (80 pièces) : jouer de la guitare ;
  - terrasse et potager (120 pièces) : la maison s'agrandit dehors, on peut
    jardiner ;
  - un chat (150 pièces) : le caresser et s'occuper de lui.
- 5 nouveaux champs lexicaux (145 mots) pour ces activités, avec leurs
  animations : le personnage lit, joue, gratte la guitare, arrose, s'accroupit
  près du chat.
- 6 nouvelles compétences : humour (dès le départ, en invitant des amis), puis
  logique, sociabilité, patience, responsabilité et douceur, qui s'ouvrent avec
  les achats. Le panneau « Compétences » montre celles qui restent à découvrir.
- Nouvel objectif à choisir : « Acheter au magasin ». Le bouton « Magasin »
  brille quand l'enfant a assez de pièces.
- Espace ergothérapeute : les achats de la séance et ceux de l'enfant
  apparaissent dans le récapitulatif.

### Modifié

- Le panneau « Compétences » est sur deux colonnes, et ses conseils ne citent
  que les activités que l'enfant possède.
- Le tutoriel et le guide présentent le magasin.

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
