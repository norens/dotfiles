# macOS Audit — Implementation Status

Останнє оновлення: 2026-05-20

## Загальний прогрес

```
Phase 0 — Repo hygiene             ████████░░  80% (3 ручні дії залишилось)
Phase 1 — Безпека + дані           █░░░░░░░░░  10% (підготовка)
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
- [ ] **MANUAL** Створити R2 bucket у Cloudflare dashboard
- [ ] **MANUAL** Створити R2 API token (Object Read & Write)
- [ ] **MANUAL** Зберегти credentials у 1Password (item: "Cloudflare R2 Backup")
- [ ] **CC** Поставити restic: `brew install restic`
- [ ] **CC** Підготувати config + exclude file у `~/.config/restic/`
- [ ] **CC** Створити launchd plist `~/Library/LaunchAgents/com.user.restic-backup.plist`
- [ ] **CC** `launchctl load` + перший manual run
- [ ] Verification: `restic -r r2:... snapshots` показує snapshot

### (K1) 1Password
- [ ] **MANUAL** Підписатись на 1Password (~$3/міс)
- [ ] **CC** `brew install --cask 1password 1password-cli`
- [ ] **MANUAL** Logged in у Desktop app
- [ ] **MANUAL** Експортувати з Apple Passwords (Settings → Passwords → "..." → Export)
- [ ] **MANUAL** Імпортувати CSV в 1Password
- [ ] **MANUAL** Safari extension: 1Password autofill замість Apple Passwords
- [ ] Verification: `op vault list` показує items

### (K2) SSH config hardening + 1Password agent
- [ ] **MANUAL** 1Password Settings → Developer → "Use the SSH agent" ON
- [ ] **MANUAL** Імпортувати наявні SSH ключі (`~/.ssh/id_*`) у 1Password як SSH Key items
- [ ] **CC** Додати `~/.ssh/config` у chezmoi (`private_dot_ssh/config`)
- [ ] **CC** Додати global `Host *` block з hardening
- [ ] Verification: `ssh -T git@github.com` без passphrase prompt

### (K3) Fix broken SSH config
- [x] **DONE** Виправлено nested `Host` (staging-es.l-club.biz + 95.216.202.206) — 2026-05-20
- [x] **DONE** Видалено exact duplicate `Host shop.med.lviv.ua` — 2026-05-20
- [ ] **MANUAL** Розпакувати duplicate `Host 71.9.27.70` (різні ports 2222 vs 2212). Треба перейменувати на aliases (напр. `pool-71` + `deploy-71`) + `HostName 71.9.27.70`. SSH зараз бере першу сумісність → друга unreachable.
- [ ] **CC (потім)** Перевірити що `staging-es.l-club.biz` справді мав бути окремий від `95.216.202.206`, чи задумувалось як `HostName 95.216.202.206`. Backup: `~/.ssh/config.backup-2026-05-20`.

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
