#!/usr/bin/env bash
# C'est claude code qui a fait

set -euo pipefail

gras=$'\033[1m'; bleu=$'\033[1;34m'; vert=$'\033[1;32m'
jaune=$'\033[1;33m'; rouge=$'\033[1;31m'; gris=$'\033[2m'; fin=$'\033[0m'

etape()  { printf '\n%s[%s/4]%s %s%s%s\n' "$bleu" "$1" "$fin" "$gras" "$2" "$fin"; }
dire()   { printf '      %s\n' "$*"; }
bien()   { printf '      %s✓%s %s\n' "$vert" "$fin" "$*"; }
oups()   { printf '      %s✘%s %s\n' "$rouge" "$fin" "$*" >&2; }
note()   { printf '      %s%s%s\n' "$gris" "$*" "$fin"; }

trap 'printf "\n%sAïe, quelque chose s'"'"'est mal passé (ligne %s).%s\n" "$rouge" "$LINENO" "$fin";
      printf "Regarde le message juste au-dessus, puis relance ./install.sh quand c'"'"'est réglé.\n"' ERR

cat <<EOF

${gras}Salut !${fin}
Je vais installer de quoi rendre Helix vraiment pratique pour coder :

  ${gras}Python${fin}   ruff          vérifie et formate ton code
           basedpyright  autocomplétion et vérification des types
  ${gras}C / C++${fin}  clangd        autocomplétion, erreurs, navigation
           clang-format  formatage automatique

${gris}Il faudra ton mot de passe une fois (pour apt). Ça prend 1 à 2 minutes.${fin}
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
dire "J'installe clangd, clang-format et pipx..."
sudo apt-get install -y -qq clangd clang-format pipx >/dev/null
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

etape 4 "Petite vérification"
manquants=0
for programme in clangd clang-format ruff basedpyright-langserver; do
    if command -v "$programme" >/dev/null; then
        bien "$programme"
    else
        oups "$programme introuvable"
        manquants=$((manquants + 1))
    fi
done

trap - ERR

echo
if [[ $manquants -eq 0 ]]; then
    cat <<EOF
${vert}${gras}Tout est prêt ! 🎉${fin}

Il reste juste une chose : ${gras}ferme et rouvre ton terminal${fin}
(pour qu'il trouve les nouveaux outils).

Ensuite, pour tester :
  ${gras}hx test.py${fin}   puis tape ${gras}imp${fin} → Helix te propose ${gras}import${fin}
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
