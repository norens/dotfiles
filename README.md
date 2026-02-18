# dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

![macOS](https://img.shields.io/badge/macOS-Sequoia-black?logo=apple)
![chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)

## What's Inside

**Shell** — zsh + [starship](https://starship.rs) prompt (Gruvbox Dark) + tmux with vi-keys

**Terminal** — [Ghostty](https://ghostty.org) with TokyoNight Storm theme and CRT shaders

**Window Management** — [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling WM (`super` = ctrl+alt+cmd)

**Status Bar** — [SketchyBar](https://github.com/FelixKratz/SketchyBar) with Lua config (workspaces, media, system widgets)

**Keyboard** — [Karabiner-Elements](https://karabiner-elements.pqrs.org) via [Goku](https://github.com/yqrashawn/GokuRakuJoudo)

**Git** — [lazygit](https://github.com/jesseduffield/lazygit) (Catppuccin theme), global config, aliases

**Packages** — Brewfile with all formulae, casks, and Mac App Store apps

**IDE** — Custom JetBrains keymap shared across all IDEs

## Structure

```
~/.zshrc                        # shell config, plugins, PATH
~/.zsh_aliases                  # aliases (cz, lg, etc.)
~/.tmux.conf                    # tmux + TPM
~/.gitconfig                    # git user/aliases
~/.config/
├── aerospace/aerospace.toml    # tiling WM
├── ghostty/
│   ├── config                  # terminal settings
│   └── shaders/                # CRT, bloom, cursor effects
├── starship.toml               # prompt theme
├── sketchybar/                 # status bar (Lua)
├── goku/karabiner.edn          # keyboard remaps (source of truth)
├── karabiner/karabiner.json    # generated — do not edit
├── lazygit/config.yml          # git TUI
├── brewfile/Brewfile           # all packages
├── jetbrains-keymaps/          # shared IDE keymap
├── git/ignore                  # global gitignore
├── gh/config.yml               # GitHub CLI
└── thefuck/settings.py         # command correction
~/.ssh/config                   # SSH (no keys)
~/scripts/
├── setup.sh                    # bootstrap a new Mac
├── merge_pr.sh                 # interactive PR merge helper
└── script_manager.sh           # alias/script manager
```

## Install on a New Mac

```bash
# 1. Install chezmoi and pull dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply norens

# 2. Run bootstrap script
~/scripts/setup.sh
```

## Daily Usage

```bash
# See what chezmoi would change
cz diff

# Track a new config file
cz add ~/.config/app/config.yml

# Edit and apply
cz edit ~/.zshrc
cz apply

# Commit and push
cz cd && git add -A && git commit -m "description" && git push

# Update Brewfile after installing packages
brew bundle dump --file=~/.config/brewfile/Brewfile --force

# Regenerate Karabiner config after editing goku
goku
```

## Key Bindings

| Context | Key | Action |
|---|---|---|
| AeroSpace | `super` + `h/j/k/l` | Focus window |
| AeroSpace | `super` + `shift` + `h/j/k/l` | Move window |
| AeroSpace | `super` + `1-9` | Switch workspace |
| AeroSpace | `super` + `;` | Service mode |
| tmux | `ctrl-a` | Prefix |

## Notes

- **Karabiner**: Always edit `~/.config/goku/karabiner.edn`, never `karabiner.json` directly
- **SketchyBar helpers**: Rebuild with `cd ~/.config/sketchybar/helpers && bash install.sh`
- **JetBrains keymap**: Single source at `~/.config/jetbrains-keymaps/macOS_mod.xml`, distributed via `setup.sh`
- **Secrets**: Auth tokens, SSH keys, and API keys are never tracked
