# fedoraqtile

Fedora 44 minimal + **qtile (X11)** — look **DTOS** (Doom One) — clavier **Swiss French (ch-fr)**  
Esprit [Chris Titus — Switch from Arch to Fedora](https://christitus.com/switch-from-arch-to-fedora/) : base moderne et prévisible, SELinux enforcing + firewalld **conservés**.  
Look & feel : [DTOS / dotfiles dwt1](https://gitlab.com/dwt1/dotfiles).

---

## Pourquoi qtile (et pas dwm)

| | qtile | dwm |
|---|---|---|
| Installation | `dnf install qtile` | compilation C + patches |
| Configuration | Python (copie de fichier) | recompilation à chaque changement |
| Déploiement scripté | ✅ trivial | ⚠ fragile |
| Référence DTOS | config qtile DT dispo | patches à maintenir |

**X11 uniquement** — compatibilité maximale (Citrix, Shadow, apps legacy).

---

## Structure

```
fedoraqtile/
├── kickstart/
│   └── ks.cfg                 # Install Fedora automatisée (équivalent preseed)
├── scripts/
│   ├── post-install.sh        # Stack système (apps, shell, locale) — via kickstart ou manuel
│   ├── qtile-setup.sh         # Qtile X11 + look DTOS — post-reboot, en user
│   └── virt-setup.sh          # QEMU/KVM + virt-manager (dnf)
├── configs/
│   ├── qtile/config.py        # Doom One, barre powerline, keybinds ch-fr
│   ├── qtile/autostart.sh     # setxkbmap ch fr, picom, nitrogen, dunst
│   ├── picom/ · rofi/ · dunst/ · alacritty/
│   └── waveterm/              # Ollama homelab, Dracula, connexion SSH
└── README.md
```

---

## Installation

### Option A — Automatisée (kickstart)

```bash
# 1. Hash du mot de passe
echo "tonpass" | openssl passwd -6 -stdin
# → remplacer dans kickstart/ks.cfg

# 2. Booter l'ISO Fedora Everything avec le paramètre kernel :
#    inst.ks=https://raw.githubusercontent.com/tonybeyond/fedoraqtile/main/kickstart/ks.cfg
#    (au menu GRUB : touche 'e', ajouter à la ligne linux, Ctrl+X)
```
L'installation est entièrement automatique (partitionnement Btrfs, user deby, minimal) et lance `post-install.sh` en fin d'install.

### Option B — Manuelle (5 clics)

1. ISO Everything → Anaconda → Software Selection → **Minimal Install**
2. Reboot, login TTY :
```bash
sudo dnf install -y git
sudo git clone https://github.com/tonybeyond/fedoraqtile.git /opt/fedoraqtile
sudo bash /opt/fedoraqtile/scripts/post-install.sh
```

### Ensuite (les deux options)

`qtile-setup.sh` est **enchaîné automatiquement** par post-install — il ne reste que :

```bash
sudo reboot   # → LightDM → session Qtile
```

Optionnel : `sudo bash /opt/fedoraqtile/scripts/virt-setup.sh` (KVM).

### Réparation / machine existante

`qtile-setup.sh` est auto-suffisant (localise le repo ou le clone lui-même, déploiement **vérifié octet par octet**, échec dur si problème) :

```bash
curl -fsSL https://raw.githubusercontent.com/tonybeyond/fedoraqtile/main/scripts/qtile-setup.sh | bash
```

---

## Ce qui est installé

| Bloc | Contenu |
|---|---|
| **post-install.sh** | RPM Fusion + codecs, locale en_US/fr_CH, Brave Origin, WaveTerm (+configs Ollama), VS Code, Zed, Claude Code CLI, Proton Mail, Shadow (AppImage+uinput), Distrobox+Podman, zsh+OMZ+Starship, Hack NF, Citrix (rpm officiel si présent dans ~/Downloads) |
| **qtile-setup.sh** | qtile, LightDM, picom, rofi, dunst, nitrogen, xsecurelock, alacritty, Mononoki NF, configs DTOS, session X11, clavier ch-fr persistant |
| **virt-setup.sh** | @virtualization, libvirtd, polkit sans sudo, réseau NAT, nested KVM |

**Note Citrix** : contrairement à Debian Trixie, le rpm Citrix officiel supporte RHEL/Fedora — installation directe sans hack webkit.
**Note Claude Desktop** : le build communautaire (aaddrick) est Debian-only — Claude Code CLI officiel installé à la place.

---

## Keybinds (pensés QWERTZ suisse — chiffres directs, pas de y/z)

| Raccourci | Action |
|---|---|
| `Super+Enter` / `Super+Shift+Enter` | WaveTerm / Alacritty |
| `Super+Space` | Rofi |
| `Super+B` / `Super+E` | Brave Origin / Thunar |
| `Super+HJKL` ou flèches | Focus |
| `+Shift` / `+Ctrl` | Déplacer / Redimensionner |
| `Super+1..9` (`+Shift`) | Workspace (envoyer vers) |
| `Super+Q` | Fermer |
| `Super+M` / `Super+F` / `Super+T` | Maximize / Fullscreen / Float |
| `Super+N` | Layout suivant |
| `Super+R` | Reset tailles |
| `Super+Ctrl+R` | Restart qtile |
| `Super+Alt+L` | Lock (xsecurelock) |
| `Print` | Flameshot |

## Personnalisation

- Wallpaper : `nitrogen` → `~/Pictures/wallpapers` (collection DT)
- Couleurs : `~/.config/qtile/config.py` → dict `colors` → `Super+Ctrl+R`
- Thème GTK : `lxappearance` (Papirus-Dark)
