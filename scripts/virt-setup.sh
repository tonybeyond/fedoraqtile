#!/usr/bin/env bash
# =============================================================================
# virt-setup.sh — Stack QEMU/KVM + virt-manager (Fedora)
# =============================================================================
# Version Fedora du virt-setup (dnf, groupe @virtualization).
# L'utilisateur gère les VMs SANS sudo : groupes libvirt+kvm, règle polkit,
# LIBVIRT_DEFAULT_URI=qemu:///system.
#
#   sudo bash /opt/fedoraqtile/scripts/virt-setup.sh
# =============================================================================

set -uo pipefail

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
[[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]] \
  || { echo "Lancer via sudo depuis un compte utilisateur."; exit 1; }
TARGET_HOME=$(getent passwd "${TARGET_USER}" | cut -d: -f6)
LOG="/var/log/virt-setup.log"
ERROR_COUNT=0

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
log_info()    { printf "${BLUE}  ·${NC}  %s\n" "$*" | tee -a "${LOG}"; }
log_ok()      { printf "${GREEN}  ✓${NC}  %s\n" "$*" | tee -a "${LOG}"; }
log_warn()    { printf "${YELLOW}  ⚠${NC}  %s\n" "$*" | tee -a "${LOG}"; }
log_error()   { printf "${RED}  ✗${NC}  %s\n" "$*" | tee -a "${LOG}" >&2; ((ERROR_COUNT++)) || true; }
log_section() { printf "\n${BOLD}── %s ──${NC}\n" "$*" | tee -a "${LOG}"; }

[[ $EUID -eq 0 ]] || exec sudo "$0" "$@"
mkdir -p "$(dirname "${LOG}")"
log_info "=== virt-setup (Fedora) — $(date) ==="

# ── 1. Support matériel ───────────────────────────────────────────────────────
log_section "Support matériel KVM"
FLAG=$(grep -oEm1 '(vmx|svm)' /proc/cpuinfo || true)
case "${FLAG}" in
  vmx) log_ok "Intel VT-x détecté" ;;
  svm) log_ok "AMD-V détecté" ;;
  *)   log_warn "VT-x/AMD-V non détecté — activer dans le BIOS/UEFI" ;;
esac
[[ -e /dev/kvm ]] && log_ok "/dev/kvm présent" || log_warn "/dev/kvm absent"

# ── 2. Installation (groupe Fedora @virtualization) ───────────────────────────
log_section "Installation"
dnf group install -y --with-optional virtualization &>>"${LOG}" \
  && log_ok "Groupe @virtualization (qemu-kvm, libvirt, virt-manager...)" \
  || {
    # Fallback : paquets individuels
    for pkg in qemu-kvm libvirt libvirt-daemon-config-network virt-manager \
               virt-install virt-viewer edk2-ovmf guestfs-tools bridge-utils; do
      rpm -q "$pkg" &>/dev/null || dnf install -y "$pkg" &>>"${LOG}" \
        && log_ok "dnf : $pkg" || log_warn "dnf : $pkg"
    done
  }

# ── 3. Service libvirtd ───────────────────────────────────────────────────────
log_section "Service libvirtd"
systemctl enable --now libvirtd &>>"${LOG}" && log_ok "libvirtd actif" || log_error "libvirtd"
systemctl enable --now virtlogd &>>"${LOG}" || true

# ── 4. Groupes ────────────────────────────────────────────────────────────────
log_section "Groupes ${TARGET_USER}"
for grp in libvirt kvm; do
  getent group "${grp}" &>/dev/null || continue
  id -nG "${TARGET_USER}" | grep -qw "${grp}" \
    && log_ok "déjà membre : ${grp}" \
    || { usermod -aG "${grp}" "${TARGET_USER}" && log_ok "ajouté : ${grp}"; }
done

# ── 5. Règle polkit — VMs sans mot de passe ───────────────────────────────────
log_section "polkit"
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-libvirt.rules << 'POLKIT'
// Groupe libvirt : gestion des VMs sans authentification
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
POLKIT
log_ok "Règle polkit : groupe libvirt → gestion VMs sans sudo"

# ── 6. Réseau default + storage pool ──────────────────────────────────────────
log_section "Réseau + storage"
virsh --connect qemu:///system net-autostart default &>>"${LOG}" || true
virsh --connect qemu:///system net-start default &>>"${LOG}" || true
log_ok "Réseau NAT default (virbr0)"

mkdir -p /var/lib/libvirt/images
virsh --connect qemu:///system pool-list --all 2>/dev/null | grep -q default || {
  virsh --connect qemu:///system pool-define-as default dir --target /var/lib/libvirt/images &>>"${LOG}"
  virsh --connect qemu:///system pool-start default &>>"${LOG}"
  virsh --connect qemu:///system pool-autostart default &>>"${LOG}"
}
log_ok "Storage pool default → /var/lib/libvirt/images"

# ── 7. Nested KVM ─────────────────────────────────────────────────────────────
log_section "Nested KVM"
if [[ -f /sys/module/kvm_intel/parameters/nested ]]; then
  echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
  log_ok "Nested Intel activé (effectif au reboot)"
elif [[ -f /sys/module/kvm_amd/parameters/nested ]]; then
  echo "options kvm_amd nested=1" > /etc/modprobe.d/kvm-nested.conf
  log_ok "Nested AMD activé (effectif au reboot)"
fi

# ── 8. Env utilisateur ────────────────────────────────────────────────────────
log_section "Environnement"
for rc in "${TARGET_HOME}/.bashrc" "${TARGET_HOME}/.zshrc"; do
  [[ -f "${rc}" ]] || continue
  grep -q LIBVIRT_DEFAULT_URI "${rc}" || {
    printf '\n# KVM / libvirt\nexport LIBVIRT_DEFAULT_URI=qemu:///system\n' >> "${rc}"
    chown "${TARGET_USER}:${TARGET_USER}" "${rc}"
    log_ok "LIBVIRT_DEFAULT_URI → $(basename ${rc})"
  }
done

echo ""
printf "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗\n"
printf "║  QEMU/KVM (Fedora) installé ✓                      ║\n"
printf "║  ⚠ Déconnexion/reconnexion requise (groupes)       ║\n"
printf "║  Puis : virt-manager (sans sudo)                   ║\n"
printf "╚════════════════════════════════════════════════════╝${NC}\n"
exit 0
