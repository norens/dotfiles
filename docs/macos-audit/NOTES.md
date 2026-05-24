# Free-form Notes

Місце для вільних думок, ідей, спостережень, питань. Не структуроване — пиши як зручно. Періодично переглядай: те що визріло → переноси в SPEC.md / DECISIONS.md / STATUS.md.

---

## 2026-05-20

(пусто — додавай тут свої думки коли працюєш над сетапом)

## 2026-05-22

- **Джерело натхнення** для всього сетапу — Leon Si's profile на ZSA: https://people.zsa.io/leon-si
  Звідти підглянуті патерни: tiling WM (AeroSpace), Karabiner-via-Goku, SketchyBar, ghostty,
  modern CLI stack (atuin/zoxide/mise/sesh/git-delta), JetBrains + Claude Code workflow.

- **ZSA Moonlander** — є в наявності, але ще не налаштований і не в активному використанні
  (https://www.zsa.io/moonlander). Парковано через брак часу. Коли візьмуся: треба
  layout в Oryx (під Karabiner-Goku-ремапи на macOS), accustom phase ~2-3 тижні падіння
  швидкості друку. Окрема міні-фаза, не в межах поточного аудиту.

- **Home network rebuild (DE)** — паркую як окремий майбутній sub-project, поза macOS audit.
  - Поточний uplink: Vodafone-роутер (standard ISP CPE, Німеччина). Швидше за все Vodafone Station / CableLink-box.
  - Hardware в наявності: **MikroTik hAP ac lite (RB952Ui-5ac2nD)** — entry-level.
    Specs: 650 MHz single-core (QCA9533), 64 MB RAM, **5× 100 Mbit Ethernet (не gigabit!)**,
    dual-band WiFi (2.4 b/g/n 300 Mbps + 5 GHz ac 433 Mbps), RouterOS L4, USB.
    **Constraints які треба знати наперед:**
    - **100 Mbit ethernet bottleneck** — якщо Vodafone дає >100 Mbit (а в DE Kabel часто 250-1000), пристрій стане стелею. Або upgrade на hAP ax³ / RB5009, або тримати hAP ac lite тільки для VPN-SSID-сегменту, а основний uplink лишити на Vodafone-router.
    - **VPN throughput ~20-50 Mbps WireGuard** (CPU-bound, без AES hw-accel) — для phone/IoT нормально, для PC streaming через VPN — мало.
    - **64 MB RAM** — pi-hole/AdGuard прямо на пристрої не варто; DNS-blocking краще через RouterOS built-in або на іншому host-i.
    - WiFi 5 GHz тільки 433 Mbps — для нової стелі не топ, але "VPN-SSID для phone/IoT" задовольняє.
  - Цілі:
    1. MikroTik за Vodafone-роутером → MacBook + PC (CachyOS) у власній локальній мережі (file share, SSH без NAT-traversal, можливо Tailscale subnet router).
    2. Окрема Wi-Fi SSID, увесь трафік якої виходить через VPN (для phone / IoT / "everything-through-VPN" devices).
    3. Bonus ідеї: pi-hole / AdGuard DNS, mDNS reflector між segment-ами, guest SSID, WireGuard server на MikroTik для віддаленого доступу додому.
  - Відкриті питання для майбутнього brainstorm:
    - Single vs double NAT (Vodafone box у bridge-mode? більшість DE ISP CPE цього не дають) → визначає чи MikroTik working as router або тільки as L2 switch + AP-controller.
    - VPN provider (Mullvad / ProtonVPN / власний WireGuard на VPS) + kill-switch на MikroTik рівні (PBR + drop rule).
    - WiFi: MikroTik вбудований чи окрема AP (UniFi U6+ / AX-class).
    - mDNS / Bonjour між segment-ами (AirPlay, AirPrint) — потребує `igmp-proxy` або avahi-reflector.
  - Коли почнемо проектувати — окремий `docs/home-network/` workspace (за аналогією з `docs/cachyos-setup/`).
  - **Архітектурне рішення (2026-05-23): Варіант A — без upgrade hardware.**
    Vodafone-роутер лишається edge router. hAP ac lite ставимо за ним як **VPN-gateway + AP**
    для окремого VPN-SSID. MacBook/PC лишаються на Vodafone-LAN (не за MikroTik).
    Наслідок: ціль "MikroTik-managed LAN MacBook↔PC" фактично **відпадає** — вони бачать одне
    одного через Vodafone-DHCP (досить включити File Sharing на macOS + smbd на CachyOS).
    Якщо колись захочеться real-LAN-фіч (VLAN, firewall rules, traffic shaping між хостами) —
    повертаємось до Варіанту B (upgrade на hAP ax³ / RB5009).
  - Відкрите для майбутнього brainstorm (під Варіант A):
    - VPN provider: Mullvad / ProtonVPN / власний WireGuard на Hetzner VPS?
    - Чи додавати MacBook/PC у VPN-SSID коли потрібно (split-tunnel за SSID), чи робити це через WG-client на самих хостах?
    - DNS-blocking для VPN-SSID: RouterOS adlist чи DNS-провайдер з блокуванням (NextDNS/Mullvad-DNS)?
    - Kill-switch на MikroTik: routing-mark + drop rule якщо WG-peer down.
