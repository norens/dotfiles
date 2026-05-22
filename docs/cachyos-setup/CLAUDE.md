# CachyOS Setup — Workspace

## Що це

Активний проект — bootstrap та CC-driven setup нового PC з CachyOS (RTX 5070 Ti + Ryzen 7800X3D).

Заходити сюди для роботи над CachyOS-проектом:
```bash
cd ~/.local/share/chezmoi/docs/cachyos-setup
claude
```

## Файли

- **CLAUDE.md** — цей файл, context для AI
- **PLAN.md** — посилання на оригінальний `~/cachyos-setup-tasks.md` (20-task план)
- **STATUS.md** — phase-by-phase прогрес
- **NOTES.md** — вільні нотатки
- **scripts/** — bootstrap + helper-скрипти для CachyOS

## Контекст користувача

Див. memory + `docs/macos-audit/CLAUDE.md` для повного профілю. Коротко:
- nazar, full-stack (BE+FE+ML+DevOps), українська мова
- macOS primary поки що, CachyOS — secondary з ML/local-LLM фокусом
- chezmoi → norens/dotfiles canonical (cross-OS templating очікується)
- 1Password (paid) — SSH agent + secrets backend
- Hetzner k3s production, Cloudflare R2 (backups), DigitalOcean

## Архітектура двох сесій

- **macOS Claude session** (тут) — координація, генерація скриптів, dotfiles editing у chezmoi
- **CachyOS Claude session** (запускається на самому Linux) — виконання native CC tasks #2-#20 з PLAN

Передача стану між сесіями — через chezmoi-репо (auto-sync на GitHub). У цьому workspace всі docs синхронізуються.

## SSH-доступ MacBook → CachyOS

Через **Tailscale mesh**, не direct LAN/public IP:
- Tailscale на обох → magic-DNS дає `ssh <hostname>` з будь-якої мережі
- SSH ключі живуть у 1Password agent (на macOS) → Touch ID при connect
- CachyOS user має authorized_keys з 1P-exposed public key
- sshd на CachyOS: pubkey-only, no password, ban root login

## Out of scope (тут)

- macOS-аудит = окремий [project-macos-audit] у `docs/macos-audit/`
- Production k3s конфігурація = окремо (Hetzner servers, не цей PC)

## Robocha послідовність (рекомендована)

1. Bootstrap (цей workspace coordinates):
   - Tailscale на обох
   - sshd hardening на CachyOS
   - claude-code на CachyOS
2. Перехід CachyOS-driven: користувач відкриває `claude` НА CachyOS і виконує CC tasks #2-#20 з оригінального плану
3. macOS-Claude сюди заходить тільки для cross-OS coordination (chezmoi templating, документація)
