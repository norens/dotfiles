# macOS Audit — Implementation Status

Останнє оновлення: 2026-05-20

## Загальний прогрес

```
Phase 0 — Repo hygiene             ████████░░  80% (3 ручні дії залишилось)
Phase 1 — Безпека + дані           ████████░░  80% (B2 ✅, K1 ✅, K2 ✅, K3 ✅, B1 чекає SSD)
Phase 2 — Shell foundation         ░░░░░░░░░░   0%
Phase 3 — Project workflow         ░░░░░░░░░░   0%
Phase 4 — Containers + Cloud       ░░░░░░░░░░   0%
Phase 5 — Desktop UX polish        ░░░░░░░░░░   0%
Phase 6 — Nice-to-have CLI         ░░░░░░░░░░   0%
Phase 7 — JetBrains/Claude polish  ░░░░░░░░░░   0%
Phase 8 — Eventual                 ░░░░░░░░░░   0%
```

## Phase 0 — Repo hygiene

- [x] **DONE** Зберегти `cachyos-setup-tasks.md` у chezmoi (commit `f254517`)
- [x] **DONE** Створити workspace `~/docs/macos-audit/` для постійної роботи
- [ ] **MANUAL** Архівувати GitHub repo: `gh repo archive norens/macos-configs --yes`
- [ ] **MANUAL** Видалити `~/IdeaProjects/macos-configs/` (після `cd ~`): `rm -rf ~/IdeaProjects/macos-configs`
- [ ] **MANUAL** Перевірити `~/macos-configs/` (тільки `.claude` і `.idea` workspace metadata): `rm -rf ~/macos-configs` якщо не треба

## Phase 1 — Безпека + дані (CRITICAL)

### (B1) Time Machine
- [ ] **MANUAL** Купити external SSD (~1ТБ NVMe в USB-C корпусі, $80-100)
- [ ] **MANUAL** Підключити, увімкнути Time Machine (System Settings → General → Time Machine)
- [ ] Verification: `tmutil latestbackup` показує свіжий запис

### (B2) restic → Cloudflare R2
- [x] **DONE** R2 bucket `nazar-restic-backup` створено — 2026-05-21
- [x] **DONE** R2 Account API token (Object Read & Write, scoped to bucket) — 2026-05-21
- [x] **DONE** Credentials у 1Password item "Cloudflare R2 Backup" (Personal vault) — 2026-05-21
- [x] **DONE** `brew install restic` 0.18.1 + Brewfile — 2026-05-21
- [x] **DONE** `~/.config/restic/{env.sh,excludes.txt,backup.sh}` — 2026-05-21
- [x] **DONE** `~/Library/LaunchAgents/com.user.restic-backup.plist`, scheduled 03:00 daily — 2026-05-21
- [x] **DONE** Repo init (`b3ebfb0820`) + перший snapshot (`5de4489e`) — 2026-05-21
- [x] **DONE** launchd kickstart verified — incremental backup працює (snapshot `a282145c`) — 2026-05-21
- **Targets**: тільки `~/.local/share/chezmoi` (див. DECISIONS 2026-05-21). ~405 KiB raw, ~264 KiB stored.
- **Out of scope зараз**: `~/Documents` (в iCloud Drive), `~/projects` (старе, у git).

### (K1) 1Password
- [x] **DONE** Підписатись на 1Password (~$3/міс) — 2026-05-20
- [x] **DONE** `brew install --cask 1password 1password-cli` — 2026-05-20 (1password 8.12.12, cli 2.34.0); додано у Brewfile
- [x] **DONE** Logged in у Desktop app — 2026-05-21
- [x] **DONE** CLI integration увімкнено (`op vault list` працює без `op signin`) — 2026-05-21
- [x] **DONE** Експортовано з Apple Passwords — 2026-05-21
- [x] **DONE** Імпортовано CSV в 1Password (з OTPAuth column → "One-time password") — 2026-05-21
- [x] **DONE** CSV безпечно видалено через `rm -P ~/Downloads/Passwords.csv` — 2026-05-21
- [ ] **MANUAL** Safari extension: enable 1Password в Safari → Preferences → Extensions; зняти Apple Passwords autofill (System Settings → Passwords → AutoFill). Passkeys лишити в Apple.
- [x] **DONE** Verification: `op vault list` → `Personal` (fddrl7nlma7ldfiwq37hrgevje) — 2026-05-21

### (K2) SSH config hardening + 1Password agent ✅
- [x] **DONE** Fix permissions: id_ed25519-pwless, id_rsa_docker, ssh-p.ppk (були 0777 → 600/644) — 2026-05-22
- [x] **DONE** Archive ssh-p.ppk + config.save + known_hosts.old у `~/.ssh/archive/` — 2026-05-22
- [x] **DONE** 1Password Settings → Developer → "Use the SSH agent" ON — 2026-05-22
- [x] **DONE** Imported `id_rsa` + `id_rsa_docker` у 1Password (id_ed25519-pwless skip — невідомо чи активний) — 2026-05-22
- [x] **DONE** `~/.ssh/config` у chezmoi (`private_dot_ssh/config`) — 2026-05-22
- [x] **DONE** Hardening: IdentityAgent → 1P socket, IdentitiesOnly, modern ciphers/KEX/MACs, ControlMaster, ServerAliveInterval, HashKnownHosts, StrictHostKeyChecking accept-new — 2026-05-22
- [x] **DONE** `UseKeychain` видалено (Apple-only, не сумісно з Homebrew openssh; з 1P agent не потрібно) — 2026-05-22
- [x] **DONE** Verification: `ssh -T git@github.com` → `Hi norens! You've successfully authenticated` через 1P agent — 2026-05-22

### (K3) Fix broken SSH config ✅
- [x] **DONE** Виправлено nested `Host` (staging-es.l-club.biz + 95.216.202.206) — 2026-05-20
- [x] **DONE** Видалено exact duplicate `Host shop.med.lviv.ua` — 2026-05-20
- [x] **DONE** Duplicate `Host 71.9.27.70` розпаковано: `pool-71` (port 2222, user pool) + `deploy-71` (port 2212, user deploy) — 2026-05-22
- [x] **DONE** `staging-es.l-club.biz` об'єднано назад у один блок з `HostName 95.216.202.206` (DNS-перевірка показала що staging-es.l-club.biz не резолвиться, отже мав бути alias). User deploy + ForwardAgent. — 2026-05-22

### (Sec) raycast token guard
- [x] **DONE** Додано `.config/raycast` у `.chezmoiignore` (2026-05-20)

## Phase 2 — Shell foundation
*Очікує Phase 1.*

- [ ] (S1) ripgrep
- [ ] (S2) atuin (local-only поки що)
- [ ] (S3) direnv
- [ ] (S4) git-delta
- [ ] (S5) EDITOR/VISUAL/PAGER/MANPAGER env vars
- [ ] (S6) `alias cd='z'`
- [ ] (K6) direnv + 1Password pattern

## Phase 3-8
*Розгортаємо коли підійде черга. Деталі в SPEC.md.*

---

## Заблоковано чим

| Що блокує | Що чекає |
|---|---|
| Покупка SSD | (B1) Time Machine |
| Cloudflare R2 setup | (B2) restic config |
| 1Password subscription | (K1, K2, K4, K6) — всі 1Password-залежні |
| (K1, K2) | (K4) chezmoi+op, (K5) git signing, Phase 2 K6 |

## Журнал сесій

- **2026-05-20** — Brainstorm-сесія: 7 шарів пройдено, 8 phases прийнято. Phase 0 розпочато.
- **2026-05-21** — K1 (1Password міграція з Apple Passwords) + B2 (restic→R2 daily backup) реалізовано. Targets B2 скорочені до chezmoi-only (DECISIONS 2026-05-21). Залишається: Safari extension (K1, тривіально), B1 (купити SSD), K2-K5 (SSH + git signing).
- **2026-05-22** — K2 + K3 виконано. SSH хід через 1Password agent (Touch ID), modern crypto (chacha20-poly1305 first), ControlMaster, hashed known_hosts. Duplicate `Host 71.9.27.70` → `pool-71`/`deploy-71`. `staging-es.l-club.biz` → alias для 95.216.202.206. ~/.ssh/config тепер у chezmoi (`private_dot_ssh/config`). `UseKeychain` видалено — несумісне з Homebrew openssh і непотрібне з 1P agent.
- **2026-05-22** — Розпочато CachyOS bootstrap проект (`docs/cachyos-setup/`). Phase 4 D6 (tailscale) front-run-ить як частина mesh-доступу MacBook → CachyOS. Cask `tailscale-app` install чекає TTY-sudo (user manual action).
