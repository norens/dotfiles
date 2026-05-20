# macOS Dev Environment Audit — CTO-grade Setup

## Context

Користувач (nazar) — full-stack розробник (Backend + Frontend + ML + DevOps), MacBook + майбутній CachyOS PC, MX Master 4, BenQ PD2730S. Хоче "CTO-grade" workflow: професійний, надійний, з усіма правильними інструментами. Не знає що саме у нього недотягує, тому що "не знаю чим не користуюсь і що краще".

Цей план — **аудит macOS-сетапу шарами 1→7** з рекомендаціями. Це **brainstorm-фаза**: ми ще не пишемо implementation plan, а збираємо вичерпну "карту місцевості" (specs).

CachyOS-міграція — окремий проект (вже описаний у `cachyos-setup-tasks.md`). Уніфікація через chezmoi — теж окремо.

## Precondition: Repo hygiene

Перед самим аудитом:
- chezmoi (`~/.local/share/chezmoi` → `github.com/norens/dotfiles`) — canonical
- Архівувати `github.com/norens/macos-configs` (initial commit only, legacy yabai/skhd)
- Видалити порожній `~/macos-configs` (bare-repo заготовка)
- Видалити `IdeaProjects/macos-configs/CLAUDE.md` (bare-repo версія) або переписати під chezmoi
- Залишити одну `CLAUDE.md` всередині chezmoi-source

## Layer 1 — Window / Desktop UX ✅ DECIDED

### Поточний інвентар
- aerospace (tiling WM) — migrated from yabai/skhd, mature
- sketchybar (status bar) — full Felix-Kratz-style з усіма widgets + aerospace integration
- raycast (launcher) — стоїть, content unknown
- karabiner-elements + goku — 3 девайси (MacBook, Moonlander, Keychron K3 E3), Caps→Esc, fn→Super, L/R Cmd↔Opt swap
- mos + logi-options+ — дуплікація для mouse scroll

### Прийняті рішення
- **(Q1) Поставити BetterDisplay** — DDC/CI для BenQ PD2730S (brightness, HiDPI, PIP, M-Book input)
- **(Q2) Замінити `mos` + cleanup Logi Options+ на `LinearMouse`** — per-app pointer/scroll
- **(Q3) Поставити AltTab** — window-level switcher з preview (а не app-level Cmd+Tab)
- **(Q4) Розширити aerospace window rules:**
  - Floating: System Settings, Calculator, Zoom screen share, Activity Monitor, Finder dialogs
  - Per-app workspace: ws1=терміналі, ws2=браузер, ws3=IDE (вже є для IntelliJ), ws4=коммунікація (Telegram/Slack/Discord), ws5=Obsidian, ws6=monitoring (Lens)
- **(Q5) workspace-to-monitor-force-assignment** для BenQ (primary) + MacBook (secondary, або навпаки — уточнити)
- **(Sec)** Перевірити що `~/.config/raycast/config.json` НЕ потрапить в chezmoi або зашифрувати через age (там plaintext token)

### Skipped (для зараз)
- Hammerspoon — без конкретного use case
- Maccy / Raycast Pro — користувач сам розбереться з extensions

## Layer 2 — Shell + Terminal + CLI ergonomics ✅ DECIDED

### Поточний інвентар (сильна база)
- zsh + vi-mode + autosuggestions + syntax-highlighting
- starship, fzf (з fd + bat/eza preview для CTRL-T / ALT-C), zoxide, thefuck, eza, bat, fd
- ghostty (TokyoNight, JetBrainsMono Nerd, cursor shaders, quick-terminal toggle `cmd+shift+ctrl+t`)
- tmux + TPM + tmux-sensible + tmux-ghostty-theme з Claude widget
- lazygit, lazydocker

### Прийняті рішення
- **(S1) ripgrep** — критичний пропуск, додати.
- **(S2) atuin** — encrypted shared shell history між MacBook ↔ CachyOS. Self-hosted або hosted sync.
- **(S3) direnv** — per-project env (AWS_PROFILE, KUBECONFIG, .venv autoload). Hook в `.zshrc`.
- **(S4) git-delta** — інтегрувати з git + lazygit.
- **(S5) EDITOR/VISUAL/PAGER/MANPAGER** env vars (`nvim`/`cursor --wait`, `bat`/`delta`).
- **(S6) `alias cd='z'`** (або додатково `zd='zoxide query'`).
- **(S7) Modern CLI utils:** btop, dust, procs, sd, tealdeer, hyperfine, yq.
- **(S8) tmux-resurrect + tmux-continuum** + auto-save кожні 15хв.
- **(S9) sesh** для project session templates.

### Skipped
- Зміна tmux prefix (`C-b` → `C-a`) — personal preference.
- Альтернативні шелли (fish/nushell) — zsh добре налаштований.

## Layer 3 — Project switching + version mgmt ✅ DECIDED

### Поточний інвентар
- fnm (Node), pyenv + pyenv-virtualenv (Python), rbenv + rbenv-gemset (Ruby), go (brew, no version mgmt), Java (Toolbox JDKs)
- Project tree: `~/IdeaProjects/` ad-hoc

### Прийняті рішення
- **(P1) mise** — поставити, мігрувати Node з fnm. Залишити pyenv/rbenv паралельно поки що.
- **(P2) uv** — для нових Python-проектів. Legacy на pyenv-virtualenv лишається.
- **(P3) ghq** — нові репи в `~/ghq/github.com/...`, fzf-ghq binding для switch.
- **(P4) sesh** (з Layer 2) — інтегрувати з ghq: один хоткей → fzf зі всіма репами + автостворення tmux сесії.
- **(P5) Eventual:** мігрувати legacy Python проєкти pyenv→uv поступово.
- **(P6) Eventual:** rbenv → mise або викинути якщо Ruby майже не пишеш.
- **(P7) `mise.toml`** в активних проектах з версіями node/python/go/java.

### Skipped
- SDKMAN (mise замінює для Java)
- asdf, volta (mise замінює)

## Layer 4 — Editors / IDE / AI ✅ DECIDED

### Реальний стек
- **IDE:** JetBrains Toolbox only (IntelliJ/PyCharm/WebStorm/GoLand). DB-tools вбудовано.
- **AI:** Claude only (Claude Code CLI + Claude Desktop).
- **Quick edit:** nano (vim не використовує).

### Cleanup (shelfware removal)
- **(E0) Видалити:** Cursor (cask + `~/.cursor` + `Library/Application Support/Cursor/`), Codex (cask).
- **(E0a) Видалити AI folders якщо plugins вимкнені:** `~/.augment`, `~/.augmentcode`, `~/.junie`, `~/.copilot`, `~/.github-copilot`.
- **(E0b) Уточнити та видалити якщо не використовуєш:** Postman, Warp. JetBrains HTTP Client (`.http` файли) замінює Postman.
- **(E0c) Видалити з chezmoi:** Cursor settings (`Library/Application Support/Cursor/User/*`) — застаріле.

### Polish — JetBrains
- **(E1) Live Templates + Code Styles** додати в chezmoi: `Library/Application Support/JetBrains/*/templates/` та `*/codestyles/`. Або (E2).
- **(E2) JetBrains Settings Sync через JetBrains account** — синхронізує plugins/keymaps/templates/colors через хмару. Альтернатива chezmoi-трекання. Один з двох. Settings Sync працює cross-OS — рекомендую його як primary, chezmoi — backup.
- **(E3) Toolbox CLI shims:** Toolbox settings → "Generate shell scripts" → дає `idea .`, `pycharm .`, `goland .`, etc.

### Polish — Claude
- **(E5) `~/.claude/` selectively в chezmoi:** `settings.json`, custom `agents/`, `commands/`, `hooks`. НЕ трекати `projects/`, `cache/`, transcripts.
- **(E6) Claude Desktop MCP servers config** — `Library/Application Support/Claude/claude_desktop_config.json` додати в chezmoi. Корисні MCP: filesystem, github, postgres, youtrack, gmail.
- **(E7) Project-level `CLAUDE.md`** habit — в кожному активному проекті invariants + conventions.

### Skip
- nvim/LazyVim (nano достатньо для quick edits)
- Standalone DB GUI (JetBrains DB Tools вбудовано)
- `usql` (на майбутнє якщо треба CLI DB)

## Layer 5 — Dev tooling per domain ✅ DECIDED

### Контекст
- **Cloud:** Cloudflare + Hetzner + DigitalOcean. Жодного hyperscaler (AWS/GCP/Azure).
- **K8s:** **self-hosted k3s на Hetzner** (production).
- **ML:** не на macOS (тільки CachyOS пізніше).
- **HTTP:** JetBrains HTTP Client primary.

### Containers / K8s
- **(C1) Мігрувати з Docker Desktop на OrbStack** (cask `orbstack`).
- **(C2) Додати:** `k9s`, `kubectx`, `kubens`, `dive`, `stern`.
- **(C3) Kubeconfig hygiene:** один файл з k3s context, плюс per-project direnv override якщо треба декілька кластерів. Шифрувати через `chezmoi-age` якщо в repo.

### HTTP
- **(H1) `xh`** — CLI HTTP (Rust httpie). Для quick checks.
- Skip Bruno (JetBrains HTTP Client primary).

### Cloud-specific CLI
- **(Cl1) `wrangler`** (Cloudflare Workers/Pages, через npm-global або mise).
- **(Cl2) `doctl`** (DigitalOcean CLI, brew).
- **(Cl3) `hcloud`** (Hetzner Cloud CLI, brew).
- Skip: aws-cli, gcloud (не використовуєш).

### IaC / DevOps
- **(D1) `opentofu`** (terraform OSS fork) + **`tflint`** + **`tfsec`** (security scan).
- **(D2) `ansible`** через `uv tool install ansible` (легше за brew, ізольовано).
- **(D3) `act`** — local GitHub Actions runner.
- **(D4) `pre-commit`** framework.
- **(D5) `gitleaks`** — secret scanning (CI + pre-commit).
- **(D6) `tailscale`** (cask) — mesh VPN для доступу до Hetzner box з MacBook + майбутнього CachyOS.

### ML (macOS)
- Skip (Ollama тільки на CachyOS).

### DB CLI
- **(DB1) `pgcli`** + **`mycli`** — autocomplete + history. JetBrains DB Tools для GUI.

### Local dev plumbing
- **(L1) `mkcert`** — local trusted SSL для `*.dev.local`.
- **(L2) `watchexec`** (modern `entr`) — re-run on file change.
- **(L3) `gron`** — JSON в greppable формат.

## Layer 6 — Secrets / SSH / Plumbing ✅ DECIDED

### Контекст
- 1Password — обрано (paid $3/міс).
- Зараз: Apple Passwords (недостатньо для SSH + chezmoi + CachyOS).
- SSH config має broken nested Host блок + майже жодного hardening.

### Прийняті рішення
- **(K1) `1password` + `1password-cli`** (cask) — desktop + `op` CLI.
- **(K1a) Migration з Apple Passwords**: експорт через Settings → Passwords → "..." → "Export All Passwords" (CSV), імпорт у 1Password. Safari після цього: керування autofill з 1Password (extension) замість Apple Passwords. Passkeys лишаються в Apple для convenience.
- **(K2) 1Password SSH Agent integration**: `IdentityAgent` socket, global hardening блок:
  ```
  Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    ServerAliveInterval 60
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
  ```
  Існуючі ключі імпортувати в 1Password vault.
- **(K3) Виправити broken SSH config** — розпакувати nested `Host 95.216.202.206`, кожен хост окремим блоком, бажано alias-ами замість IP.
- **(K4) chezmoi + 1Password**: `secret_command = "op"` в `.chezmoi.toml.tmpl`, `{{ onepasswordRead "op://..." }}` в темплейтах.
- **(K5) Git commit signing через SSH (1Password key)**: `git config --global gpg.format ssh`, `commit.gpgsign true`. Замість gpg.
- **(K6) direnv + 1Password pattern**: `.envrc` → `export FOO="$(op read 'op://...')"`. Спільний `~/.envrc.lib` helper.
- **(K7) gpg cleanup**: якщо інше не використовується — knock down dependency.

### Skip
- sops / HashiCorp Vault — overkill для personal.
- Bitwarden / KeePassXC — обрав 1Password.
- doppler / dotenv-vault — 1Password покриває.

## Layer 7 — Backup / Browser / Capture ✅ DECIDED

### Контекст
- Backup: **повністю відсутній** (CTO-grade неприпустимо).
- Browser: Firefox + Chrome + Arc встановлені, без ролей. Firefox / Firefox Dev Edition = primary.
- Obsidian + iCloud Drive (не сумісно з CachyOS).
- Screenshots: macOS native.

### Прийняті рішення

**Backup (critical):**
- **(B1) External SSD ($80-100) + Time Machine** — купити цього тижня, увімкнути hourly auto-backup.
- **(B2) `restic` → Cloudflare R2** з launchd daemon. Daily 03:00. Encrypted. Retention 7d/4w/6m. Targets: `~/projects`, `~/Documents`, `~/.local/share/chezmoi`, Obsidian vault, JetBrains templates. Виключити: caches, node_modules, .venv, Docker volumes.

**Browser:**
- **(W1) Firefox Developer Edition** (cask `firefox@developer-edition`) → primary, замість плейн Firefox.
- **(W2) Multi-Account Containers** extension — work/personal/dev ізоляція.
- **(W3) Видалити Arc** (Browser Co припиняє розвиток) + оновити aerospace.toml binding на Firefox Dev.
- **(W4) Chrome → залишити для testing only.**

**Capture:**
- **(W5) Screenshot defaults**: `~/Pictures/Screenshots/`, png, disable-shadow.

**Defer:**
- **(D1) Obsidian sync migration** → defer до CachyOS-міграції. Тоді → Obsidian Sync ($4/міс) або Syncthing.

### Skip
- CleanShot X / Shottr — native macOS достатньо.

## Implementation phases

Реалізація має йти **знизу вгору**: критичне → фундамент → інструменти → polish. Кожна фаза = окремий implementation plan (через writing-plans), окремий PR в chezmoi.

### Phase 0 — Repo hygiene (precondition, ~1 год)
- Архівувати `github.com/norens/macos-configs`
- Видалити `~/macos-configs` (порожній bare-repo)
- Видалити stale `CLAUDE.md` в `~/IdeaProjects/macos-configs/`
- chezmoi → canonical source of truth

### Phase 1 — Безпека + дані (CRITICAL, ~3-4 год)
- **(B1)** Купити external SSD + Time Machine
- **(B2)** restic → Cloudflare R2 + launchd
- **(K1)** 1Password + 1password-cli
- **(K2)** 1Password SSH Agent + SSH config hardening (`Host *` block)
- **(K3)** Виправити broken SSH config (nested Host)
- **(Sec)** raycast `config.json` НЕ додавати в chezmoi (plaintext token)

### Phase 2 — Shell foundation (~2 год)
- **(S1)** ripgrep
- **(S2)** atuin (без sync server поки — local-only, server налаштуємо у CachyOS-міграції)
- **(S3)** direnv
- **(S4)** git-delta
- **(S5)** EDITOR/VISUAL/PAGER/MANPAGER env vars
- **(S6)** `cd→z` alias
- **(K6)** direnv + 1Password pattern (`~/.envrc.lib` helper)

### Phase 3 — Project workflow (~3 год)
- **(P1)** mise — мігрувати Node з fnm. pyenv/rbenv залишити.
- **(P2)** uv — для нових Python projects
- **(P3)** ghq — нові репи в `~/ghq/...`
- **(P4)** sesh — інтеграція з ghq
- **(S9)** sesh setup
- **(K4)** chezmoi + 1Password integration (`secret_command = "op"`)
- **(K5)** Git commit signing через SSH (1Password key)

### Phase 4 — Containers + Cloud + DevOps (~3-4 год)
- **(C1)** Migrate Docker Desktop → OrbStack
- **(C2)** k9s + kubectx + kubens + dive + stern
- **(C3)** kubeconfig hygiene
- **(Cl1-3)** wrangler, doctl, hcloud
- **(D1-D6)** opentofu + tflint + tfsec + ansible (via uv) + act + pre-commit + gitleaks + tailscale

### Phase 5 — Desktop UX polish (~2 год)
- **(Q1)** BetterDisplay (BenQ DDC/CI)
- **(Q2)** LinearMouse → замінити mos, перенастроїти Logi Options+
- **(Q3)** AltTab
- **(Q4)** Aerospace window rules (floating + per-app workspace)
- **(Q5)** workspace-to-monitor-force-assignment (BenQ primary)
- **(W1)** Firefox Developer Edition
- **(W2)** Multi-Account Containers
- **(W3)** Видалити Arc + update aerospace.toml
- **(W5)** Screenshot defaults
- **(E0)** Cleanup: Cursor, Codex, Augment, Junie, Copilot folders, Postman?, Warp?

### Phase 6 — Nice-to-have CLI (~1-2 год)
- **(S7)** btop, dust, procs, sd, tealdeer, hyperfine, yq
- **(S8)** tmux-resurrect + tmux-continuum
- **(H1)** xh
- **(DB1)** pgcli + mycli
- **(L1-L3)** mkcert, watchexec, gron

### Phase 7 — JetBrains/Claude polish (~1-2 год)
- **(E2)** JetBrains Settings Sync через account
- **(E3)** Toolbox CLI shims
- **(E5)** `~/.claude/` selectively в chezmoi
- **(E6)** Claude Desktop MCP servers config

### Phase 8 — Eventual (без deadline)
- **(P5)** Поступово мігрувати pyenv→uv legacy
- **(P6)** rbenv → mise або видалити
- **(P7)** `mise.toml` в активних проектах
- **(D1)** Obsidian sync migration (при CachyOS-переході)
- **(K7)** gpg cleanup (якщо не використовується)

## Critical files to modify

- `~/.local/share/chezmoi/dot_zshrc` — EDITOR vars, mise/atuin/direnv/zoxide eval-и, prune fnm
- `~/.local/share/chezmoi/dot_zsh_aliases` — `cd=z`, додати aliases для нових утиліт
- `~/.local/share/chezmoi/dot_ssh/config` (новий) — hardening + 1Password agent
- `~/.local/share/chezmoi/dot_config/aerospace/aerospace.toml` — window rules, monitor-assignment, прибрати Arc
- `~/.local/share/chezmoi/dot_config/brewfile/Brewfile` — додати нові casks + brews, прибрати mos/cursor/codex/postman/warp
- `~/.local/share/chezmoi/.chezmoi.toml.tmpl` (новий) — `secret_command = "op"`
- `~/Library/LaunchAgents/com.user.restic-backup.plist` (новий) — daily backup daemon
- `~/.config/restic/` (новий) — config, exclude file, R2 credentials через `op://`
- `~/.local/share/chezmoi/dot_tmux.conf` — додати tmux-resurrect/continuum plugins

## Verification

Кожна фаза має end-to-end перевірку:

- **Phase 1:**
  - `ls /Volumes` показує external SSD; `tmutil latestbackup` показує свіжий запис
  - `restic -r r2:... snapshots` показує snapshot за останню добу
  - `ssh -T git@github.com` працює без passphrase prompt (через 1Password agent)
  - `op vault list` показує items
- **Phase 2:**
  - `command -v rg atuin direnv delta` всі повертають шлях
  - `echo $EDITOR` показує `nvim`/`cursor --wait`
  - `cd ~/projects/some-repo` → zoxide tracks; `cd anywhere` працює як `z`
- **Phase 3:**
  - `mise current` показує node@22; `node --version` правильна
  - `uv venv && uv pip install requests && uv run python -c "import requests"` — без помилок
  - `ghq list | fzf` → cd in repo
  - `sesh` біндинг → tmux session per repo
- **Phase 4:**
  - `orbctl status` running
  - `k9s` запускається, видно k3s namespaces
  - `op signin && hcloud server list` працює
  - `pre-commit run --all-files` працює в одному з проектів
- **Phase 5:**
  - BenQ brightness control з клавіш macbook
  - `pgrep AltTab` running; cmd+tab показує windows-level switcher
  - Aerospace: відкрив Slack → автоматично на ws4
  - У `~/Pictures/Screenshots/` лежать нові screenshot-и
- **Phase 6-7:** smoke tests per tool

## Out of scope (окремі проекти)

- **CachyOS migration** — `cachyos-setup-tasks.md` (вже існує)
- **Cross-OS chezmoi templating** — окремий sub-project (cross-OS conditionals після того як macOS-сетап стабільний)
- **Hammerspoon-based advanced automation** — якщо знайдеться конкретний use case
