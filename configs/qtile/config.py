# =============================================================================
# Qtile — style DTOS (Derek Taylor / DistroTube), adapté Swiss French
# Palette : Doom One | Barre : powerline arrows | Layouts : MonadTall/Max
# Clavier : ch-fr (QWERTZ suisse — chiffres directs, y/z évités dans les binds)
# =============================================================================

import os
import subprocess
from libqtile import bar, hook, layout, qtile
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from libqtile.widget import (
    Clock, CPU, CurrentLayout, GroupBox, Memory, Net, Prompt,
    PulseVolume, Spacer, Systray, TextBox, WindowName,
)

mod = "mod4"                      # Super
terminal = "waveterm"             # Terminal principal (fallback: alacritty)
browser = "brave-browser"         # brave-origin si présent (voir autostart)
launcher = "rofi -show drun"

# ── Palette Doom One (DTOS) ───────────────────────────────────────────────────
colors = {
    "bg":        "#282c34",
    "bg_alt":    "#1c1f24",
    "fg":        "#bbc2cf",
    "grey":      "#5b6268",
    "red":       "#ff6c6b",
    "green":     "#98be65",
    "yellow":    "#ecbe7b",
    "blue":      "#51afef",
    "magenta":   "#c678dd",
    "cyan":      "#46d9ff",
    "orange":    "#da8548",
}

# ── Keybinds (pensés QWERTZ suisse : pas de y/z, chiffres directs) ────────────
keys = [
    # Applications
    Key([mod], "Return", lazy.spawn(terminal), desc="Terminal"),
    Key([mod], "space",  lazy.spawn(launcher), desc="Launcher rofi"),
    Key([mod], "b",      lazy.spawn("sh -c 'exec $(command -v brave-origin || command -v brave-browser)'"), desc="Browser"),
    Key([mod], "e",      lazy.spawn("thunar"), desc="Fichiers"),
    Key([mod, "shift"], "Return", lazy.spawn("alacritty"), desc="Terminal léger"),

    # Fenêtres — navigation (HJKL + flèches)
    Key([mod], "h", lazy.layout.left(),  desc="Focus gauche"),
    Key([mod], "l", lazy.layout.right(), desc="Focus droite"),
    Key([mod], "j", lazy.layout.down(),  desc="Focus bas"),
    Key([mod], "k", lazy.layout.up(),    desc="Focus haut"),
    Key([mod], "Left",  lazy.layout.left()),
    Key([mod], "Right", lazy.layout.right()),
    Key([mod], "Down",  lazy.layout.down()),
    Key([mod], "Up",    lazy.layout.up()),

    # Fenêtres — déplacement
    Key([mod, "shift"], "h", lazy.layout.shuffle_left()),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right()),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down()),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up()),
    Key([mod, "shift"], "Left",  lazy.layout.shuffle_left()),
    Key([mod, "shift"], "Right", lazy.layout.shuffle_right()),
    Key([mod, "shift"], "Down",  lazy.layout.shuffle_down()),
    Key([mod, "shift"], "Up",    lazy.layout.shuffle_up()),

    # Fenêtres — taille
    Key([mod, "control"], "h", lazy.layout.grow_left()),
    Key([mod, "control"], "l", lazy.layout.grow_right()),
    Key([mod, "control"], "j", lazy.layout.grow_down()),
    Key([mod, "control"], "k", lazy.layout.grow_up()),
    Key([mod], "r", lazy.layout.normalize(), desc="Reset tailles"),
    Key([mod], "m", lazy.layout.maximize(),  desc="Maximize (toggle)"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Fullscreen"),
    Key([mod], "t", lazy.window.toggle_floating(),   desc="Float toggle"),

    # Fenêtres — gestion
    Key([mod], "q", lazy.window.kill(), desc="Fermer fenêtre"),
    Key([mod], "Tab", lazy.layout.next(), desc="Fenêtre suivante"),
    Key([mod, "shift"], "Tab", lazy.layout.previous()),

    # Layouts
    Key([mod], "n", lazy.next_layout(), desc="Layout suivant"),

    # Qtile
    Key([mod, "control"], "r", lazy.restart(),  desc="Restart qtile"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Quitter qtile"),

    # Audio (PipeWire/wpctl)
    Key([], "XF86AudioRaiseVolume", lazy.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")),
    Key([], "XF86AudioMute",        lazy.spawn("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")),
    Key([], "XF86AudioPlay",  lazy.spawn("playerctl play-pause")),
    Key([], "XF86AudioNext",  lazy.spawn("playerctl next")),
    Key([], "XF86AudioPrev",  lazy.spawn("playerctl previous")),

    # Luminosité
    Key([], "XF86MonBrightnessUp",   lazy.spawn("brightnessctl set 10%+")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("brightnessctl set 10%-")),

    # Screenshot
    Key([], "Print", lazy.spawn("flameshot gui"), desc="Screenshot"),

    # Verrouillage
    Key([mod, "mod1"], "l", lazy.spawn("xsecurelock"), desc="Lock"),
]

# ── Groupes 1-9 (chiffres directs sur clavier ch) ─────────────────────────────
group_labels = ["", "", "", "", "", "", "", "", ""]
groups = [Group(str(i + 1), label=group_labels[i]) for i in range(9)]

for g in groups:
    keys.extend([
        Key([mod], g.name, lazy.group[g.name].toscreen(), desc=f"Workspace {g.name}"),
        Key([mod, "shift"], g.name, lazy.window.togroup(g.name, switch_group=False),
            desc=f"Envoyer vers workspace {g.name}"),
    ])

# ── Layouts (gaps DTOS : margin 8, borders Doom One) ──────────────────────────
layout_theme = {
    "border_width": 2,
    "margin": 8,
    "border_focus": colors["blue"],
    "border_normal": colors["bg_alt"],
}

layouts = [
    layout.MonadTall(**layout_theme),
    layout.Max(**layout_theme),
    layout.MonadWide(**layout_theme),
    layout.Floating(**layout_theme),
]

# ── Widgets : barre powerline arrows (signature DTOS) ─────────────────────────
widget_defaults = dict(
    font="Mononoki Nerd Font Bold",
    fontsize=13,
    padding=4,
    background=colors["bg"],
    foreground=colors["fg"],
)
extension_defaults = widget_defaults.copy()

def arrow(bg, fg):
    """Flèche powerline (style DTOS)."""
    return TextBox(text="", fontsize=28, padding=0,
                   background=bg, foreground=fg)

screens = [
    Screen(
        top=bar.Bar(
            [
                TextBox(text=" ", fontsize=16, padding=6,
                        foreground=colors["blue"],
                        mouse_callbacks={"Button1": lazy.spawn(launcher)}),
                GroupBox(
                    fontsize=14, margin_y=3, margin_x=2,
                    padding_y=4, padding_x=4, borderwidth=3,
                    active=colors["fg"], inactive=colors["grey"],
                    rounded=False,
                    highlight_method="line",
                    highlight_color=[colors["bg_alt"], colors["bg_alt"]],
                    this_current_screen_border=colors["blue"],
                    urgent_border=colors["red"],
                ),
                TextBox(text="|", foreground=colors["grey"]),
                CurrentLayout(foreground=colors["magenta"]),
                TextBox(text="|", foreground=colors["grey"]),
                WindowName(foreground=colors["cyan"], max_chars=50),
                Spacer(),

                arrow(colors["bg"], colors["bg_alt"]),
                CPU(background=colors["bg_alt"], foreground=colors["blue"],
                    format=" {load_percent}%", update_interval=3),
                arrow(colors["bg_alt"], colors["bg"]),
                Memory(background=colors["bg"], foreground=colors["green"],
                       format=" {MemUsed:.0f}{mm}", measure_mem="G",
                       update_interval=5),
                arrow(colors["bg"], colors["bg_alt"]),
                Net(background=colors["bg_alt"], foreground=colors["yellow"],
                    format=" {down:6.2f}{down_suffix}", update_interval=3),
                arrow(colors["bg_alt"], colors["bg"]),
                PulseVolume(background=colors["bg"], foreground=colors["orange"],
                            fmt=" {}"),
                arrow(colors["bg"], colors["bg_alt"]),
                Clock(background=colors["bg_alt"], foreground=colors["magenta"],
                      format=" %H:%M  %a %d.%m"),
                arrow(colors["bg_alt"], colors["bg"]),
                Systray(background=colors["bg"], icon_size=16, padding=6),
                Spacer(length=6),
            ],
            26,
            background=colors["bg"],
            margin=[6, 8, 0, 8],   # gaps autour de la barre (DTOS)
        ),
    ),
]

# ── Souris ────────────────────────────────────────────────────────────────────
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(),
         start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

# ── Règles de flottement ──────────────────────────────────────────────────────
floating_layout = layout.Floating(
    **layout_theme,
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="pavucontrol"),
        Match(wm_class="nitrogen"),
        Match(wm_class="Wfica"),          # Citrix
        Match(title="Picture-in-Picture"),
    ],
)

# ── Divers ────────────────────────────────────────────────────────────────────
dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True
wmname = "LG3D"   # compat Java

# ── Autostart ─────────────────────────────────────────────────────────────────
@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser("~/.config/qtile/autostart.sh")
    subprocess.Popen([home])
