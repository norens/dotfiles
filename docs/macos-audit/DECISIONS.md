# Decisions Log

Лог прийнятих рішень з обґрунтуванням. Коли рішення змінюється — додати новий запис, старий лишити (audit trail).

## 2026-05-20 — Initial audit

### chezmoi як canonical (vs bare-repo `macos-configs`)
**Контекст**: дві паралельні системи — chezmoi (`~/.local/share/chezmoi` → `norens/dotfiles`) і bare-repo (`~/macos-configs` → `norens/macos-configs`). Bare-repo legacy з часів yabai/skhd.
**Вибрано**: chezmoi. **Чому**: cross-OS templating (потрібно для майбутнього CachyOS), активно використовується, реальний source-of-truth.

### 1Password (vs Bitwarden / KeePassXC / Apple Passwords)
**Контекст**: користувач на Apple Passwords. Треба SSH agent + chezmoi secrets + cross-OS (macOS + CachyOS).
**Вибрано**: 1Password (paid $3/міс). **Чому**: найзріліший SSH agent, найкраща UX, native chezmoi integration через `onepasswordRead` template func. Apple Passwords не вміє SSH agent і не працює на Linux.
**Альтернативи розглянуто**: Bitwarden free (SSH agent в beta, OK fallback якщо $3/міс стане проблемою), KeePassXC (повністю OSS але manual sync), Apple Passwords (недостатньо).

### OrbStack (vs Docker Desktop / Colima)
**Вибрано**: OrbStack. **Чому**: macOS-native, faster, free for personal, drop-in replacement Docker Desktop.

### restic (vs borg / Time Machine only)
**Вибрано**: restic + Time Machine (комбінація). **Чому**: restic працює cross-platform (macOS + CachyOS), encrypted, incremental, інтегрується з S3-сумісним R2. Time Machine — local recovery для macOS-specific артефактів.

### Cloudflare R2 (vs S3 / B2 / iCloud)
**Вибрано**: R2. **Чому**: користувач уже на Cloudflare, R2 має zero egress fees (важливо для restore), S3-compatible API.

### mise (vs asdf / volta / individual managers)
**Контекст**: зараз fnm + pyenv + rbenv окремо.
**Вибрано**: mise. **Чому**: один tool для node/python/ruby/go/java/rust, активно розвивається (Rust-based, швидкий), повна підтримка `.tool-versions`.

### Firefox Developer Edition primary (vs Arc / Chrome)
**Вибрано**: Firefox Dev Edition. **Чому**: Arc припиняє розвиток (Browser Company → Dia). Chrome — Google telemetry. Firefox Dev — найкращий devtools + privacy + Containers extension.

### nano не nvim
**Вибрано**: лишити nano. **Чому**: vim learning curve без конкретного use case = waste. Користувач ніколи не використовував vim.

### JetBrains primary, без Cursor/VSCode
**Вибрано**: видалити Cursor + Codex + Augment + Junie + Copilot. **Чому**: shelfware. Один primary editor + один primary AI (Claude) = чистий workflow.

### tailscale (vs self-hosted WireGuard)
**Вибрано**: tailscale free tier. **Чому**: до 100 девайсів безкоштовно, zero-config mesh, SSO логін.

### opentofu (vs terraform)
**Вибрано**: opentofu. **Чому**: OSS форк після зміни ліцензії HashiCorp, drop-in replacement.

### Hammerspoon — пропустили
**Чому**: без конкретного use case Lua scripting overkill. aerospace + sketchybar покривають 90% потреб.
