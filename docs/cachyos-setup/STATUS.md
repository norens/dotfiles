# CachyOS Setup — Status

Останнє оновлення: 2026-05-22

## Загальний прогрес

```
Phase 0 — Pre-install Windows     ██████████ 100% (вже виконано)
Phase 1 — CachyOS install         ██████████ 100% (system bootstraps, user logged in)
Bootstrap (this workspace)        █░░░░░░░░░  10% (planning)
Phase 2 — NVIDIA + CUDA           ░░░░░░░░░░   0%
Phase 3 — Keyboard parity         ░░░░░░░░░░   0%
Phase 4 — Dev environment         ░░░░░░░░░░   0%
Phase 5 — ML stack                ░░░░░░░░░░   0%
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
