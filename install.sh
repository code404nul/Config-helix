#!/usr/bin/env bash
# C'est claude code qui a fait

set -euo pipefail

gras=$'\033[1m'; bleu=$'\033[1;34m'; vert=$'\033[1;32m'
jaune=$'\033[1;33m'; rouge=$'\033[1;31m'; gris=$'\033[2m'; fin=$'\033[0m'

etape()  { printf '\n%s[%s/6]%s %s%s%s\n' "$bleu" "$1" "$fin" "$gras" "$2" "$fin"; }
dire()   { printf '      %s\n' "$*"; }
bien()   { printf '      %s✓%s %s\n' "$vert" "$fin" "$*"; }
oups()   { printf '      %s✘%s %s\n' "$rouge" "$fin" "$*" >&2; }
note()   { printf '      %s%s%s\n' "$gris" "$*" "$fin"; }

trap 'printf "\n%sAïe, quelque chose s'"'"'est mal passé (ligne %s).%s\n" "$rouge" "$LINENO" "$fin";
      printf "Regarde le message juste au-dessus, puis relance ./install.sh quand c'"'"'est réglé.\n"' ERR

# Dossier du script : permet de retrouver helix/config.toml même lancé depuis ailleurs
ici="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat <<EOF

${gras}Salut !${fin}
Je vais installer de quoi rendre Helix vraiment pratique pour coder :

  ${gras}Python${fin}   ruff          vérifie et formate ton code
           basedpyright  autocomplétion et vérification des types
  ${gras}C / C++${fin}  clangd        autocomplétion, erreurs, navigation
           clang-format  formatage automatique

Je vais aussi ${gras}mettre ta config en place${fin} (thème + réglages) et
${gras}compiler la coloration syntaxique${fin} pour que tout fonctionne du premier coup.

${gris}Il faudra ton mot de passe une fois (pour apt). Ça prend 2 à 4 minutes.${fin}
EOF


if [[ $EUID -eq 0 ]]; then
    echo
    oups "Pas besoin de sudo devant le script : lance juste ./install.sh"
    note "Je demanderai le mot de passe moi-même au bon moment."
    exit 1
fi

if ! command -v apt-get >/dev/null; then
    echo
    oups "Je ne trouve pas apt : ce script est fait pour Ubuntu ou Debian."
    exit 1
fi

echo
read -rp "On y va ? [O/n] " reponse
if [[ ${reponse,,} == n* ]]; then
    echo "Pas de souci, rien n'a été touché. À plus !"
    exit 0
fi

etape 1 "Installation des outils C / C++"
dire "Je mets à jour la liste des paquets..."
sudo apt-get update -qq
dire "J'installe clangd, clang-format, pipx, git et un compilateur C..."
sudo apt-get install -y -qq clangd clang-format pipx git build-essential >/dev/null
bien "C'est fait."

etape 2 "Préparation de pipx"
export PATH="$HOME/.local/bin:$PATH"
pipx ensurepath >/dev/null 2>&1
bien "pipx est prêt, et ~/.local/bin sera dans ton PATH."
note "(pipx installe chaque outil Python dans son coin, sans rien casser ailleurs)"

etape 3 "Installation des outils Python"
for outil in ruff basedpyright; do
    if pipx list --short 2>/dev/null | grep -q "^$outil "; then
        dire "$outil est déjà là, je regarde s'il y a une mise à jour..."
        pipx upgrade "$outil" >/dev/null
        bien "$outil est à jour."
    else
        dire "J'installe $outil..."
        pipx install "$outil" >/dev/null
        bien "$outil est installé."
    fi
done

etape 4 "Mise en place de ta config Helix"
dest="$HOME/.config/helix"
mkdir -p "$dest"
for fichier in config.toml languages.toml; do
    source="$ici/helix/$fichier"
    if [[ ! -f "$source" ]]; then
        oups "Je ne trouve pas $source"
        exit 1
    fi
    if [[ -f "$dest/$fichier" ]] && ! cmp -s "$source" "$dest/$fichier"; then
        sauvegarde="$dest/$fichier.sauvegarde-$(date +%Y%m%d-%H%M%S)"
        cp "$dest/$fichier" "$sauvegarde"
        note "Ancien $fichier sauvegardé : $sauvegarde"
    fi
    cp "$source" "$dest/$fichier"
    bien "$fichier copié dans ~/.config/helix/"
done

etape 5 "Compilation de la coloration syntaxique"
if command -v hx >/dev/null; then
    dire "Je télécharge et compile les grammaires tree-sitter (1 à 2 min)..."
    hx --grammar fetch >/dev/null 2>&1 || true
    hx --grammar build >/dev/null 2>&1 || true
    if ls "$dest"/runtime/grammars/*.so >/dev/null 2>&1; then
        bien "Coloration syntaxique prête."
    else
        oups "La coloration n'a pas pu être compilée (réseau ou compilateur manquant ?)."
    fi
else
    oups "Helix (hx) n'est pas installé : installe-le, puis relance ./install.sh."
    note "Sans hx, impossible de compiler la coloration."
fi

etape 6 "Petite vérification"
manquants=0
for programme in clangd clang-format ruff basedpyright-langserver; do
    if command -v "$programme" >/dev/null; then
        bien "$programme"
    else
        oups "$programme introuvable"
        manquants=$((manquants + 1))
    fi
done
if [[ -f "$dest/config.toml" && -f "$dest/languages.toml" ]]; then
    bien "config Helix en place"
else
    oups "config Helix manquante"
    manquants=$((manquants + 1))
fi

trap - ERR

echo
if [[ $manquants -eq 0 ]]; then
    cat <<EOF
${vert}${gras}Tout est prêt ! 🎉${fin}

Config, thème et coloration syntaxique sont en place.
Il reste juste une chose : ${gras}ferme et rouvre ton terminal${fin}
(pour qu'il trouve les nouveaux outils).

Ensuite, pour tester :
  ${gras}hx test.py${fin}   le code doit être coloré, tape ${gras}imp${fin} → Helix propose ${gras}import${fin}
  ${gras}hx --health python${fin}  et  ${gras}hx --health cpp${fin}  doivent être au vert.

Bon code !
EOF
else
    cat <<EOF
${jaune}${gras}Presque !${fin} Il manque $manquants outil(s), regarde au-dessus.

Souvent, il suffit de fermer et rouvrir le terminal, puis de relancer :
  ${gras}./install.sh${fin}
EOF
    exit 1
fi
