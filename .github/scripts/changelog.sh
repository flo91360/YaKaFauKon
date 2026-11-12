#!/usr/bin/env bash
# Prépare les notes d'une version à partir de CHANGELOG.md.
#
#   .github/scripts/changelog.sh <version> <fichier de notes>
#
# - Si CHANGELOG.md contient une section « ## [<version>] », elle est copiée
#   dans le fichier de notes.
# - Sinon, la section est rédigée à partir des commits depuis le tag de la
#   version précédente, ajoutée en tête de CHANGELOG.md, et le script
#   affiche « genere » (le workflow enregistre alors CHANGELOG.md sur main).
set -euo pipefail

version="$1"
notes="$2"
changelog=CHANGELOG.md

# Section « ## [version] … » jusqu'à la section suivante (titre exclu).
extraire() {
  awk -v v="$version" '
    /^## \[/ { dedans = index($0, "## [" v "]") == 1; next }
    dedans { print }
  ' "$changelog" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

if [ -f "$changelog" ] && grep -q "^## \[$version\]" "$changelog"; then
  extraire > "$notes"
  exit 0
fi

# Tag de la version précédente (le plus récent des tags v*, hors celui-ci).
precedent=$(git tag --list 'v*' --sort=-v:refname --merged HEAD | grep -vx "v$version" | head -n1 || true)
if [ -n "$precedent" ]; then
  plage="$precedent..HEAD"
else
  plage="HEAD"
fi
# Titres des commits, sans les commits de fusion.
git log --no-merges --format='- %s' "$plage" > "$notes.tmp"
if [ ! -s "$notes.tmp" ]; then
  echo "- Corrections et améliorations." > "$notes.tmp"
fi
{
  echo "### Modifications"
  echo
  cat "$notes.tmp"
} > "$notes"
rm -f "$notes.tmp"

section=$(printf '## [%s] - %s\n\n%s\n' "$version" "$(date -u +%Y-%m-%d)" "$(cat "$notes")")
if [ -f "$changelog" ] && grep -q '^## \[' "$changelog"; then
  # Insérer avant la première section existante.
  awk -v s="$section" '!fait && /^## \[/ { print s; print ""; fait = 1 } { print }' \
    "$changelog" > "$changelog.tmp"
  mv "$changelog.tmp" "$changelog"
else
  { [ -f "$changelog" ] && cat "$changelog" || echo "# Journal des modifications"; echo; echo "$section"; } > "$changelog.tmp"
  mv "$changelog.tmp" "$changelog"
fi
echo genere
