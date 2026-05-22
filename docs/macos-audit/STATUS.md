# macOS Audit — Implementation Status

Останнє оновлення: 2026-05-20

## Загальний прогрес

```
Phase 0 — Repo hygiene             ████████░░  80% (3 ручні дії залишилось)
Phase 1 — Безпека + дані           █████████░  90% (B2 ✅, K1 ✅, K2 ✅, K3 ✅, K5 ✅, B1 чекає SSD)
Phase 2 — Shell foundation         █████████░  90% (S1-S6 ✅, K6 deferred)
Phase 3 — Project workflow         █████████░  90% (P1-P4 ✅, K4/K6 deferred)
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

### (K5) Git commit signing via SSH (1Password) ✅
- [x] **DONE** Створено окремий Ed25519 ключ у 1Password (`SSH: git signing (Ed25519)`) — приватка ніколи не торкала диск — 2026-05-22
- [x] **DONE** `~/.gitconfig`: `gpg.format ssh`, `commit.gpgsign true`, `tag.gpgsign true`, `user.signingkey` inline — 2026-05-22
- [x] **DONE** `~/.config/git/allowed_signers` — для локальної верифікації — 2026-05-22
- [x] **DONE** `SSH_AUTH_SOCK` → 1P agent socket у `.zshrc` (необхідно для git's ssh-keygen, бо він не читає ssh_config IdentityAgent) — 2026-05-22
- [x] **DONE** Local verify: test commit `c197cf5` → `Good "git" signature for nazarfedishin@gmail.com with ED25519 key SHA256:s5ldt8En...` (відкочено після перевірки) — 2026-05-22
- [x] **DONE** GitHub Signing Key додано — 2026-05-22

### (K4) chezmoi + 1Password — DEFERRED
- Built-in `onepasswordRead` template function працює без додаткового config. Налаштування зайвe доки немає template-ів з secrets. Активуємо коли з'явиться перший use case.

## Phase 2 — Shell foundation
- [x] **DONE** (S1) ripgrep 15.1.0 (вже було, додано у Brewfile) — 2026-05-22
- [x] **DONE** (S2) atuin 18.16.1 local-only (`--disable-up-arrow`, sync server defer до CachyOS). History імпортовано з ~/.zsh_history — 2026-05-22
- [x] **DONE** (S3) direnv 2.37.1, hook у `.zshrc` — 2026-05-22
- [x] **DONE** (S4) git-delta 0.19.2: `core.pager`, `interactive.diffFilter`, navigate, line-numbers, gruvbox-dark theme, `merge.conflictStyle=zdiff3`, `diff.colorMoved=default` — 2026-05-22
- [x] **DONE** (S5) `EDITOR=nano` (per user CLAUDE.md context — nano для quick edits, не vim), `VISUAL=nano`, `PAGER=less`, `MANPAGER` через bat — 2026-05-22
- [x] **DONE** (S6) `alias cd='z'` (zoxide) — 2026-05-22
- [ ] (K6) direnv + 1Password pattern — defer разом з K4 до першого use case. Both work without setup; activate коли з'явиться `.envrc` що потребує secrets.

## Phase 3 — Project workflow
- [x] **DONE** (P1) mise 2026.5.13 — Node migration з fnm. `~/.config/mise/config.toml` з `idiomatic_version_file_enable_tools = ["node"]` щоб респектити `.nvmrc`. Global default `node@24.12.0`; test у `~/IdeaProjects/url-shortener/` resolved до `node@20.20.2` per .nvmrc. fnm лишився в Brewfile (transition fallback) — 2026-05-22
- [x] **DONE** (P2) uv 0.11.16 (Astral). Для нових Python projects. Не торкає pyenv. — 2026-05-22
- [x] **DONE** (P3) ghq 1.10.1. `git config --global ghq.root '~/ghq'`. Майбутні `ghq get …` йдуть у `~/ghq/<host>/<owner>/<repo>` — 2026-05-22
- [x] **DONE** (P4/S9) sesh 2.26.2. `~/.config/sesh/sesh.toml` з sources: tmux/zoxide/ghq/legacy project dirs. tmux keybind `Prefix+Space` → fzf-popup picker — 2026-05-22
- [ ] (K4) chezmoi + 1Password — deferred (`onepasswordRead` built-in; no template needs secrets yet)

## Phase 4-8
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
- **2026-05-22** — K5 (git commit signing via SSH) виконано. Окремий Ed25519 ключ створено всередині 1Password vault (приватка ніколи не торкала диск); локальна верифікація пройшла; GitHub Signing Key додано. `SSH_AUTH_SOCK` тепер експортовано в `.zshrc` → 1P agent socket. K4 (chezmoi+op) deferred — `onepasswordRead` працює built-in, доки немає use case.
- **2026-05-22** — Phase 2 Shell foundation (S1-S6). atuin (local-only, history імпортовано), direnv, git-delta (gruvbox-dark, navigate, zdiff3), ripgrep тепер у Brewfile. EDITOR=nano per CLAUDE.md, MANPAGER=bat. `alias cd=z`. K6 (direnv+op pattern) deferred. Phase 2 у 90% (S7-S9 — modern CLI utils, tmux plugins, sesh — Layer 2 але поза Phase 2 скоупом, пізніше).
- **2026-05-22** — Phase 3 Project workflow (P1-P4). mise замінив fnm у zshrc (legacy .nvmrc reading увімкнено). uv поставлено для нових Python. ghq з ~/ghq root. sesh з tmux Prefix+Space picker, sources: tmux/zoxide/ghq/legacy IdeaProjects/CLionProjects/WebstormProjects/projects.
