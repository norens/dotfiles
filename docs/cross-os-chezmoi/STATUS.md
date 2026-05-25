# Cross-OS chezmoi Migration — Status

**Status:** COMPLETE (2026-05-25)

## Outcome

Both machines (MacBook + CachyOS nazarf-cachyos) now use chezmoi from the same `norens/dotfiles` repo with `.chezmoiignore.tmpl` filtering macOS-only and Linux-only paths per host.

## Plan 2 commits (chronological)

- `ed9e268` — feat(chezmoi): templated .chezmoiignore with OS guards
- `4a505d9` — feat(zsh): skeleton dot_zsh/{shared,darwin,linux}.zsh fragments
- `f98384e` — feat(ssh): template IdentityAgent per OS (1Password socket path)
- `b47d7e8` — feat(zsh): populate shared.zsh from dot_zshrc cross-OS lines
- `9100b65` — fix(zsh): add thefuck (guarded) — missing from initial T5 heredoc
- `f71b000` — feat(zsh): populate darwin.zsh from dot_zshrc macOS-only lines
- `7787fc9` — feat(zsh): replace dot_zshrc with thin loader (sources ~/.zsh/{shared,os}.zsh)
- `150e28a` — fix(chezmoi): add .config/brewfile to macOS-only ignore (Brewfile is macOS-only)
- `28170ff` — feat(zsh): populate linux.zsh from CachyOS-specific bits + Plan-1 ML env
- `d79b543` — feat(containers): promote ollama.container + storage.conf into chezmoi
- `e2fb876` — feat(bootstrap): update CachyOS script + add macOS bootstrap (chezmoi init --apply)

## Final verification (Task 12, 2026-05-25)

| Check | MacBook | CachyOS |
|---|---|---|
| `chezmoi diff` clean (no NEW Plan-2 drift) | PASS (only pre-existing drift) | PASS (empty) |
| `zsh -i -c "echo OK"` exits 0 | PASS | PASS |
| starship / zoxide / mise / atuin / direnv all report versions | PASS | PASS |
| `chezmoi managed` count | 140 | 65 |
| macOS-only paths managed only on Mac | PASS | PASS |
| Linux-only paths managed only on Linux | PASS | PASS |
| Linux env (HF_HOME / PODMAN_USERNS / EDITOR) correct on CachyOS | — | PASS |
| Ollama service still `active` + container `Up` | — | PASS |

## Known follow-ups (non-blocking)

- CachyOS chezmoi remote is HTTPS (read-only). All future cross-OS commits must originate on MacBook + `chezmoi update` on CachyOS, or reconfigure CachyOS remote to SSH once 1Password Linux + SSH-key are set up.
- Pre-existing repo drift on MacBook (Brewfile, `.ssh/config` OrbStack lines, `Library/Preferences/com.apple.HIToolbox.plist`, `docs/macos-audit/NOTES.md` edits, untracked `docs/` tree subdirs) is NOT caused by Plan 2 — out of scope here.
- Step 9 (git SSH-signing smoke test) was aborted on timeout: user is AFK, Touch ID prompt would have blocked. Signing not confirmed in this session; previous commits in the repo are signed (1P-agent works), so no regression suspected — re-run interactively to confirm.
- Catppuccin `FZF_DEFAULT_OPTS` theme from the old CachyOS `.zshrc` was dropped (Gruvbox is the repo-wide aesthetic). Re-add via `~/.zsh/local.zsh` on CachyOS if desired.
- `zle "can't change option"` warnings under `zsh -i -c "..."` are pre-existing non-interactive-mode noise, not regressions.
