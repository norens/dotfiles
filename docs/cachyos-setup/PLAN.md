# CachyOS Setup — Plan

Повний 20-task план живе у **`~/cachyos-setup-tasks.md`** (chezmoi-tracked, commit `f254517`).

Цей файл — посилання + bootstrap-doodatok, який передує оригінальному плану.

## Bootstrap (передує Phase 2 з оригіналу)

Оригінальний план від Phase 2 передбачає CC-tasks через Claude Code на CachyOS. Перш ніж їх виконувати, потрібно:

1. Mesh-network MacBook ↔ CachyOS — **Tailscale**
2. Hardened SSH access — sshd config + 1Password agent keys
3. Claude Code installation на CachyOS

Деталі — у `STATUS.md` Bootstrap-секція + `scripts/00-bootstrap.sh`.

## Після Bootstrap

Виконуємо `~/cachyos-setup-tasks.md` Phase 2 → Phase 8 у вказаному порядку. Кожна CC-задача — окрема Claude-сесія НА CachyOS (не з macOS через SSH).
