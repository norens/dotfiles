# CachyOS Setup — Status

Останнє оновлення: 2026-05-27

## Scope (locked 2026-05-27)

**CachyOS = ML-compute box only.** Used remotely from MacBook via Tailscale SSH for running models (Ollama / llama.cpp) and training (PyTorch nightly cu128). All actual development happens on macOS. Gaming stays on Windows side of the dual-boot (user picks Windows at boot when gaming). Off-site backup not needed — local Snapper snapshots are enough; reproducible ML environments are recreatable from `~/.local/share/chezmoi`.

**Setup considered DONE.** Remaining items in the table below are explicitly out-of-scope, not "to do".

## Загальний прогрес

```
Phase 0 — Pre-install Windows     ██████████ 100%
Phase 1 — CachyOS install         ██████████ 100%
Bootstrap (this workspace)        ██████████ 100% (Tailscale + SSH + 1P keys + cross-OS chezmoi + claude-code on CachyOS)
Phase 1.5 — ML storage subvols    ██████████ 100%
Phase 2 — NVIDIA + CUDA           ██████████ 100%
Phase 3 — Keyboard parity         ██████████ 100% (kanata Cmd→Ctrl Kinto-style + Caps tap-hold; KVM-safe via udev hotplug rule)
Phase 3b — Desktop polish         ██████████ 100% (Waybar+swaync+hypridle+awww+hyprshot+satty all Gruvbox)
Phase 4 — Dev environment         ██████████ 100% (CLI + chezmoi + mise toolchains + nvim+claude — sufficient for SSH-driven remote use; vscode/cursor/zed/1P-GUI out of scope)
Phase 5 — ML Foundation Slice     ██████████ 100% (Podman+CDI+Ollama; PyTorch nightly cu128 sm_120 verified)
Phase 5b — Isaac Lab/Sim/GR00T    ░░░░░░░░░░  out of scope until needed
Phase 5c — Networking polish       ░░░░░░░░░░  out of scope (Tailscale + LAN sufficient)
Phase 6 — Apps + локалізація     ██████████ 100% (UA layout + fonts; GUI apps out of scope — remote use only)
Phase 7 — Backup + snapshots      ██████████ 100% (Snapper timeline+pacman hooks; off-site backup out of scope)
Phase 8 — Polish                  ░░░░░░░░░░  out of scope (dual-boot fine, gaming = Windows)
```

(Phases originally tracked from `~/cachyos-setup-tasks.md`. Out-of-scope phases pruned to match the locked ML-compute role.)

## Bootstrap (передумова до Phase 2+)

Мета: налагодити mesh-доступ MacBook → CachyOS + поставити claude-code на CachyOS щоб CC tasks #2-#20 виконувались nативно з другого кінця.

### macOS-сторона
- [ ] **MANUAL** `brew install --cask tailscale-app` (потребує sudo TTY)
- [ ] **MANUAL** Запустити Tailscale.app, sign in через SSO (Google/GitHub/Apple)
- [ ] Verification: `tailscale status` показує MacBook

### CachyOS-сторона (виконати на самому CachyOS у терміналі)
- [ ] **MANUAL** Завантажити bootstrap script: `curl -O https://raw.githubusercontent.com/norens/dotfiles/main/docs/cachyos-setup/scripts/00-bootstrap.sh` (або через scp/copy-paste)
- [ ] **MANUAL** Прочитати + запустити: `bash 00-bootstrap.sh`
- [ ] **MANUAL** `sudo tailscale up --ssh` — sign in через ту саму tailnet
- [ ] Verification (на CachyOS): `tailscale status` показує обидва вузли
- [ ] **MANUAL** Додати SSH public key з 1Password у `~/.ssh/authorized_keys` (1P-exposed public key)

### Перевірка SSH end-to-end
- [ ] З macOS: `ssh nazar@<cachyos-hostname>` (Tailscale magic-DNS)
- [ ] Touch ID prompt → 1Password agent authorizes
- [ ] Login без password

### Claude Code на CachyOS
- [ ] **CC #1** (на CachyOS): pacman/AUR встановити `claude-code` (or upstream npm install)
- [ ] **MANUAL**: `claude` запускається, login до Anthropic account
- [ ] Verification: `claude` працює, бачить `~/.local/share/chezmoi/docs/cachyos-setup/`

## Після bootstrap → продовжуємо PLAN.md

`~/cachyos-setup-tasks.md` Phase 2+ (NVIDIA, kanata, Hyprland, dev env). Виконуються вже з нативного Claude на CachyOS.

## Журнал

- **2026-05-22** — Workspace створено, bootstrap-стратегія узгоджена (Tailscale mesh + claude-code на CachyOS).
- **2026-05-24** — ML/Robotics дизайн-спека написана (`specs/2026-05-24-ml-robotics-stack-design.md`). Container-first підхід (Podman + NVIDIA CDI). Plan 1 (foundation slice) задокументовано в `plans/`.
- **2026-05-25** — Bootstrap фактично виконано (Tailscale on both, sshd hardening, 1Password public key у `authorized_keys`). SSH `nazarf@100.104.21.28` working via ControlMaster.
- **2026-05-25** — **Plan 1 виконано driven from macOS via SSH:**
  - **Task 1-3:** btrfs subvols `@ml-data` (ID 294) → `/home/nazarf/ml-data`, `@containers` (ID 295) → `/var/lib/containers`. fstab entries з `nodatacow,noatime,compress=no,ssd,discard=async`. `chattr +C` на mount-points + subdirs (new files inherit `C` flag — verified via lsattr).
  - **Task 4:** ML env вставлено напряму у CachyOS `~/.zshrc` (НЕ chezmoi — cross-OS templating deferred). `HF_HOME=$HOME/ml-data/hf-cache`, `TRANSFORMERS_CACHE`, `HF_DATASETS_CACHE`, `PODMAN_USERNS=keep-id`.
  - **Task 5:** podman 5.8.2 + nvidia-container-toolkit 1.19.0 + slirp4netns + fuse-overlayfs. CDI auto-generated post-install (`/etc/cdi/nvidia.yaml`). GPU passthrough verified: `nvidia-smi` всередині `nvcr.io/nvidia/cuda:12.8.0-base-ubuntu24.04` показав RTX 5070 Ti, driver 595.71.05, CUDA 13.2.
  - **Architectural fix mid-Task-5:** rootless podman за замовчуванням пише в `$HOME/.local/share/containers/storage` (regular CoW). Pivot via `~/.config/containers/storage.conf` → `graphroot = /home/nazarf/ml-data/containers-rootless` (nodatacow inherited). `@containers` subvol залишається для system-podman (наразі не used).
  - **Task 6-7:** Ollama Quadlet у `~/.config/containers/systemd/ollama.container`. **НЕ chezmoi-managed** (cross-OS templating deferred). `PublishPort=100.104.21.28:11434:11434` — bind тільки на Tailscale interface. Volume `~/ml-data/ollama-models` (Z relabel). `TimeoutStartSec=600` (default 90s занадто короткий для image pull). Image (6.55 GB!) pulled manually перед service start щоб уникнути restart-loop на pull-timeout. Service `active (running)`. `loginctl enable-linger nazarf` → service survive logout. Quadlets НЕ потрібно `systemctl enable` — `[Install]` секція робить це автоматично через generator.
  - **Task 8:** Pull `qwen2.5-coder:7b` + `qwen2.5:14b-instruct` (in progress).
  - **Task 9 phase 1:** E2E з MacBook ✅ — Tailscale magic-DNS `nazarf-cachyos` resolve, direct LAN connection (192.168.0.71), `curl http://nazarf-cachyos:11434/api/tags` повертає JSON.
- **2026-05-25** — **Cross-OS chezmoi migration COMPLETE (Plan 2, `docs/cross-os-chezmoi/`):** обидві машини під одним `norens/dotfiles` репо. `.chezmoiignore.tmpl` фільтрує macOS-only (aerospace/karabiner/goku/sketchybar/brewfile/Library/...) і Linux-only (hypr/waybar/mako/kanata/containers) шляхи per-host. `~/.zshrc` тепер thin loader → `~/.zsh/{shared,darwin|linux}.zsh`. ML env (`HF_HOME`, `PODMAN_USERNS`) перенесено з ad-hoc CachyOS `~/.zshrc` у chezmoi-managed `linux.zsh`. `ollama.container` + `storage.conf` promoted у chezmoi. CachyOS `chezmoi managed` = 65 файлів (vs MacBook 140) — ignore template працює.
- **Архітектурні рішення зафіксовані в журналі (не в spec, бо це implementation details):**
  - Cross-OS chezmoi templating DONE (Plan 2). Раніше відкладалось — закрито 2026-05-25.
  - Rootless podman storage переїхав на `@ml-data/containers-rootless` (не на `@containers`). `@containers` залишений у fstab для майбутнього (якщо колись system-podman потрібен).
- **2026-05-27** — **CachyOS setup CLOSED.** User locked scope: CachyOS is an ML-compute box accessed remotely from MacBook via Tailscale SSH; dev happens on macOS; gaming on Windows dual-boot. Out-of-scope (no further action): 1Password GUI, vscode/cursor/zed editors, off-site backup, Isaac Lab/Sim, GUI app installs, gaming polish. In-scope and DONE: kernel/NVIDIA/CUDA, keyboard parity (kanata Kinto-style + KVM hotplug), Hyprland+Waybar+swaync+hypridle+awww, Ukrainian layout+fonts, Podman/CDI/Ollama, PyTorch nightly cu128 (sm_120 verified), Snapper timeline+pacman hooks, mise toolchains, nvim+claude. Cross-OS chezmoi templating from Plan 2 keeps everything reproducible. Future returns to this workspace = ad-hoc ML workflow needs only (model pulls, isolated venvs), not setup.
- **2026-05-26** — **Phase 7.1 Snapper.** CachyOS ships fully configured: snapper 0.13.1 + snap-pac (pre/post pacman hooks) + limine-snapper-sync (boot entries per snapshot) + btrfs-assistant GUI + cachyos-snapper-support. Only changes this session: enabled `snapper-timeline.timer` + `snapper-cleanup.timer` (default was disabled — added 5 hourly + 7 daily timeline snapshots in addition to pacman pre/post). Also uninstalled `visual-studio-code-insiders-bin` that paru sneaked in despite user's interrupt — caught via snapshot 47-48 review. Rollback procedure: `sudo snapper -c root rollback N` → reboot, or pick snapshot from limine boot menu.
- **2026-05-26** — **Phase 4.1 / 4.2 / 4.3 done; 4.4 reduced to nvim+claude (user skipped vscode/cursor/zed).** CLI stack mostly pre-installed by CachyOS — only `yazi` + `github-cli` had to be added (pacman). zsh hooks (`starship`, `zoxide`, `direnv`, `atuin`, `mise`, `fzf`) already wired via `~/.zsh/{shared,linux}.zsh` from Plan 2. Chezmoi bootstrap: implicit (already running cross-OS). mise toolchain materialized: `bun 1.3.14`, `deno 2.8.0`, `go 1.26.3`, `node 24.16.0`, `npm:pnpm 11.3.0`, `python 3.12.13`, `rust 1.95.0 stable`. Fix: switched pnpm from `aqua:pnpm` to `npm:pnpm` backend (aqua asset naming mismatch on linux-x64). atuin history import from MacBook deferred — needs manual file copy.
- **2026-05-26** — **Phase 5.3 PyTorch CUDA verification PASS.** Driver 595.71.05 + uv venv (Python 3.12.13) at `~/ml-data/pytorch-test/.venv`. `torch==2.12.0.dev20260407+cu128`, `torchvision==0.27.0.dev`, `triton==3.7.0+git9c288bc5`. Smoke test: `cuda.is_available()=True`, device "NVIDIA GeForce RTX 5070 Ti" sm_120 (Blackwell), CUDA build 12.8, cudnn 9.20. Matmul 4096³ fp32 = 4.07ms (33.8 TFLOPS, ~77% of theoretical 44 TFLOPS peak). 5-step MLP forward+backward converges, gradients flow. `uv` installed via `pacman -S uv` (0.11.16). Initial `uv pip install` hit network timeout on `nvidia-nvjitlink-cu12` — retry with `UV_HTTP_TIMEOUT=300` succeeded.
- **2026-05-26** — **Plan 3 Desktop UX COMPLETE** (`docs/cachyos-setup/specs/2026-05-25-desktop-ux-design.md`, `plans/2026-05-25-desktop-ux-implementation.md`). Driven from MacBook via Tailscale SSH + chezmoi git push/pull.
  - **kanata 1.11** system service via `scripts/setup-kanata-cachyos.sh` (uinput module + group + udev rules + systemd unit). Config `~/.config/kanata/keychron.kbd` matches by auto-discovery (kanata 1.11 ignored `linux-dev-names-include`-filtered devices, fallback works). `--watch-devices` doesn't exist in 1.11, replaced by `linux-continue-if-no-devs-found yes` + **udev rule** (`98-kanata-keychron-restart.rules`) that restarts the service on Keychron K3 USB hotplug (matches by Apple VID 05ac / PID 024f). Without that rule kanata stays "active" after KVM toggle but doesn't re-grab.
  - **Final keymap (Kinto-style macOS-feel)**: physical Cmd → LCTRL/RCTRL so Cmd+A/Z/T/W/Q/C/V/S/F/L hit Linux apps' Ctrl shortcuts natively. Caps tap=Esc, hold=LCtrl. Physical Opt stays LALT. Original spec's lAlt↔lMet swap dropped: Keychron K3 in **Mac mode** already ships macOS-order keycodes hardware-side, so swapping again reversed it.
  - **Hyprland** $mainMod = ALT (Opt-key drives launcher/workspaces/cycler/killactive). Screenshots on explicit `CTRL SHIFT, 3/4/5` so physical Cmd+Shift+N still triggers hyprshot. Parallel `CTRL, Space` (Cmd+Space → wofi) and `CTRL, Q` (Cmd+Q → killactive) for Spotlight + quit muscle memory. Move-to-workspace on Opt+Shift+N. `$mainMod+V` togglefloating freed → Cmd+Shift+V (so Cmd+V is paste).
  - **Ghostty** keybinds add `performable:ctrl+c=copy_to_clipboard` + `ctrl+v=paste_from_clipboard` (kept legacy `cmd+c`/`cmd+v` for macOS-native).
  - **Wallpaper**: `awww-daemon` (NOT swww — CachyOS/Arch repos renamed swww → awww as `An Answer to your Wayland Wallpaper Woes`, codeberg.org/LGFae/awww, drop-in CLI compat). `wallpaper-init.sh` set to executable via chezmoi `executable_` prefix. `gruvbox/cabin.png` default.
  - **Waybar / swaync / hypridle** all Gruvbox Dark Hard, running via Hyprland `exec-once`. Ukrainian layout toggle via Right Ctrl (`grp:rctrl_toggle`).
  - **Trade-offs accepted**: Ctrl+Space in apps blocked (VSCode IntelliSense force-suggest unreachable — use Opt+Space alternate). Alt+F/E/B browser menu access blocked by Hyprland binds. Cmd+R font-size / Cmd+E reset / Cmd+Enter fullscreen in Ghostty don't fire on Linux (would need OS-conditional template — deferred).
