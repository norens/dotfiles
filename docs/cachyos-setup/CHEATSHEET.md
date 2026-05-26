# CachyOS — Cheatsheet

Швидкий референс по hotkey-ах, програмах і середовищу для CachyOS ML-compute box (RTX 5070 Ti @ `nazarf-cachyos` через Tailscale).

---

## 1. Hotkeys

### Keychron K3 (Mac mode) — фізична розкладка

```
[ Ctrl ] [ Opt ] [ Cmd ] [ Space ] [ Cmd ] [ Opt ] [ Fn ]
                                                    ↑
                                            (Fn-row layer toggle)
```

### Що kanata робить з модифікаторами

| Фізична клавіша | Що надсилає у Linux |
|---|---|
| **Caps Lock** (тап) | Esc |
| **Caps Lock** (утримання) | Left Ctrl |
| **Cmd** (обидві) | **Left/Right Ctrl** (Kinto-style — щоб Cmd+letter працювало як на macOS) |
| **Opt** (ліва) | Left Alt (Hyprland $mainMod) |
| **Ctrl** | Ctrl (без змін) |
| **Opt** (права) | Right Alt / AltGr |

### App shortcuts — як на macOS (через Cmd → Ctrl)

| Hotkey | Дія |
|---|---|
| `Cmd+A` | Select all |
| `Cmd+C` / `Cmd+V` / `Cmd+X` | Copy / paste / cut |
| `Cmd+Z` / `Cmd+Shift+Z` | Undo / redo |
| `Cmd+S` | Save |
| `Cmd+F` | Find |
| `Cmd+R` | Reload |
| `Cmd+T` | New tab (browser) |
| `Cmd+W` | Close tab (browser) — НЕ закриває все вікно |
| `Cmd+Q` | Quit program (intercept by Hyprland → killactive) |
| `Cmd+L` | Focus address bar (browser) |
| `Cmd+1..9` | Switch tab (browser) |
| `Cmd+Tab` | Switch tab forward (Firefox) — на Mac це app switcher |

### Hyprland WM — через **Opt** (фізичну Alt-клавішу)

| Hotkey | Дія |
|---|---|
| `Opt+Space` | wofi launcher |
| `Opt+Return` | Terminal (Ghostty) |
| `Opt+E` | File manager (Dolphin) |
| `Opt+B` | Browser (Firefox) |
| `Opt+W` / `Opt+Q` | Kill window (WM-level — закриває вікно) |
| `Opt+F` | Toggle fullscreen |
| `Opt+Tab` | Cycle windows |
| `Opt+P` | Pseudo-tile |
| `Opt+1..9` | Switch to workspace N |
| `Opt+0` | Switch to workspace 10 |
| `Opt+Shift+1..9` | Move window to workspace N |
| `Opt+Shift+V` | Toggle floating window |
| `Opt+Shift+Q` | Logout (exit Hyprland) |
| `Opt+left/right/up/down` | Move focus |
| `Opt+Shift+arrow` | Move window in direction |
| `Opt+Ctrl+left/right` | Switch workspace ± 1 |
| `Opt+Ctrl+Q` | Lock screen (hyprlock) |
| `Opt+H` / `Opt+Shift+H` | Toggle / move to hidden special workspace |
| `Opt+Shift+R` | Reload Hyprland config |

### Cmd-prefix биндинги, які перехоплює Hyprland (паралельно до Opt)

| Hotkey | Дія |
|---|---|
| `Cmd+Space` | wofi launcher (Spotlight muscle memory) |
| `Cmd+Q` | killactive (інтерсептується до того як Firefox/Ghostty побачить) |

### Screenshots — Cmd+Shift+N (explicit Ctrl-prefix у Hyprland)

| Hotkey | Дія |
|---|---|
| `Cmd+Shift+3` | Full screen → `~/Pictures/Screenshots/` + swaync toast |
| `Cmd+Shift+4` | Region → `~/Pictures/Screenshots/` + clipboard |
| `Cmd+Shift+5` | Region → satty annotation editor → save + clipboard |

### Caps tap-hold accelerators (бо hold = Ctrl)

| Hotkey | Дія |
|---|---|
| `Caps+L` | Clear screen (Ctrl+L) |
| `Caps+C` | Interrupt running command (Ctrl+C) |
| `Caps+R` | Reverse history search (Ctrl+R) |
| `Caps+W` | Delete word backward |
| `Caps+U` | Delete to start of line |

### Ghostty terminal

| Hotkey | Дія |
|---|---|
| `Cmd+C` / `Cmd+V` | Copy / paste (через `ctrl+c performable` + `ctrl+v`) |
| `Cmd+Shift+Ctrl+T` | Toggle quick terminal (global) |

### Ukrainian / English layout

| Hotkey | Дія |
|---|---|
| **Right Ctrl** | Toggle UA / EN (Waybar показує active layout) |

---

## 2. Програми / що для чого

### Wayland compositor stack
- **Hyprland** — compositor, конфіг `~/.config/hypr/hyprland.conf`
- **Waybar** — top bar (GPU temp, CPU, RAM, network, audio, layout, tray) — Gruvbox Dark Hard
- **swaync** — notification center, panel toggle через `Cmd+N` (TODO: bind)
- **hypridle** — 5min dim / 10min lock / 30min DPMS off
- **hyprlock** — lock screen, fires from hypridle
- **awww** — wallpaper daemon (formerly known as swww — Arch repos renamed). `awww-daemon` runs from Hyprland `exec-once`, `~/.config/hypr/scripts/wallpaper-init.sh` sets `gruvbox/cabin.png`
- **wofi** — application launcher (Cmd+Space / Opt+Space)
- **hyprshot** — screenshot helper (used by Hyprland binds)
- **satty** — annotation editor for screenshots (Cmd+Shift+5)
- **cliphist** + `wl-paste --watch` — clipboard history daemon
- **hyprpolkitagent** — polkit prompts (`systemctl --user`)

### Keyboard remap
- **kanata** 1.11 — system service (`/etc/systemd/system/kanata.service`), config `~/.config/kanata/keychron.kbd`. udev rule `/etc/udev/rules.d/98-kanata-keychron-restart.rules` рестартує сервіс коли Keychron K3 hotplug-ається (KVM toggle).

### Terminal stack
- **Ghostty** 1.3 — terminal, config `~/.config/ghostty/config`. TokyoNight Storm theme, JetBrains Mono Nerd Font 16pt.
- **starship** — prompt (Gruvbox Dark), config `~/.config/starship.toml`
- **zsh** — shell. Loaded через `~/.zshrc` thin loader → `~/.zsh/{shared,linux}.zsh` (chezmoi-templated cross-OS)
- **atuin** — shell history sync/search (Ctrl+R replaced)
- **zoxide** — `z` smart cd
- **direnv** — per-dir env
- **mise** — language version manager
- **fzf** — fuzzy finder (Ctrl+T file, Ctrl+R history, Alt+C cd)
- **tldr** — short man pages

### CLI tools (modern Linux замість GNU coreutils)
| Замість | Сучасне |
|---|---|
| `ls` | `eza` |
| `cat` | `bat` (syntax highlighting) |
| `grep` | `rg` (ripgrep) |
| `find` | `fd` |
| `du` | `dust` |
| `ps` | `procs` |
| `top` / `htop` | `btop` |
| `sed` | `sd` |
| `cd` | `z` (zoxide) |
| `cat <json>` | `jq` |
| `cat <yaml>` | `yq` |
| (file manager) | `yazi` |
| `git diff` | `delta` (auto-pager) |
| (git TUI) | `lazygit` |
| (GitHub CLI) | `gh` |

### Dev toolchains (через mise)
- `node@24.16.0` + `npm:pnpm@11.3.0` — JS/TS
- `python@3.12.13` — Python
- `go@1.26.3` — Go
- `rust@stable (1.95.0)` — Rust (rustup-managed)
- `bun@1.3.14`, `deno@2.8.0` — JS runtimes
- `uv` (pacman) — Python venv/pkg manager для ML
- `claude` (npm-global `@anthropic-ai/claude-code`) — Claude Code CLI
- `nvim` + LazyVim — text editor

### ML stack
- **Podman** (rootless) — container runtime. Storage at `~/ml-data/containers-rootless` (btrfs nodatacow).
- **NVIDIA CDI** — container GPU passthrough (`/etc/cdi/nvidia.yaml`, auto-generated).
- **Ollama** — local LLM server. Quadlet at `~/.config/containers/systemd/ollama.container`. Binds на Tailscale interface only: `100.104.21.28:11434`. Models у `~/ml-data/ollama-models`.
- **PyTorch nightly** cu128 sm_120 — у `~/ml-data/pytorch-test/.venv` (uv).
- **NVIDIA driver** 595.71.05, CUDA build 12.8, cudnn 9.20.

### Backup
- **Snapper** 0.13 + **snap-pac** — btrfs snapshots before/after кожен `pacman -S/-U`. Plus snapper-timeline.timer (5 hourly, 7 daily).
- **limine-snapper-sync** — boot menu entries per snapshot (можна boot з попередньої версії OS).
- **btrfs-assistant** — GUI для управління снапшотами.

---

## 3. Середовище (paths, services, files)

### File system layout
- `/` — btrfs root subvol `@`
- `/home` — btrfs subvol `@home`
- `~/.local/share/chezmoi` — dotfiles repo (`norens/dotfiles` on GitHub)
- `~/ml-data/` — окремий btrfs subvol `@ml-data` (nodatacow, для CoW-heavy ML workloads):
  - `checkpoints/`, `datasets/`, `hf-cache/`, `isaac-cache/`
  - `containers-rootless/` — Podman rootless storage
  - `ollama-models/` — pulled GGUF models
  - `pytorch-test/.venv/` — uv venv для smoke tests
- `~/Pictures/Screenshots/` — куди hyprshot пише PNG
- `~/Pictures/Wallpapers/gruvbox/` — Gruvbox wallpapers; symlink `gruvbox-default.png → cabin.png`

### Tailscale
- macOS: `100.97.200.36 s-macbook-pro`
- CachyOS: `100.104.21.28 nazarf-cachyos`
- SSH: `ssh nazarf@nazarf-cachyos` (Tailscale SSH через magic-DNS)

### systemd units worth knowing
| Unit | Що робить |
|---|---|
| `kanata.service` (system) | Keyboard remap |
| `snapper-timeline.timer` (system) | Periodic snapshots |
| `snapper-cleanup.timer` (system) | Cleanup old snapshots |
| `limine-snapper-sync.service` (system) | Boot entries per snapshot |
| `ollama.service` (user) | Ollama via Quadlet |
| `loginctl enable-linger nazarf` | User services survive logout |

### Key files
| Файл | Опис |
|---|---|
| `~/.config/hypr/hyprland.conf` | Hyprland config (binds, autostart, input) |
| `~/.config/hypr/hypridle.conf` | Idle policy |
| `~/.config/hypr/hyprlock.conf` | Lock screen |
| `~/.config/kanata/keychron.kbd` | Keyboard remap config |
| `~/.config/waybar/{config.jsonc,style.css}` | Top bar |
| `~/.config/swaync/{config.json,style.css}` | Notifications |
| `~/.config/ghostty/config` | Terminal config |
| `~/.config/mise/config.toml` | Dev toolchain versions |
| `~/.zshrc` | Thin loader → `~/.zsh/{shared,linux}.zsh` |
| `/etc/systemd/system/kanata.service` | kanata systemd unit |
| `/etc/udev/rules.d/98-kanata-keychron-restart.rules` | KVM-hotplug restart |
| `/etc/udev/rules.d/99-uinput.rules` | uinput group access |
| `/etc/snapper/configs/root` | Snapper retention policy |

### chezmoi
```bash
chezmoi diff          # what would change
chezmoi update        # git pull + apply
chezmoi edit ~/.zshrc # edit via chezmoi
chezmoi apply         # apply staged changes
chezmoi cd            # cd into source dir
```

### Snapper
```bash
sudo snapper -c root list                       # show all
sudo snapper -c root status N..M                # diff
sudo snapper -c root rollback N                 # rollback (then reboot)
sudo snapper -c root create -c manual -d "..."  # manual snapshot
```

### ML quick commands
```bash
# Activate PyTorch venv
cd ~/ml-data/pytorch-test && source .venv/bin/activate

# New ML experiment with isolated venv
cd ~/ml-data && mkdir -p new-experiment && cd new-experiment
uv venv && source .venv/bin/activate
uv pip install <packages>

# Talk to Ollama
curl http://nazarf-cachyos:11434/api/tags        # list models
ollama run qwen2.5:14b                            # interactive
```

### Common breakages → fixes
| Симптом | Виправлення |
|---|---|
| Caps Lock тільки toggle-ить замість Esc після KVM toggle | udev rule повинен auto-restart kanata; перевір `journalctl -u kanata.service -n 20` |
| Шпалер не показується після логіну | `awww-daemon` не запустився; `pgrep -x awww-daemon`, якщо нема — `awww-daemon &` |
| Hyprland WM hotkeys не працюють | KVM на іншій машині? Або `hyprctl reload` |
| `chezmoi diff` показує невідому правку | Хтось редагував файл напряму у `~/.config/` — або promote змін у chezmoi через `chezmoi add`, або відкатити `chezmoi apply` |
| OS зламалась після pacman -Syu | Limine boot menu → вибери pre-snapshot, потім `sudo snapper -c root rollback N` |
