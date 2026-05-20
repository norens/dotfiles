# CachyOS Setup — Послідовність задач

**Легенда:**
- 🧑 **HUMAN** — фізично робиш сам (BIOS, фізичні дії, рішення)
- 🤖 **CC** — задача для Claude Code (конфіги, скрипти, debugging)
- ⚡ **HYBRID** — ти запускаєш команду, CC підготовлює її і пояснює

---

## PHASE 0 — Pre-install у Windows (зараз)

### 🧑 0.1 Windows preparation (~30 хв)
```powershell
# Все у admin PowerShell
manage-bde -status                    # перевірити BitLocker
manage-bde -off C:                    # якщо ON — вимкнути, дочекатись decrypt
powercfg /h off                       # вимкнути hibernate
# Control Panel → Power Options → "Choose what power buttons do" → uncheck Fast Startup
```

### 🧑 0.2 Shrink Windows partition (~15 хв)
- Win+R → `diskmgmt.msc`
- ПКМ на C: → Shrink Volume
- Залишити Windows ~250 GiB, звільнити решту (700+ GiB під Linux)
- **Не створюй там нічого** — Calamares сам розіб'є

### 🧑 0.3 Rufus — флешка (вже робиш)
- **Partition scheme: GPT** (зміни з MBR)
- Target: UEFI (non CSM)
- START → ISO mode

### 🧑 0.4 BIOS settings (reboot → Del/F2)
```
Above 4G Decoding         → ON
Re-Size BAR Support       → ON
SVM Mode (AMD-V)          → ON
Secure Boot               → OFF (поки)
CSM                       → OFF
Fast Boot                 → OFF
EXPO/DOCP RAM profile     → Profile 1
Boot priority             → USB перший
```

### 🤖 0.5 [CC TASK #1] Підготувати dotfiles repo
**Промт для Claude Code (запускай ще з MacBook):**
```
Створи новий приватний GitHub repo "dotfiles" і налаштуй chezmoi у ньому.
Структура має підтримувати cross-OS (macOS + Linux) через templating.
Перенеси мою поточну конфігурацію з ~/.config (Ghostty, tmux, nvim, zsh, starship)
у chezmoi-формат з умовними блоками {{ if eq .chezmoi.os "darwin" }}.
Додай README з instructions для bootstrap на новій машині.
```

---

## PHASE 1 — Базова інсталяція CachyOS (~1.5 год)

### 🧑 1.1 Boot з флешки
- F11/F12 під час POST → вибрати USB
- У GRUB-меню CachyOS → "Boot CachyOS Live"
- Дочекатись завантаження desktop

### 🧑 1.2 Calamares installer — критичні вибори
| Крок | Вибір |
|---|---|
| Keyboard | English (US) |
| Timezone | Europe/Berlin |
| Partitioning | **Manual** (не Erase!) |
| ESP partition | Існуючий Windows EFI → mount `/efi`, **format=NO** |
| Root | Новий розділ з вільного місця → btrfs, mount `/` |
| Subvolumes | Default CachyOS схема (`@`, `@home`, `@.snapshots`, `@var`) |
| Bootloader | **Limine** |
| Desktop | **Hyprland** |
| Shell | zsh |
| Username | `nazar` (як на macOS — важливо для path-parity) |
| Hostname | `scople-dev` (або як любиш) |

### 🧑 1.3 First boot перевірка
- Reboot, витягни флешку
- Limine має показати: CachyOS + Windows
- Обери CachyOS → логін → відкрий термінал
- `nvidia-smi` → має показати RTX 5070 Ti, driver 580.xx
- `cat /sys/module/nvidia_drm/parameters/modeset` → `Y`

**Якщо щось не так — стоп, пиши що бачиш, далі не йди.**

---

## PHASE 2 — NVIDIA + CUDA verification (~1 год)

### ⚡ 2.1 Verify stack
```bash
nvidia-smi                            # 580.xx, 16 GiB
nvcc --version                        # CUDA 13.0 або 12.9
echo $XDG_SESSION_TYPE                # wayland
```

### 🤖 2.2 [CC TASK #2] Налаштувати NVIDIA kernel params
**Промт:**
```
Я на CachyOS з RTX 5070 Ti (Blackwell). Налаштуй оптимальні modprobe parameters
для nvidia-open driver. Створи /etc/modprobe.d/nvidia.conf з NVreg_PreserveVideoMemoryAllocations=1,
fbdev=1, modeset=1. Онови mkinitcpio.conf щоб модулі nvidia, nvidia_modeset,
nvidia_uvm, nvidia_drm були у MODULES=(). Запусти mkinitcpio -P. Покажи мені diff
кожного файлу перед застосуванням.
```

### 🤖 2.3 [CC TASK #3] Container GPU passthrough
**Промт:**
```
Встанови та налаштуй Podman rootless з nvidia-container-toolkit.
Згенеруй CDI specification. Запусти тестовий container nvcr.io/nvidia/cuda:13.0.0-base
з nvidia-smi. Якщо щось не працює — задебаж та пофікси.
```

---

## PHASE 3 — Keyboard parity з macOS (~3 год, найважливіше)

### 🧑 3.1 Знайди ідентифікатор клавіатури
```bash
ls /dev/input/by-id/ | grep -i kbd
```
Скопіюй точний шлях — він потрібен для kanata.

### 🤖 3.2 [CC TASK #4] Kanata setup (CRITICAL)
**Промт (передай Claude шлях з 3.1):**
```
Встанови kanata з AUR. Налаштуй systemd-сервіс що запускає kanata як root з доступом
до /dev/uinput. Створи групу uinput, додай мене, налаштуй udev rule.

Конфіг kanata має:
1. Замінити Caps Lock на Escape (одне натискання) / Ctrl (hold)
2. Зробити лівий Alt → Meta (Super), тобто фізична клавіша біля пробілу стає
   "Cmd-аналогом" для macOS-style шорткатів
3. Зберегти правий Alt як AltGr для umlauts і української

Клавіатура: <ШЛЯХ З 3.1>

Покажи конфіг перед встановленням, дай мені перевірити, потім встанови.
Перевір що сервіс стартує без помилок.
```

### 🤖 3.3 [CC TASK #5] Hyprland macOS-style binds
**Промт:**
```
Перепиши мій ~/.config/hypr/hyprland.conf на основі CachyOS-default так, щоб:

1. $mod = SUPER (після kanata = моя "Cmd")
2. Cmd+Space → запуск Walker (поставити walker-bin з AUR)
3. Cmd+Tab → cyclenext (app switching)
4. Cmd+Q → killactive
5. Cmd+W → close window
6. Cmd+C/V у Ghostty транслювати в Ctrl+Shift+C/V через sendshortcut,
   у браузерах/Obsidian/VSCode — Ctrl+C/V
7. Cmd+Shift+4 → hyprshot region (поставити hyprshot, satty)
8. Cmd+Shift+3 → hyprshot output
9. Cmd+H → minimize (через special workspace)
10. Cmd+, → відкрити налаштування активного вікна
11. Workspaces: Cmd+1..9 → перехід; Cmd+Shift+1..9 → перенести вікно

Тема — Catppuccin Mocha (як на macOS). Налаштуй Waybar з Catppuccin, mako для
нотифікацій, hyprlock для locker. Show me the diff перед apply.
```

### 🧑 3.4 Test drive — 30 хвилин просто покористуйся
Відкрий браузер, Ghostty, потести шорткати. Що болить — занотуй, передаси CC окремо. **Не йди далі поки 80% мускульної памʼяті не працює.**

---

## PHASE 4 — Dev environment (~2 год)

### 🤖 4.1 [CC TASK #6] CLI stack + shell
**Промт:**
```
Встанови з pacman/AUR: eza, bat, ripgrep, fd, zoxide, fzf, delta, btop, dust,
procs, sd, tealdeer, direnv, atuin, mise, paru, starship, jq, yq.

Налаштуй мій ~/.zshrc:
- starship prompt з Catppuccin Mocha
- aliases: ls→eza, cat→bat, cd→z (zoxide)
- direnv hook
- atuin init (поки local, sync server налаштуємо пізніше)
- mise activate
- FZF key-bindings

Імпортуй мій zsh-history з MacBook (я скопіюю файл у ~/zsh_history_mac.txt
заздалегідь — оброби його через atuin import).
```

### 🤖 4.2 [CC TASK #7] Chezmoi bootstrap
**Промт:**
```
Встанови chezmoi. Зроби `chezmoi init --apply git@github.com:norens/dotfiles.git`.
Перевір що шляхи коректно резолвляться через templating (Linux vs macOS блоки).
Якщо щось конфліктує з CachyOS-defaults — покажи мені diff перед merge.

Особливо перевір:
- ~/.config/ghostty/config (має бути ідентичний macOS)
- ~/.config/tmux/tmux.conf
- ~/.config/nvim/ (LazyVim)
- ~/.zshrc
- ~/.gitconfig
```

### 🤖 4.3 [CC TASK #8] Language toolchains
**Промт:**
```
Через mise встанови globally: node@22, pnpm@latest, python@3.12, go@1.23,
rust stable, bun@latest, deno@latest.
Налаштуй corepack enable. Перевір що pnpm workspaces працюють.
Додай ~/.local/share/mise/shims у PATH.

Також встанови uv (для Python venv ML-проєктів).
```

### 🤖 4.4 [CC TASK #9] Editors
**Промт:**
```
Встанови:
- visual-studio-code-insiders-bin з AUR
- cursor-bin з AUR
- neovim (вже має бути) + LazyVim starter
- zed з AUR

Для VSCode/Cursor — увімкни Settings Sync через GitHub.
Перевір що Claude Code extension встановлений і працює.

Налаштуй xdg-mime defaults так щоб .md, .ts, .tsx, .py відкривалися у VSCode Insiders.
```

### 🤖 4.5 [CC TASK #10] 1Password + SSH
**Промт:**
```
Встанови 1password з AUR. Налаштуй SSH agent integration через
~/.1password/agent.sock (~/.ssh/config має містити IdentityAgent для всіх хостів).
Імпортуй мої SSH ключі з 1Password vault.
Перевір `ssh -T git@github.com` працює без password prompt.
```

---

## PHASE 5 — ML stack (~1.5 год)

### 🤖 5.1 [CC TASK #11] Ollama
**Промт:**
```
Встанови ollama (через official script або AUR — оціни що стабільніше для RTX 5070 Ti
sm_120 у травні 2026, перевір останні GitHub issues #13163 та подібні).
Якщо є sm_120 регресія в latest — pin на 0.12.10.
Запусти ollama serve як systemd-user-сервіс.
Зроби `ollama pull qwen2.5:14b` та бенчмарк tok/s через ollama run --verbose.
Очікувано: 30-40 tok/s на 14B Q4. Якщо нижче — задебаж.
```

### 🤖 5.2 [CC TASK #12] llama.cpp manual build
**Промт:**
```
Склонуй ggml-org/llama.cpp, збилди з CUDA_ARCHITECTURES=120 для Blackwell.
Покажи бенчмарк на тій самій моделі що Ollama (через GGUF) щоб порівняти.
Створи alias `llama-server` що стартує server з оптимальними параметрами для 5070 Ti.
```

### 🤖 5.3 [CC TASK #13] PyTorch nightly verification
**Промт:**
```
У свіжому uv-venv встанови torch nightly з cu128 index:
uv pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

Запусти smoke test:
- torch.cuda.is_available() → True
- torch.cuda.get_device_name(0) → RTX 5070 Ti
- Перемнож дві матриці 4096x4096 на GPU, заміряй час
- Перевір що backward pass працює (простий MLP, dummy data)
```

---

## PHASE 6 — Apps + локалізація (~1 год)

### 🤖 6.1 [CC TASK #14] Application install
**Промт:**
```
Встанови з відповідних джерел (обери оптимальне — AUR/Flatpak/native):
- obsidian (наlинкуй мій vault з ~/Documents/ObsidianVault через Obsidian Sync)
- telegram-desktop
- slack або slack-desktop (через Flatpak)
- discord
- spotify
- zoom
- localsend-bin
- zen-browser-bin (primary) + firefox-developer-edition (secondary)
- chromium (для тестів)

Не ставити нічого зайвого. Перевір що кожен запускається.
```

### 🤖 6.2 [CC TASK #15] Ukrainian input + fonts
**Промт:**
```
1. Налаштуй Hyprland kb_layout = "us,ua" з перемиканням через Right_Ctrl
   (не Win+Space — конфлікт з Walker)
2. Встанови шрифти: noto-fonts, noto-fonts-cjk, noto-fonts-emoji,
   ttf-jetbrains-mono-nerd, inter-font, adobe-source-sans-fonts
3. Налаштуй locale: LANG=en_US.UTF-8, LC_TIME=uk_UA.UTF-8
4. Перевір що українська друкується в Ghostty, Firefox, Obsidian
```

### 🤖 6.3 [CC TASK #16] ESP32 toolchain
**Промт:**
```
Встанови esp-idf-git, platformio-core, arduino-ide з AUR.
Додай мене у групи uucp, dialout.
Скачай та встанови офіційні udev rules з platformio.org/install/udev-rules.
Підключи мій ESP32-CAM, перевір що /dev/ttyUSB0 видно і pio device list його бачить.
```

---

## PHASE 7 — Backup + snapshots (~1 год)

### 🤖 7.1 [CC TASK #17] Snapper + pacman-hook
**Промт:**
```
Налаштуй snapper для @ subvolume з timeline cleanup (зберігати 10 hourly,
10 daily, 5 weekly, 3 monthly).
Створи pacman-hook /etc/pacman.d/hooks/50-bootbackup.hook що робить pre-snapshot
перед кожним -Syu.
Перевір що Limine bootloader бачить snapshots у menu (limine-snapper-sync).
Зроби тестовий snapshot, зміни щось, rollback, переконайся що працює.
```

### 🤖 7.2 [CC TASK #18] Off-site backup
**Промт:**
```
Налаштуй restic backup ~/projects, ~/Documents, ~/.config/chezmoi на Cloudflare R2.
Bucket вже існує: <BUCKET_NAME>. Credentials у 1Password під "Cloudflare R2 Backup".
Створи systemd-user timer що робить backup кожен день о 03:00.
Налаштуй retention policy: keep 7 daily, 4 weekly, 6 monthly.
Перевір restore процедуру на тестовому файлі.
```

---

## PHASE 8 — Polish (коли є час)

### 🤖 8.1 [CC TASK #19] Power, dual-boot fixes
**Промт:**
```
1. timedatectl set-local-rtc 1 --adjust-system-clock (фікс RTC drift з Windows)
2. Встанови power-profiles-daemon, вистав "performance" як default
3. Перевір що /etc/fstab опції btrfs оптимальні: noatime,compress=zstd:3,ssd,discard=async
4. Створи recovery USB ISO image: запиши CachyOS ISO на запасну флешку через dd
```

### 🤖 8.2 [CC TASK #20] Gaming (опційно)
**Промт:**
```
Встанови steam, proton-cachy, gamescope, mangohud, lutris.
Налаштуй Sunshine для streaming на MacBook через Moonlight.
Перевір на одній грі з моєї бібліотеки (запитай яку).
```

---

## Cheat sheet — порядок задач для CC

Коли сядеш за CachyOS, просто кидай задачі в Claude Code у цьому порядку:

```
CC #1   → dotfiles repo (роби з macOS перед інсталом)
─── INSTALL CACHYOS ───
CC #2   → NVIDIA modprobe
CC #3   → Podman + nvidia-container-toolkit
CC #4   → kanata (CRITICAL)
CC #5   → Hyprland binds
─── TEST DRIVE 30 MIN ───
CC #6   → CLI stack
CC #7   → chezmoi bootstrap
CC #8   → language toolchains
CC #9   → editors
CC #10  → 1Password SSH
CC #11  → Ollama
CC #12  → llama.cpp
CC #13  → PyTorch nightly
CC #14  → apps
CC #15  → Ukrainian + fonts
CC #16  → ESP32
CC #17  → snapper
CC #18  → restic
CC #19  → polish
CC #20  → gaming (опційно)
```

---

## Що пам'ятати про роботу з CC у цьому setup

1. **Завжди вимагай diff перед apply.** На fresh install одна неправильна правка `/etc/fstab` або mkinitcpio = непідйомна система.
2. **Snapshot перед кожною CC-сесією що чіпає systemd/kernel/bootloader.** `sudo snapper -c root create -d "before CC task #X"`.
3. **CC має повний доступ до sudo через NOPASSWD?** Якщо ні — він буде губити команди. Налаштуй або давай йому копіювати команди для тебе вручну.
4. **Передавай контекст по hardware.** Кожна задача почни з рядка "Я на CachyOS, RTX 5070 Ti Blackwell sm_120, Ryzen 7800X3D, Hyprland Wayland, kernel linux-cachyos".
5. **Не дай CC ставити kernel modules з .run installers, не дай чіпати UEFI/efibootmgr без подвійної перевірки.** Це червоні зони.

Удачі. Як буде Phase 1 готова — пиши, далі допоможу з кожним CC-task окремо.
