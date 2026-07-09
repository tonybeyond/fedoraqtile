#!/usr/bin/env bash
# =============================================================================
# qtile-setup.sh — Qtile (X11) + look DTOS sur Fedora
# =============================================================================
# Installe qtile depuis les repos Fedora (session X11), LightDM, et déploie
# la config style DTOS (Doom One, barre widgets, rofi, picom).
# Clavier Swiss French (ch/fr) forcé dans l'autostart X11.
#
# Lancer SANS sudo :
#   bash /opt/fedoraqtile/scripts/qtile-setup.sh
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log_info()    { printf "${BLUE}  ·${NC}  %s\n" "$*"; }
log_ok()      { printf "${GREEN}  ✓${NC}  %s\n" "$*"; }
log_warn()    { printf "${YELLOW}  ⚠${NC}  %s\n" "$*"; }
log_error()   { printf "${RED}  ✗${NC}  %s\n" "$*" >&2; }
log_section() { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

[[ $EUID -ne 0 ]] || { echo "Lancer SANS sudo."; exit 1; }
REPO_DIR="/opt/fedoraqtile"

# ── 1. Paquets (qtile X11 + écosystème DTOS) ─────────────────────────────────
log_section "Installation qtile + écosystème"
sudo dnf install -y \
  qtile python3-dbus-next \
  xorg-x11-server-Xorg xorg-x11-xinit xrandr xsetroot setxkbmap \
  lightdm lightdm-gtk-greeter \
  picom rofi nitrogen \
  thunar thunar-volman gvfs \
  xsecurelock xkill alacritty \
  network-manager-applet pavucontrol playerctl brightnessctl \
  flameshot dunst \
  google-noto-emoji-color-fonts \
  || log_warn "Certains paquets ont échoué — vérifier dnf"

log_ok "Paquets installés"

# ── 2. Configs (qtile, picom, rofi) ──────────────────────────────────────────
log_section "Déploiement des configs (style DTOS)"
QTILE_DIR="${HOME}/.config/qtile"
PICOM_DIR="${HOME}/.config/picom"
ROFI_DIR="${HOME}/.config/rofi"
mkdir -p "${QTILE_DIR}" "${PICOM_DIR}" "${ROFI_DIR}"

# Backup
[[ -f "${QTILE_DIR}/config.py" ]] && \
  cp "${QTILE_DIR}/config.py" "${QTILE_DIR}/config.py.bak-$(date +%Y%m%d-%H%M%S)"

cp "${REPO_DIR}/configs/qtile/config.py"     "${QTILE_DIR}/config.py"
cp "${REPO_DIR}/configs/qtile/autostart.sh"  "${QTILE_DIR}/autostart.sh"
chmod +x "${QTILE_DIR}/autostart.sh"
cp "${REPO_DIR}/configs/picom/picom.conf"    "${PICOM_DIR}/picom.conf"
cp "${REPO_DIR}/configs/rofi/config.rasi"    "${ROFI_DIR}/config.rasi"
mkdir -p "${HOME}/.config/dunst" "${HOME}/.config/alacritty"
cp "${REPO_DIR}/configs/dunst/dunstrc"           "${HOME}/.config/dunst/dunstrc" 2>/dev/null || true
cp "${REPO_DIR}/configs/alacritty/alacritty.toml" "${HOME}/.config/alacritty/alacritty.toml" 2>/dev/null || true
log_ok "Configs qtile + picom + rofi + dunst + alacritty déployées"

# Police Mononoki Nerd Font (DTOS) — requise par config.py et la barre
FONT_DIR="${HOME}/.local/share/fonts/MononokiNerdFont"
if [[ ! -d "${FONT_DIR}" ]]; then
  mkdir -p "${FONT_DIR}"
  curl -fLo /tmp/Mononoki.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Mononoki.zip 2>/dev/null \
    && unzip -o /tmp/Mononoki.zip -d "${FONT_DIR}" >/dev/null \
    && rm -f /tmp/Mononoki.zip && fc-cache -f >/dev/null \
    && log_ok "Mononoki Nerd Font (DTOS)" || log_warn "Mononoki NF échoué"
fi

# ── 3. Session X11 + LightDM ──────────────────────────────────────────────────
log_section "Session graphique (LightDM + qtile X11)"
# Le paquet Fedora qtile fournit /usr/share/xsessions/qtile.desktop
if [[ -f /usr/share/xsessions/qtile.desktop ]]; then
  log_ok "Session qtile (X11) disponible dans LightDM"
else
  log_warn "qtile.desktop absent — création manuelle"
  sudo tee /usr/share/xsessions/qtile.desktop > /dev/null << 'DESKTOP'
[Desktop Entry]
Name=Qtile
Comment=Qtile Tiling Window Manager
Exec=qtile start
Type=Application
DESKTOP
fi

sudo systemctl enable lightdm 2>/dev/null && log_ok "LightDM activé" || true
sudo systemctl set-default graphical.target 2>/dev/null \
  && log_ok "Boot en mode graphique" || true

# ── 4. Clavier ch/fr — toutes les couches ─────────────────────────────────────
log_section "Clavier Swiss French"
sudo localectl set-x11-keymap ch pc105 fr 2>/dev/null \
  && log_ok "X11 keymap : ch (fr) — persistant" || true
# L'autostart.sh de qtile fait aussi setxkbmap ch fr à chaque session (ceinture+bretelles)
log_ok "setxkbmap ch fr dans l'autostart qtile"

# ── 5. Validation config qtile ────────────────────────────────────────────────
log_section "Validation"
if python3 -c "
import sys
sys.path.insert(0, '${QTILE_DIR}')
import ast
with open('${QTILE_DIR}/config.py') as f:
    ast.parse(f.read())
" 2>/dev/null; then
  log_ok "config.py : syntaxe Python valide"
else
  log_error "config.py : erreur de syntaxe"
fi

command -v qtile &>/dev/null \
  && log_ok "qtile $(qtile --version 2>/dev/null | head -1)" \
  || log_error "qtile introuvable"

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗\n"
printf "║  Qtile (X11, style DTOS) installé ✓                      ║\n"
printf "╠══════════════════════════════════════════════════════════╣\n"
printf "║  sudo reboot → LightDM → session Qtile                   ║\n"
printf "╠══════════════════════════════════════════════════════════╣\n"
printf "║  Keybinds (clavier ch/fr, zéro AltGr) :                  ║\n"
printf "║  Super+Enter      WaveTerm                               ║\n"
printf "║  Super+Space      rofi (launcher)                        ║\n"
printf "║  Super+B          Brave                                  ║\n"
printf "║  Super+E          Thunar                                 ║\n"
printf "║  Super+HJKL/↑↓←→  Focus                                  ║\n"
printf "║  Super+Shift+…    Déplacer fenêtre                       ║\n"
printf "║  Super+Ctrl+…     Redimensionner                         ║\n"
printf "║  Super+1..9       Groupes (dev www sys doc …)            ║\n"
printf "║  Super+N          Layout suivant (MonadTall→Max→Wide)    ║\n"
printf "║  Super+Tab        Fenêtre suivante                       ║\n"
printf "║  Super+F/M/T      Fullscreen / Maximize / Float          ║\n"
printf "║  Super+Q          Fermer fenêtre                         ║\n"
printf "║  Super+Ctrl+R     Restart qtile (recharge config)        ║\n"
printf "║  Super+Alt+L      Lock (xsecurelock)                     ║\n"
printf "║  Print            Screenshot (flameshot)                 ║\n"
printf "╚══════════════════════════════════════════════════════════╝${NC}\n"
exit 0
