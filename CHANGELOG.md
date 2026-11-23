# Journal des modifications

Toutes les versions publiées de YaKaFauKon, la plus récente en premier. Chaque
version correspond à un tag `vX.Y.Z` et à une Release GitHub
(https://github.com/flo91360/YaKaFauKon/releases) dont la description reprend la
section de la version.

Pour une nouvelle version : augmenter `config/version` dans `project.godot` et
ajouter ici une section `## [X.Y.Z] - AAAA-MM-JJ` décrivant ce qui change pour
l'enfant ou l'adulte. Sans section, la publication en rédige une à partir des
titres des commits.

## [2.4.5] - 2026-11-23

### Changé

- **Accords au féminin** : avec un personnage « Femme », les alertes disent « est
  très fatiguée ! » et « se sent seule ! ». Les métiers, leurs paliers et les rêves
  sont accordés aussi : sportive, artisane, chanteuse, ingénieure, organisatrice…
  et « Devenir championne », « Devenir une grande savante ». Le récapitulatif de
  l'ergo suit le même accord.
- **Course de relais** : « Tu cours en dernier » remplace « Tu es le dernier », qui
  ne convenait pas à tous les enfants.

## [2.4.4] - 2026-11-23

### Changé

- **Mode « Léger » plus léger** : plus d'ombre à l'intérieur de la maison (la
  lumière reste), plus d'ombre sous les petits objets (plus de 900 sur environ
  1 300), et les portraits de « Ma famille » sans antialiasing. Seule l'ombre du
  soleil, dans le jardin, est gardée. En « Beau », la carte des ombres passe de
  8 192 à 4 096 pixels : environ 96 Mo de mémoire vidéo en moins, pour des
  ombres à peine moins fines.
- **Allègement automatique réversible** : quand le jeu allège tout seul les
  graphismes parce qu'il saccade, il retente le niveau au-dessus au début des
  2 parties suivantes. Un ralentissement passager ne laisse plus « Léger » pour
  toujours. Un choix fait à la main dans les réglages est toujours respecté.

## [2.4.3] - 2026-11-23

### Pour l'adulte

- **Mot d'accès choisi par l'ergo** : au premier passage, `ergo` ouvre l'espace
  ergothérapeute puis le jeu demande un mot à soi (6 caractères ou plus). Il est
  gardé haché sur le PC, et `ergo` ne marche plus. Il se change dans la nouvelle
  page « Ce PC » de l'espace ergo.
- **Prénoms cachés** : dans « Ce PC », l'ergo peut n'afficher que l'initiale et la
  couleur de chaque joueur sur « Qui joue ? ». Un enfant ne voit plus les prénoms
  des autres patients.

### Changé

- **Prénom déjà pris** : à la création d'un joueur, un prénom qui existe déjà est
  signalé. L'enfant peut ajouter l'initiale de son nom, ou appuyer encore pour
  garder ce prénom.

## [2.4.2] - 2026-11-23

### Pour l'adulte

- **Fautes comptées une fois** : appuyer plusieurs fois sur Entrée pour le même
  texte ne recompte plus les mêmes fautes. Le taux de fautes se calcule sur tous
  les textes tentés, réussis ou non.
- **Abandons** : fermer un texte sans avoir tapé une lettre n'est plus compté
  comme une tâche abandonnée.
- **Vitesse par niveau de texte** : le récapitulatif de séance donne la vitesse
  pour chaque niveau de texte, et le mot-clé « Vitesse en progrès / stable / en
  baisse » compare des séances du même niveau. Passer à des textes plus longs ne
  passe plus pour une baisse.

### Changé

- **Choix des missions mélangés** : l'ordre des réponses change à chaque
  question, la bonne n'est plus presque toujours au milieu. Le bouton qui lit la
  question suit le même ordre.

## [2.4.1] - 2026-11-23

### Corrigé

- **Mission bloquée** : si le personnage arrivait à une activité pendant que
  l'enfant tapait un élément de mission, la série de mots prenait sa place et la
  mission devenait introuvable. La mission garde maintenant la frappe, puis
  l'activité commence. Pendant une série, « Taper » de la mission attend la fin
  de la série.
- **Pause** : le personnage s'arrête quand un panneau (magasin, pause…) est
  ouvert. Une série ne démarre plus cachée derrière, et le chronomètre ne compte
  plus un mot « trop lent » que l'enfant ne voyait pas.
- **Lettres en couleur** : seule la première lettre différente passe en rouge.
  Une lettre oubliée ne colore plus toute la fin du mot.

### Pour l'adulte

- **Sauvegarde sûre** : le profil est écrit dans un fichier temporaire avant de
  remplacer l'ancien, gardé en copie de secours (`.bak`). Après une coupure de
  courant pendant une sauvegarde, le jeu reprend la dernière sauvegarde complète
  au lieu de faire disparaître l'enfant de la liste.

## [2.4.0] - 2026-11-15

### Ajouté

- **Ma famille** : un nouveau cadre à gauche de l'écran. L'enfant peut rencontrer
  quelqu'un (il faut le niveau 1 en charisme) : le jeu propose deux femmes et deux
  hommes, chacun avec ses goûts, et c'est l'enfant qui choisit. Ce n'est jamais
  obligatoire.
- **Complicité** : sur le canapé, offrir des fleurs, danser ou faire un câlin
  (séries de 5 mots). Chaque mot réussi fait monter la complicité ; à 60 %, le
  couple peut vivre ensemble. Le lit devient un grand lit et le conjoint reste à
  la maison (il lit sur le canapé, dort à côté le soir).
- **Enfants, ou pas** : avoir un bébé ou non est un choix, et « Pas d'enfant »
  peut changer plus tard. Il faut le niveau 2 en organisation. L'enfant choisit
  le prénom ; une chambre d'enfant apparaît devant la maison. On berce le bébé
  et on lui donne le biberon au berceau ; après 4 soins, il grandit et joue dans
  sa chambre (jouer avec lui, lui raconter une histoire). Deux enfants au plus.
- **Nouveau rêve « Fonder une famille »** (9 rêves en tout), et deux nouveaux
  objectifs : rencontrer quelqu'un, passer du temps en famille.
- Le bouton en bas à droite passe de la maison au jardin, puis à la chambre des
  enfants quand elle existe.

### Pour l'adulte

- Le récapitulatif montre la famille en une ligne, et chaque séance note les
  grands moments (rencontre, vie à deux, naissance, bébé qui grandit, choix de
  ne pas avoir d'enfant).

## [2.3.0] - 2026-11-14

### Ajouté

- **Ressources à récolter** : dans le jardin, l'enfant coupe du bois et ramasse
  des pierres. Chaque mot réussi de la série rapporte une bûche ou une pierre,
  gardée dans sa réserve (affichée en bas à droite de l'écran).
- **Construire** : avec sa réserve, il construit dans la cour un banc de jardin
  (6 bûches), une fontaine (10 pierres, physique niveau 2) puis un barbecue
  (6 bûches et 8 pierres, physique niveau 3 et créativité niveau 2). Chaque
  construction ajoute une activité : se reposer sur le banc, se laver à la
  fontaine, faire un barbecue avec un ami. L'écran « Construire » montre ce
  qu'il a déjà et ce qu'il lui manque.
- **Vue du jardin** : un bouton « Jardin » / « Maison », en bas à droite, passe
  d'une vue à l'autre. La caméra suit aussi le personnage quand il sort ou
  rentre. Une cour pavée relie la maison au tas de bois et aux rochers.
- Deux nouveaux objectifs : récolter des bûches ou des pierres, et construire
  la prochaine construction du jardin.
- Espace ergothérapeute : la réserve et les constructions de l'enfant, et par
  séance ce qu'il a récolté et construit.

### Modifié

- Couper du bois et ramasser des pierres entraînent la compétence physique et
  font baisser un peu l'hygiène et le sommeil, comme le sport.
- Le guide présente le jardin, la récolte et le bouton « Construire ».
- La boîte aux lettres et les pas japonais du jardin ont été déplacés pour
  laisser la place à la cour.

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
