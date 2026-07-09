#!/usr/bin/env bash
# =============================================================================
# post-install.sh — Stack système Fedora 44 minimal
# =============================================================================
# Appelé par kickstart (%post) ou manuellement :
#   sudo bash /opt/fedoraqtile/scripts/post-install.sh
#
# Post-reboot (manuels) :
#   (qtile-setup.sh est enchaîné automatiquement — plus d'étape manuelle)
#   sudo bash /opt/fedoraqtile/scripts/virt-setup.sh
# =============================================================================

set -uo pipefail   # PAS de -e : best-effort

TARGET_USER="${SUDO_USER:-fedo}"
TARGET_HOME=$(getent passwd "${TARGET_USER}" 2>/dev/null | cut -d: -f6 || echo "/home/${TARGET_USER}")
REPO_DIR="/opt/fedoraqtile"
LOG_FILE="/var/log/fedoraqtile-setup.log"
ERROR_COUNT=0

log_info()    { echo "[$(date +'%H:%M:%S')] ·     $*" | tee -a "${LOG_FILE}"; }
log_ok()      { echo "[$(date +'%H:%M:%S')] ✓     $*" | tee -a "${LOG_FILE}"; }
log_error()   { echo "[$(date +'%H:%M:%S')] ✗     $*" | tee -a "${LOG_FILE}" >&2; ((ERROR_COUNT++)) || true; }
log_section() { echo "" | tee -a "${LOG_FILE}"; echo "[$(date +'%H:%M:%S')] ════ $* ════" | tee -a "${LOG_FILE}"; }

is_installed() { rpm -q "$1" &>/dev/null; }
dnf_install() {
  for pkg in "$@"; do
    is_installed "$pkg" && { log_ok "présent : $pkg"; continue; }
    dnf install -y "$pkg" &>>"${LOG_FILE}" \
      && log_ok "dnf : $pkg" || log_error "dnf : $pkg FAILED"
  done
}
as_user() { su -s /bin/bash -c "HOME=${TARGET_HOME} $*" "${TARGET_USER}"; }

[[ $EUID -eq 0 ]] || { echo "Requiert root (sudo)."; exit 1; }
mkdir -p "$(dirname "${LOG_FILE}")"
log_info "=== fedoraqtile post-install — $(date) ==="
log_info "Utilisateur : ${TARGET_USER}"

# ── 1. Mise à jour + RPM Fusion ───────────────────────────────────────────────
log_section "Mise à jour + RPM Fusion"
dnf upgrade -y --refresh &>>"${LOG_FILE}" || log_error "dnf upgrade"

FEDORA_VER=$(rpm -E %fedora)
dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
  &>>"${LOG_FILE}" && log_ok "RPM Fusion free + nonfree" || log_error "RPM Fusion"

# Codecs multimédia (ffmpeg complet depuis RPM Fusion)
dnf swap -y ffmpeg-free ffmpeg --allowerasing &>>"${LOG_FILE}" \
  && log_ok "ffmpeg complet (RPM Fusion)" || true

# ── 2. Locale : en_US interface + fr_CH formats ───────────────────────────────
log_section "Locale"
dnf_install glibc-langpack-en glibc-langpack-fr
cat > /etc/locale.conf << 'LOCALE'
LANG=en_US.UTF-8
LC_TIME=fr_CH.UTF-8
LC_NUMERIC=fr_CH.UTF-8
LC_MONETARY=fr_CH.UTF-8
LC_PAPER=fr_CH.UTF-8
LC_MEASUREMENT=fr_CH.UTF-8
LOCALE
localectl set-keymap ch-fr 2>/dev/null || true
localectl set-x11-keymap ch pc105 fr 2>/dev/null || true
log_ok "Locale en_US + formats fr_CH + clavier ch/fr"

# ── 3. Outils de base ─────────────────────────────────────────────────────────
log_section "Outils de base"
dnf_install \
  git curl wget unzip gcc make \
  zsh fzf eza bat btop fastfetch \
  xclip flameshot \
  tesseract tesseract-langpack-fra tesseract-langpack-eng \
  NetworkManager-tui bash-completion

# ── 4. Brave Origin ───────────────────────────────────────────────────────────
log_section "Brave Origin"
if ! command -v brave-origin &>/dev/null; then
  dnf install -y dnf-plugins-core &>>"${LOG_FILE}" || true
  dnf config-manager addrepo \
    --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
    &>>"${LOG_FILE}" \
    || dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo &>>"${LOG_FILE}" || true
  rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc &>>"${LOG_FILE}" || true
  if dnf install -y brave-origin &>>"${LOG_FILE}"; then
    log_ok "Brave Origin installé"
  elif dnf install -y brave-browser &>>"${LOG_FILE}"; then
    log_ok "Brave standard (brave-origin absent du repo rpm — fallback)"
  else
    log_error "Brave install FAILED"
  fi
else
  log_ok "Brave Origin déjà présent"
fi

# ── 5. WaveTerm ───────────────────────────────────────────────────────────────
log_section "WaveTerm"
if ! command -v waveterm &>/dev/null; then
  WT_VER=$(curl -s https://api.github.com/repos/wavetermdev/waveterm/releases/latest \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))" 2>/dev/null \
    || echo "0.14.5")
  WT_RPM="/tmp/waveterm.rpm"
  if curl -fL --connect-timeout 30 -o "${WT_RPM}" \
      "https://github.com/wavetermdev/waveterm/releases/download/v${WT_VER}/waveterm-linux-x86_64-${WT_VER}.rpm" 2>>"${LOG_FILE}"; then
    dnf install -y "${WT_RPM}" &>>"${LOG_FILE}" \
      && log_ok "WaveTerm v${WT_VER}" || log_error "WaveTerm rpm FAILED"
    rm -f "${WT_RPM}"
  else
    log_error "WaveTerm download FAILED — https://www.waveterm.dev/download"
  fi
fi
WAVETERM_CONF="${TARGET_HOME}/.config/waveterm"
if [[ -d "${REPO_DIR}/configs/waveterm" ]]; then
  mkdir -p "${WAVETERM_CONF}"
  cp "${REPO_DIR}/configs/waveterm/"*.json "${WAVETERM_CONF}/" 2>/dev/null || true
  chown -R "${TARGET_USER}:${TARGET_USER}" "${WAVETERM_CONF}"
  log_ok "Config WaveTerm déployée"
fi

# ── 6. VS Code (repo Microsoft) ───────────────────────────────────────────────
log_section "VS Code"
if ! command -v code &>/dev/null; then
  rpm --import https://packages.microsoft.com/keys/microsoft.asc &>>"${LOG_FILE}" || true
  cat > /etc/yum.repos.d/vscode.repo << 'VSCODE'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
VSCODE
  dnf install -y code &>>"${LOG_FILE}" && log_ok "VS Code" || log_error "VS Code FAILED"
else
  log_ok "VS Code déjà présent"
fi

# ── 7. Zed + Claude Code (installeurs officiels, en user) ────────────────────
log_section "Zed + Claude Code"
as_user "curl -fsSL https://zed.dev/install.sh | sh" &>>"${LOG_FILE}" \
  && log_ok "Zed" || log_error "Zed install"
as_user "curl -fsSL https://claude.ai/install.sh | bash" &>>"${LOG_FILE}" \
  && log_ok "Claude Code CLI" || log_error "Claude Code install"
# Note : Claude Desktop (build aaddrick) est Debian-only — pas de rpm fiable.
log_info "Claude Desktop : pas de build rpm communautaire fiable — utiliser Claude Code CLI"

# ── 8. Proton Mail ────────────────────────────────────────────────────────────
log_section "Proton Mail"
if ! is_installed proton-mail; then
  PM_RPM="/tmp/protonmail.rpm"
  if curl -fL --connect-timeout 15 -o "${PM_RPM}" \
      "https://proton.me/download/mail/linux/ProtonMail-desktop-beta.rpm" 2>>"${LOG_FILE}"; then
    dnf install -y "${PM_RPM}" &>>"${LOG_FILE}" \
      && log_ok "Proton Mail (⚠ premium après 14j)" || log_error "Proton Mail rpm"
    rm -f "${PM_RPM}"
  else
    log_error "Proton Mail download — proton.me/mail/download"
  fi
fi

# ── 9. Shadow PC (AppImage — pas de rpm officiel) ────────────────────────────
log_section "Shadow PC"
SHADOW_DIR="${TARGET_HOME}/.local/bin"
if [[ ! -f "${SHADOW_DIR}/Shadow.AppImage" ]]; then
  mkdir -p "${SHADOW_DIR}"
  if curl -fL --connect-timeout 30 -o "${SHADOW_DIR}/Shadow.AppImage" \
      "https://update.shadow.tech/launcher/prod/linux/ubuntu_18.04/Shadow.AppImage" 2>>"${LOG_FILE}"; then
    chmod +x "${SHADOW_DIR}/Shadow.AppImage"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${SHADOW_DIR}"
    # uinput pour Wayland/X11 capture
    usermod -aG input "${TARGET_USER}" 2>/dev/null || true
    echo "uinput" > /etc/modules-load.d/uinput.conf
    groupadd -f shadow-input
    echo 'KERNEL=="uinput", MODE="0660", GROUP="shadow-input"' \
      > /etc/udev/rules.d/65-shadow-client.rules
    usermod -aG shadow-input "${TARGET_USER}" 2>/dev/null || true
    log_ok "Shadow AppImage → ~/.local/bin (groupes effectifs après reboot)"
  else
    log_error "Shadow download FAILED"
  fi
fi

# ── 10. Distrobox + Podman ────────────────────────────────────────────────────
log_section "Distrobox + Podman"
dnf_install podman distrobox

# ── 11. Zsh + Oh My Zsh + Starship + Hack Nerd Font ──────────────────────────
log_section "Shell (zsh + starship + fonts)"
if [[ ! -d "${TARGET_HOME}/.oh-my-zsh" ]]; then
  as_user "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended" &>>"${LOG_FILE}" \
    && log_ok "Oh My Zsh" || log_error "Oh My Zsh"
fi
command -v starship &>/dev/null \
  || { curl -sS https://starship.rs/install.sh | sh -s -- --yes &>>"${LOG_FILE}" && log_ok "Starship"; }

FONT_DIR="${TARGET_HOME}/.local/share/fonts/HackNerdFont"
if [[ ! -d "${FONT_DIR}" ]]; then
  mkdir -p "${FONT_DIR}"
  curl -fLo /tmp/Hack.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip &>>"${LOG_FILE}" \
    && unzip -o /tmp/Hack.zip -d "${FONT_DIR}" &>>"${LOG_FILE}" \
    && rm /tmp/Hack.zip && fc-cache -f &>/dev/null \
    && chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.local" \
    && log_ok "Hack Nerd Font" || log_error "Hack Nerd Font"
fi
chsh -s "$(which zsh)" "${TARGET_USER}" 2>/dev/null && log_ok "zsh par défaut" || true

# ── 12. Citrix Workspace (rpm officiel supporté sur Fedora/RHEL) ─────────────
log_section "Citrix Workspace"
CITRIX_RPM=$(find "${TARGET_HOME}/Downloads" /root/Downloads -maxdepth 1 \
  -name "ICAClient*.rpm" -o -name "icaclient*.rpm" 2>/dev/null | sort -V | tail -n1)
if [[ -n "${CITRIX_RPM}" ]]; then
  dnf install -y "${CITRIX_RPM}" &>>"${LOG_FILE}" \
    && log_ok "Citrix installé ($(basename "${CITRIX_RPM}"))" \
    || log_error "Citrix rpm FAILED"
  # Store SSL
  CERTS="/opt/Citrix/ICAClient/keystore/cacerts"
  [[ -d "${CERTS}" ]] && {
    cp /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem "${CERTS}/" 2>/dev/null || true
    /opt/Citrix/ICAClient/util/ctx_rehash 2>/dev/null || true
  }
else
  log_info "Citrix : placer ICAClient rpm dans ~/Downloads puis relancer (le rpm Citrix supporte RHEL/Fedora)"
fi

# ── Enchaînement automatique : qtile-setup ───────────────────────────────────
# Plus d'étape manuelle : le setup qtile (paquets + configs style DTOS) est
# lancé directement ici. Il gère lui-même la bascule root→user pour les configs.
log_section "Enchaînement : qtile-setup.sh"
if [[ -f "${REPO_DIR}/scripts/qtile-setup.sh" ]]; then
  bash "${REPO_DIR}/scripts/qtile-setup.sh" \
    && log_ok "qtile-setup terminé" \
    || log_error "qtile-setup a échoué — relancer : sudo bash ${REPO_DIR}/scripts/qtile-setup.sh"
else
  log_warn "qtile-setup.sh introuvable dans ${REPO_DIR}/scripts/"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  fedoraqtile post-install — TERMINÉ                        ║"
printf "║  Erreurs : %-3d                                             ║\n" "${ERROR_COUNT}"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Post-reboot :                                             ║"
echo "║  qtile : configuré automatiquement ✓                       ║"
echo "║  2. sudo bash /opt/fedoraqtile/scripts/virt-setup.sh       ║"
echo "╚════════════════════════════════════════════════════════════╝"
exit 0
