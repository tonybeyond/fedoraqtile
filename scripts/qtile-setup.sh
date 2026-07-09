#!/usr/bin/env bash
# =============================================================================
# qtile-setup.sh — Qtile X11 style DTOS (Fedora) — v2 robuste
# =============================================================================
# AUTO-SUFFISANT : trouve le repo où qu'il soit, ou le clone lui-même.
# Utilisable de 3 façons, toutes équivalentes :
#   sudo bash /opt/fedoraqtile/scripts/qtile-setup.sh
#   bash ~/fedoraqtile/scripts/qtile-setup.sh
#   curl -fsSL https://raw.githubusercontent.com/tonybeyond/fedoraqtile/main/scripts/qtile-setup.sh | bash
#
# Lancé root : installe les paquets puis bascule en user pour les configs.
# Lancé user : sudo pour les paquets, direct pour les configs.
# ÉCHEC DUR si le déploiement des configs ne peut pas être vérifié.
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log_info()    { printf "${BLUE}  ·${NC}  %s\n" "$*"; }
log_ok()      { printf "${GREEN}  ✓${NC}  %s\n" "$*"; }
log_warn()    { printf "${YELLOW}  ⚠${NC}  %s\n" "$*"; }
log_error()   { printf "${RED}  ✗${NC}  %s\n" "$*" >&2; }
log_section() { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }
die()         { log_error "$*"; exit 1; }

REPO_URL="https://github.com/tonybeyond/fedoraqtile.git"

# ── Déterminer l'utilisateur cible et le mode ─────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
  [[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]] \
    || die "Impossible de déterminer l'utilisateur cible. Lancer : sudo bash $0"
  RUN_AS_ROOT=true
else
  TARGET_USER="${USER}"
  RUN_AS_ROOT=false
fi
TARGET_HOME=$(getent passwd "${TARGET_USER}" | cut -d: -f6)
log_info "Utilisateur cible : ${TARGET_USER} (${TARGET_HOME})"

# ── Résolution du repo : script dir → /opt → ~ → clone auto ──────────────────
log_section "Localisation du repo fedoraqtile"
REPO_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || echo '')"

for candidate in \
  "${SCRIPT_DIR}/.." \
  "/opt/fedoraqtile" \
  "${TARGET_HOME}/fedoraqtile" \
  "${TARGET_HOME}/Downloads/fedoraqtile"; do
  if [[ -f "${candidate}/configs/qtile/config.py" ]]; then
    REPO_DIR="$(cd "${candidate}" && pwd)"
    log_ok "Repo trouvé : ${REPO_DIR}"
    break
  fi
done

if [[ -z "${REPO_DIR}" ]]; then
  log_info "Repo introuvable localement — clone automatique..."
  REPO_DIR="/tmp/fedoraqtile-setup-$$"
  git clone --depth 1 "${REPO_URL}" "${REPO_DIR}" 2>/dev/null \
    || die "Clone échoué. Vérifier réseau + git : sudo dnf install -y git"
  log_ok "Repo cloné : ${REPO_DIR}"
fi

# Vérification d'intégrité du repo AVANT toute action
for required in configs/qtile/config.py configs/qtile/autostart.sh \
                configs/picom/picom.conf configs/rofi/config.rasi \
                configs/dunst/dunstrc configs/alacritty/alacritty.toml; do
  [[ -f "${REPO_DIR}/${required}" ]] \
    || die "Fichier manquant dans le repo : ${required} — repo corrompu, re-cloner."
done
log_ok "Intégrité du repo vérifiée (6 configs présentes)"

# ── 1. Paquets (root ou sudo) ────────────────────────────────────────────────
log_section "Installation des paquets"
DNF="dnf"; [[ "${RUN_AS_ROOT}" == false ]] && DNF="sudo dnf"

${DNF} install -y \
  qtile python3-dbus-next \
  xorg-x11-server-Xorg xorg-x11-xinit xrandr xsetroot setxkbmap \
  lightdm lightdm-gtk-greeter \
  picom rofi nitrogen dunst \
  thunar thunar-volman gvfs \
  xsecurelock xkill alacritty \
  network-manager-applet \
  flameshot xclip playerctl brightnessctl pavucontrol \
  papirus-icon-theme lxappearance \
  git curl unzip \
  || die "dnf install a échoué — vérifier le réseau/repos"
log_ok "Paquets installés"

# Session graphique
if [[ "${RUN_AS_ROOT}" == true ]]; then
  systemctl set-default graphical.target &>/dev/null
  systemctl enable lightdm &>/dev/null
else
  sudo systemctl set-default graphical.target &>/dev/null
  sudo systemctl enable lightdm &>/dev/null
fi
log_ok "LightDM activé, boot graphique"

# Clavier X11 persistant
if [[ "${RUN_AS_ROOT}" == true ]]; then
  localectl set-x11-keymap ch pc105 fr 2>/dev/null || true
else
  sudo localectl set-x11-keymap ch pc105 fr 2>/dev/null || true
fi
log_ok "Keymap X11 : ch (fr)"

# ── 2. Partie utilisateur : configs + fonts + validation ─────────────────────
# Fonction exécutée en tant que TARGET_USER (jamais root)
deploy_user_configs() {
  local repo="$1"
  local fail=0

  # deploy <src-rel> <dst-abs> : copie + VÉRIFIE par comparaison binaire
  deploy() {
    local src="${repo}/$1" dst="$2"
    mkdir -p "$(dirname "${dst}")"
    [[ -f "${dst}" && "$3" == "backup" ]] \
      && cp "${dst}" "${dst}.bak-$(date +%Y%m%d-%H%M%S)"
    cp "${src}" "${dst}" 2>/dev/null
    if cmp -s "${src}" "${dst}"; then
      printf "  \033[0;32m✓\033[0m  %s (%s bytes)\n" "$2" "$(wc -c < "${dst}")"
    else
      printf "  \033[0;31m✗\033[0m  ÉCHEC déploiement : %s\n" "$2" >&2
      fail=1
    fi
  }

  deploy configs/qtile/config.py        "${HOME}/.config/qtile/config.py"        backup
  deploy configs/qtile/autostart.sh     "${HOME}/.config/qtile/autostart.sh"     nobackup
  deploy configs/picom/picom.conf       "${HOME}/.config/picom/picom.conf"       nobackup
  deploy configs/rofi/config.rasi       "${HOME}/.config/rofi/config.rasi"       nobackup
  deploy configs/dunst/dunstrc          "${HOME}/.config/dunst/dunstrc"          nobackup
  deploy configs/alacritty/alacritty.toml "${HOME}/.config/alacritty/alacritty.toml" nobackup
  chmod +x "${HOME}/.config/qtile/autostart.sh" 2>/dev/null

  # WaveTerm configs si présentes dans le repo
  if [[ -d "${repo}/configs/waveterm" ]]; then
    mkdir -p "${HOME}/.config/waveterm"
    cp "${repo}/configs/waveterm/"*.json "${HOME}/.config/waveterm/" 2>/dev/null \
      && printf "  \033[0;32m✓\033[0m  configs WaveTerm\n"
  fi

  # Police Mononoki NF (requise par la barre DTOS)
  local fdir="${HOME}/.local/share/fonts/MononokiNerdFont"
  if ! fc-list 2>/dev/null | grep -qi mononoki; then
    mkdir -p "${fdir}"
    curl -fLo /tmp/Mononoki.zip \
      https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Mononoki.zip 2>/dev/null \
      && unzip -o /tmp/Mononoki.zip -d "${fdir}" >/dev/null 2>&1 \
      && rm -f /tmp/Mononoki.zip && fc-cache -f >/dev/null 2>&1 \
      && printf "  \033[0;32m✓\033[0m  Mononoki Nerd Font\n" \
      || { printf "  \033[0;31m✗\033[0m  Mononoki NF échouée\n" >&2; fail=1; }
  else
    printf "  \033[0;32m✓\033[0m  Mononoki NF déjà présente\n"
  fi

  # Wallpapers DT
  [[ -d "${HOME}/Pictures/wallpapers" ]] \
    || git clone --depth 1 https://gitlab.com/dwt1/wallpapers.git \
         "${HOME}/Pictures/wallpapers" >/dev/null 2>&1 \
    && printf "  \033[0;32m✓\033[0m  Wallpapers DT\n" || true

  # VALIDATION avec erreur réelle affichée
  local verr
  verr=$(python3 -c "
import ast
with open('${HOME}/.config/qtile/config.py') as f:
    ast.parse(f.read())
print('VALID')" 2>&1)
  if [[ "${verr}" == "VALID" ]]; then
    printf "  \033[0;32m✓\033[0m  config.py : validé (ast.parse)\n"
  else
    printf "  \033[0;31m✗\033[0m  config.py INVALIDE :\n%s\n" "${verr}" >&2
    fail=1
  fi

  return ${fail}
}

log_section "Déploiement des configs (user: ${TARGET_USER})"
if [[ "${RUN_AS_ROOT}" == true ]]; then
  # Exporter la fonction et l'exécuter en tant que user
  export -f deploy_user_configs
  su -s /bin/bash -c "HOME=${TARGET_HOME} deploy_user_configs '${REPO_DIR}'" "${TARGET_USER}" \
    || die "Déploiement des configs ÉCHOUÉ — voir les ✗ ci-dessus. RIEN n'a été masqué."
else
  deploy_user_configs "${REPO_DIR}" \
    || die "Déploiement des configs ÉCHOUÉ — voir les ✗ ci-dessus."
fi

# Nettoyage du clone temporaire éventuel
[[ "${REPO_DIR}" == /tmp/fedoraqtile-setup-* ]] && rm -rf "${REPO_DIR}"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗\n"
printf "║  Qtile (X11, style DTOS) — DÉPLOIEMENT VÉRIFIÉ ✓         ║\n"
printf "╠══════════════════════════════════════════════════════════╣\n"
printf "║  sudo reboot → LightDM → session Qtile                   ║\n"
printf "║  Wallpaper : nitrogen ~/Pictures/wallpapers (1re fois)   ║\n"
printf "╠══════════════════════════════════════════════════════════╣\n"
printf "║  Super+Enter WaveTerm · Super+Space rofi · Super+B Brave ║\n"
printf "║  Super+1..9 groupes · Super+M/F/T max/full/float         ║\n"
printf "║  Super+Ctrl+R restart · aide complète : README du repo   ║\n"
printf "╚══════════════════════════════════════════════════════════╝${NC}\n"
exit 0
