# macOS Dev Environment Audit — Workspace

## Що це

Постійний робочий простір для **macOS dev environment audit** проекту. Користувач (nazar) проводить структурний аудит свого macOS-сетапу для досягнення "CTO-grade" workflow.

Цей folder — місце куди користувач заходить (`cd ~/docs/macos-audit && claude`) щоб продовжити роботу над цим проектом між сесіями.

## Файли тут

- **SPEC.md** — повний design doc з рішеннями по 7 шарах + 8 phases. Це source-of-truth. Якщо рішення змінюється — оновити тут.
- **STATUS.md** — прогрес-чекліст по фазах. Що зроблено, що в роботі, що блоковано чим.
- **DECISIONS.md** — лог "чому ми обрали X замість Y" (1Password vs Bitwarden, OrbStack vs Docker Desktop тощо). Майбутньому-нам корисно.
- **NOTES.md** — вільні нотатки користувача. Спостереження, ідеї, питання.
- **CLAUDE.md** — цей файл.

Оригінальний plan-файл живе в `~/.claude/plans/cosmic-yawning-papert.md` — це snapshot з brainstorm-сесії. SPEC.md — поточна актуальна версія.

## Контекст користувача

- **Роль**: full-stack розробник (Backend + Frontend + ML + DevOps).
- **Hardware**: MacBook + майбутній CachyOS PC (RTX 5070 Ti, Ryzen 7800X3D), MX Master 4, BenQ PD2730S.
- **Cloud**: Cloudflare + Hetzner + DigitalOcean. **k3s self-hosted на Hetzner** (production).
- **Primary IDE**: JetBrains Toolbox (IntelliJ/PyCharm/WebStorm/GoLand).
- **Primary AI**: Claude (Claude Code CLI + Claude Desktop).
- **Editor для quick edits**: nano (vim не використовує).
- **Password manager**: переходить з Apple Passwords на 1Password (paid).
- **Dotfiles**: chezmoi → `github.com/norens/dotfiles` (canonical).
- **Кириличний/український інтерфейс комунікації** — відповідай українською.

## Як з цим працювати

**На початку сесії**: прочитай SPEC.md (поточний стан) і STATUS.md (прогрес). Не питай повторно те, що там вже зафіксовано.

**Коли користувач каже "продовжуємо Phase X"**: відкрий STATUS.md, знайди фазу, виконуй наступні незавершені кроки. Оновлюй STATUS.md по ходу.

**Коли користувач хоче змінити рішення**: оновлюй SPEC.md (нове рішення) + додавай запис у DECISIONS.md (чому змінили).

**Коли користувач задає вільне питання / закидає ідею**: думай чи має воно вплив на SPEC. Якщо так — пропонуй оновити SPEC. Якщо просто думка — пиши в NOTES.md.

## Не плутати з

- `~/cachyos-setup-tasks.md` — окремий проект (міграція на CachyOS PC). Не цей.
- `~/.local/share/chezmoi/CLAUDE.md` — інструкції для всього chezmoi-репо. Цей CLAUDE.md (`docs/macos-audit/`) — specific для аудит-проекту.

## Out-of-scope

- CachyOS migration — окремий план.
- Cross-OS chezmoi templating — окремий sub-project (після стабілізації macOS).
- Hammerspoon — без use case, не робимо.
