# CachyOS Setup — Status

Останнє оновлення: 2026-05-25

## Загальний прогрес

```
Phase 0 — Pre-install Windows     ██████████ 100% (вже виконано)
Phase 1 — CachyOS install         ██████████ 100% (system bootstraps, user logged in)
Bootstrap (this workspace)        ████████░░  80% (Tailscale + SSH + 1P keys ✅; claude-code on CachyOS — deferred)
Phase 1.5 — ML storage subvols    ██████████ 100% (Plan 1, 2026-05-25)
Phase 2 — NVIDIA + CUDA           █████████░  90% (driver 595.71.05 + nvidia-container-toolkit + CDI; kanata/Hyprland pending)
Phase 3 — Keyboard parity         ░░░░░░░░░░   0%
Phase 4 — Dev environment         ░░░░░░░░░░   0%
Phase 5 — ML Foundation Slice     █████████░  90% (Plan 1: Podman+CDI+Ollama running on Tailscale; models pulling)
Phase 5b — Isaac Lab/Sim/GR00T    ░░░░░░░░░░   0% (Plan 3, TBD)
Phase 5c — Networking polish       ░░░░░░░░░░   0% (Plan 4, TBD)
Phase 6 — Apps + локалізація     ░░░░░░░░░░   0%
Phase 7 — Backup + snapshots      ░░░░░░░░░░   0%
Phase 8 — Polish                  ░░░░░░░░░░   0%
```

(Phases відповідають `~/cachyos-setup-tasks.md`.)

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
- **Архітектурні рішення зафіксовані в журналі (не в spec, бо це implementation details):**
  - Cross-OS chezmoi templating відкладено — на macOS і CachyOS у `~/.zshrc` різні файли, об'єднання в один template не варто складності зараз. Ml-related env додано напряму на CachyOS.
  - Rootless podman storage переїхав на `@ml-data/containers-rootless` (не на `@containers`). `@containers` залишений у fstab для майбутнього (якщо колись system-podman потрібен).
