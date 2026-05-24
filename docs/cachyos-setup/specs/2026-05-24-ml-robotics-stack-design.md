# ML / Robotics Stack on CachyOS — Design

**Date:** 2026-05-24
**Status:** Draft, awaiting user review
**Hardware:** RTX 5070 Ti (Blackwell, sm_120, 16 GiB VRAM), Ryzen 7800X3D, CachyOS + Hyprland Wayland
**Approach:** Container-first (Option A from brainstorm 2026-05-24)
**Supersedes:** `~/cachyos-setup-tasks.md` Phase 5 (Ollama / llama.cpp / PyTorch nightly)

This design extends the existing 20-task CachyOS plan (`~/cachyos-setup-tasks.md`) with an ML and humanoid-robotics workflow. It is **additive** to that plan, not a replacement, except where noted (Phase 5 is replaced; new Phases 1.5 and 5b are inserted).

---

## 1. Scope & goals

### In scope

- **Local LLM inference** for personal use and project integration: Qwen / Llama / Gemma up to 14B via Ollama; on-demand vLLM serving for OpenAI-compatible API.
- **Local fine-tuning** with HuggingFace stack (transformers, PEFT, TRL): LoRA up to 13B (QLoRA for larger).
- **Isaac Sim 5.x + Isaac Lab 2.x** humanoid RL: baseline locomotion tasks for Unitree H1 / G1, manipulation on GR1 as stretch.
- **Isaac-GR00T N1.7** inference (NVIDIA's open VLA model for generalist humanoid skills); LoRA fine-tune as stretch goal.
- **Remote-training UX:** start an 8-hour training run, close the laptop, reattach from MacBook from anywhere via Tailscale.
- **Networking:** access local LLMs from MacBook, from apps running on Hetzner k3s, and (selectively) from public Internet.

### Out of scope

- Multi-GPU training (single 5070 Ti).
- Distributed training across machines.
- Production model serving (lives on Hetzner k3s, not this PC).
- Real physical-robot integration (sim only for now).
- Custom kernel patches or .run-installer NVIDIA drivers — only nvidia-open from pacman.

### Hardware constraint reminder

16 GiB VRAM is the hard ceiling. Concretely:

| Workload | Status on 16 GiB |
|---|---|
| LLM inference up to 14B Q4 | ✅ comfortable |
| LLM serving via vLLM (≤8B FP16, ≤14B FP8/AWQ) | ✅ |
| HuggingFace LoRA fine-tune up to 7B | ✅ |
| HuggingFace LoRA fine-tune 13B (QLoRA + gradient ckpt) | ✅ tight |
| Isaac Lab humanoid RL, reduced envs (1024–2048) | ✅ |
| Isaac-GR00T N1.7 inference | ✅ at threshold |
| Isaac-GR00T full fine-tune | ❌ wants 40 GiB+; only aggressive LoRA + 4-bit |

**One heavy workload at a time.** Don't run Isaac training and vLLM serving concurrently.

---

## 2. Storage layout (btrfs)

The CachyOS Calamares default creates `@`, `@home`, `@.snapshots`, `@var`. **Add two more subvols before any ML data lands** to avoid migrating later.

### Subvol table

| Subvol | Mount | Mount opts | Snapper |
|---|---|---|---|
| `@` | `/` | `noatime,compress=zstd:3,ssd,discard=async` | yes |
| `@home` | `/home` | `noatime,compress=zstd:3,ssd,discard=async` | yes |
| `@.snapshots` | `/.snapshots` | (default) | n/a |
| `@var` | `/var` | `noatime,compress=zstd:3` | yes |
| **`@ml-data`** (NEW) | `/home/nazar/ml-data` | `nodatacow,noatime,compress=no,ssd,discard=async` | **NO** (excluded) |
| **`@containers`** (NEW) | `/var/lib/containers` | `nodatacow,noatime,compress=no,ssd,discard=async` | **NO** (excluded) |

### Layout under `~/ml-data`

```
~/ml-data/
├── hf-cache/         # symlinked from ~/.cache/huggingface (HF_HOME)
├── isaac-cache/      # Omniverse Nucleus cache (NUCLEUS_CACHE)
├── datasets/         # personal datasets for fine-tuning
├── checkpoints/      # output trained models (THIS is what restic backs up)
└── logs/             # GPU/temp logs, tensorboard event files
```

### Rationale

- **`nodatacow`:** btrfs CoW + huge mutating files (model weights, dataset shards, container layers) fragments catastrophically over weeks. `nodatacow` disables it for these dirs.
- **Excluded from snapper:** ML cache 500 GB × 10 snapshots = 5 TB of phantom space. Snapper is for system + dotfiles, not bulk binary data. Configure in `/etc/snapper/configs/home` via `SUBVOLUME_EXCLUDE` or simply don't add `@ml-data` as a snapper config.
- **`/var/lib/containers` on its own subvol:** Podman image storage; same fragmentation argument. Also lets you wipe containers without touching `/var` snapshots.

### Disk budget (of the 700+ GB Linux partition)

| Subvol | Target size |
|---|---|
| `@` | 80 GB |
| `@home` (without ML data) | 100 GB |
| `@.snapshots` | 50 GB |
| `@var` (without containers) | 30 GB |
| `@containers` | 100 GB |
| `@ml-data` | remainder (350+ GB) |

These are not partitions — btrfs subvols share the same FS pool. Sizes are advisory budgets monitored via `btrfs filesystem usage /`.

### Implementation

New phase **1.5 — ML storage layout** runs after Phase 1 first boot, before Phase 2 NVIDIA. Tasks:

1. From a live USB or single-user mode (to avoid in-use `/`): create `@ml-data` and `@containers` subvols.
2. Add `/etc/fstab` entries with the opts above.
3. Bind-mount `~/.cache/huggingface` → `~/ml-data/hf-cache` via symlink, set `HF_HOME=~/ml-data/hf-cache` in zsh.
4. Configure `/etc/containers/storage.conf` `graphroot = "/var/lib/containers/storage"` (default).
5. Verify with `btrfs subvolume list /` and `df -h`.

---

## 3. Container topology

### Runtime

**Podman rootless** with NVIDIA CDI. Rationale:

- First-class on Arch, no daemon, no root socket.
- NVIDIA CDI spec is the modern way; works with rootless Podman.
- Quadlet units (systemd-native container definitions) replace docker-compose, integrate with journald and systemd timers.
- If you ever need docker.sock for a specific tool, `podman-docker` shim provides it.

### Container inventory

| Container | Image | Lifecycle | Use |
|---|---|---|---|
| **Ollama** | `docker.io/ollama/ollama:latest` | `systemd --user` service, always-on | Interactive chat, MCP integration, quick model swap |
| **vLLM** | `vllm/vllm-openai:latest` (rebuilt for sm_120 if upstream lacks) | manual `podman run` per session | OpenAI-compatible API for batch evals or serving |
| **Isaac Lab** | `nvcr.io/nvidia/isaac-lab:2.x` | manual per training run | Humanoid RL training |
| **Isaac Sim** | `nvcr.io/nvidia/isaac-sim:5.x` | manual, rare (Lab includes Sim) | Standalone sim for GR00T inference |
| **LiteLLM Proxy** (opt) | `ghcr.io/berriai/litellm:latest` | `systemd --user`, always-on | Unified endpoint routing local + cloud models |

### Native (no container)

- nvidia-open driver from `extra` repo + `nvidia-container-toolkit` (this only)
- Podman + slirp4netns + fuse-overlayfs
- `uv` for occasional one-off venvs not worth containerizing

### Why not a system-wide CUDA toolkit?

Isaac Sim, PyTorch, vLLM each ship their own CUDA runtime via wheels or container images. Installing the system `cuda` package adds a third runtime that doesn't match either, causing classic "two CUDA versions in one process" errors. **Install only the driver, not the toolkit.**

---

## 4. Isaac Lab / Sim — workflow

### Install

```bash
# One-time: get NGC API key (free) and login
podman login nvcr.io   # username "$oauthtoken", password = NGC API key
podman pull nvcr.io/nvidia/isaac-lab:2.x
```

NGC API key stored in 1Password item "NVIDIA NGC API key".

### Sanity-check (headless)

```bash
podman run --rm --device nvidia.com/gpu=all \
  -v ~/ml-data/isaac-cache:/root/.cache/ov \
  -v ~/projects/isaac-work:/workspace \
  -e ACCEPT_EULA=Y -e PRIVACY_CONSENT=Y \
  nvcr.io/nvidia/isaac-lab:2.x \
  ./isaaclab.sh -p source/standalone/workflows/rsl_rl/train.py \
    --task Isaac-Velocity-Flat-H1-v0 --headless --num_envs 2048
```

`--num_envs 2048` instead of default 4096 to fit 16 GiB VRAM. If OOM, drop to 1024.

### Interactive viewport — WebRTC livestream (not X11)

Isaac Sim has built-in WebRTC livestream. Running the container with `--enable-livestream` exposes a viewport on `:8211`. From MacBook, open `http://cachyos:8211/streaming/client` in Firefox.

This avoids the entire Hyprland-Wayland-vs-Isaac question:

- No X11 fallback session needed
- Works identically when you're sitting at the CachyOS desk or at a café
- One viewport path for local and remote

If WebRTC streaming has issues with a given Isaac Sim release, fallback is `xpra` to forward Isaac's window — but only if the livestream regresses.

### Recommended first three task experiments

1. `Isaac-Velocity-Flat-H1-v0` — H1 flat-ground locomotion. Baseline; trains in ~1-2h on 5070 Ti with 2048 envs. Establish that the stack works end-to-end.
2. `Isaac-Velocity-Rough-G1-v0` — G1 rough terrain locomotion. Harder, longer (~4-6h). Validates that you can leave it overnight via tmux.
3. **Isaac-GR00T N1.7 inference** on `demo_data/droid_sample` — no training, just running the foundation model. Smoke-test for VLA workflow.

### Checkpoint storage

```
~/ml-data/checkpoints/isaac/<task>/<run-timestamp>/
```

These ARE backed up by restic (see Phase 7 update). HF cache and Isaac asset cache are NOT — reproducible from internet.

---

## 5. HuggingFace / LLM workflow

### Inference — always-on (Ollama)

- Ollama container as `systemd --user` service.
- Exposed on Tailscale interface only: `OLLAMA_HOST=tailscale0:11434` (not `0.0.0.0`).
- Quadlet unit at `~/.config/containers/systemd/ollama.container`.
- Initial model pull set: `qwen2.5:14b-instruct-q4_K_M`, `llama3.3:8b`, `gemma3:12b`, `qwen2.5-coder:7b`.

### Serving — on-demand (vLLM)

- Helper script `~/scripts/vllm-up.sh <model>` starts vLLM container with sensible defaults for 16 GiB.
- OpenAI-compatible API on `:8000`.
- If upstream `vllm-openai` image lacks Blackwell support at install time, build locally with `TORCH_CUDA_ARCH_LIST='12.0+PTX'`. Document the build command in the script's header comment.

### Training / fine-tuning

- Per-project uv venv: `cd ~/projects/ml/<project> && uv venv && uv pip install -r requirements.txt`
- Pinned stack baseline (`requirements-ml-base.txt`):
  ```
  torch==2.7.*  --index-url https://download.pytorch.org/whl/cu128
  transformers>=4.50
  accelerate>=1.5
  datasets>=3.0
  peft>=0.14
  trl>=0.12
  bitsandbytes>=0.45    # built with CUDA 12.8 — may need BNB_CUDA_VERSION=128 env at install
  flash-attn>=2.7       # Blackwell kernels landed in 2.7
  ```
- HF Hub login: `huggingface-cli login` with token stored in 1Password ("HuggingFace Hub Token").
- `HF_HOME=~/ml-data/hf-cache` exported in `.zshrc` (cross-OS template: only set on Linux).

### Smoke test script

`~/scripts/cuda-smoke.sh` — runs in any ML venv, verifies:

1. `torch.cuda.is_available()` → True
2. `torch.cuda.get_device_name(0)` matches `5070 Ti`
3. 4096×4096 matmul + backward pass completes < 1s
4. `bitsandbytes` imports without error
5. `flash_attn` imports without error

Run this after every system update that touches the kernel or NVIDIA driver, before starting a long job.

### LoRA recipe template

`~/projects/ml/templates/lora-llama-8b/` — minimal working example: load Llama-3.1-8B in 4-bit, LoRA on a tiny custom dataset, train 50 steps, save adapter. Copy this dir to start a new fine-tune experiment.

---

## 6. Remote-training UX

### The flow

1. SSH from MacBook: `ssh nazar@cachyos` (Tailscale magic-DNS + 1P Touch ID).
2. `tmux new -s isaac-h1` (or attach existing session via `sesh`).
3. In pane 1: training command. Pane 2: `nvitop`. Pane 3: `tensorboard --bind_all --logdir ~/ml-data/checkpoints/isaac/H1-v0`.
4. Detach (`prefix-d`), close laptop lid, walk away.
5. From café: same SSH, `tmux attach -t isaac-h1`. Or open `http://cachyos:6006` in browser (tensorboard via Tailscale).

### Components (mostly already in the original plan)

- **tmux + tmux-resurrect + tmux-continuum** — already in Phase 6 (S8). Auto-save every 15 min, restore on tmux start, capture-pane-contents.
- **sesh** — already in Phase 4 / Phase 3 macOS plan. tmux `Prefix+Space` picker.
- **nvitop** — NEW. `pacman -S nvitop` (or `pipx install nvitop` if not packaged).
- **tensorboard** — comes with TF; for PyTorch users prefer `tensorboardX` or directly `torch.utils.tensorboard`.
- **`journalctl --user -fu ollama`** — live container log tail.

### sshd binding

CachyOS sshd should accept connections only from the Tailscale network, not from `eth0` / `wlan0`. Implementation: **firewalld rule** that allows `:22` only from `100.64.0.0/10` (Tailscale CGNAT range), drops everywhere else. This is more robust than `ListenAddress` because Tailscale-assigned IPs are not stable across reinstalls.

Configured in Phase Bootstrap. Equivalent `nftables` rule is fine if user prefers nftables over firewalld.

---

## 7. Power / thermals

For sustained 8-hour training:

- **Power limit:** `nvidia-smi -pl 250` (5070 Ti stock TDP ~300W; 250W loses ~5-8% throughput, gains substantially lower temps and noise).
- **Systemd unit:** `/etc/systemd/system/nvidia-power-limit.service` applies on boot.
- **Temperature logging:** during a training run, a background script appends `nvidia-smi --query-gpu=timestamp,temperature.gpu,power.draw --format=csv` to `~/ml-data/logs/gpu-$(date +%F).csv` every 30s. Cheap, useful for spotting thermal throttling.
- **power-profiles-daemon** → `performance` (Phase 8 in original plan).
- **Thermal cutoff (manual judgement):** if sustained `temperature.gpu > 83°C`, drop power limit further or add intake fan.
- **CPU undervolt:** out of scope. Ryzen 7800X3D with PBO stock is fine for sim CPU side.

---

## 8. Networking / access patterns

### Three layers, three answers

| Caller | From | Recommended |
|---|---|---|
| MacBook (personal) | anywhere | Tailscale magic-DNS — `http://cachyos:11434` |
| Apps on Hetzner k3s | datacenter | Tailscale on the k3s node, then `http://cachyos:11434` from pod |
| Public services / mobile apps / collaborators | Internet | Cloudflare Tunnel + Cloudflare Access |
| Multi-endpoint routing | any of above | LiteLLM Proxy in front of everything (optional) |

### What NOT to do

- **No port forwarding on the Vodafone router.** Vodafone DE often uses CGNAT (no public IP at all). Even without CGNAT: bot scans, no TLS, dynamic IP, ISP firmware updates break setup.

### Tailscale on k3s

- `tailscale up --auth-key=<key>` on the Hetzner k3s node.
- Magic-DNS makes `cachyos` resolvable from inside pods.
- For higher-end use: deploy the Tailscale Kubernetes operator, expose Ollama as a Tailscale Service with cluster-internal DNS.

### Cloudflare Tunnel + Access

- `cloudflared tunnel create home-ml` on CachyOS.
- Public hostname `ollama.nazarf.dev` (Cloudflare DNS).
- Cloudflare Access policy: email allow-list for browser access; service tokens for server-to-server.
- Free tier covers up to 50 users.

### LiteLLM Proxy (optional, recommended once 2+ endpoints exist)

Single OpenAI-compatible endpoint that routes to Ollama / vLLM / Anthropic / OpenAI per model name. Centralized:

- API key management (Anthropic / OpenAI keys live only here)
- Per-model cost tracking
- Fallbacks (if local Ollama down, route to Anthropic)
- Rate limits

Quadlet unit, exposed on Tailscale only.

### Power-state caveat

PC must be awake for any of this to work. Options:

- **24/7 on** — simplest. ~30W idle in DE ≈ €8-12/month.
- **WoL trigger** — MacBook script that wakes the PC via Wake-on-LAN before opening connection. Requires WoL enabled in BIOS, magic packet support, and a wakeup script on MacBook side.
- **Suspend after N idle hours + WoL** — systemd timer suspends after inactivity; WoL wakes on demand.

Recommendation: **24/7 on** for the first 2-3 months while iterating. Re-evaluate if electricity bill bites.

---

## 9. Integration with existing 20-task plan

Not rewriting `~/cachyos-setup-tasks.md` whole. Instead:

1. **This spec is the source of truth** for new ML/robotics parts.
2. **Phase 5 of original plan is replaced** by Section 5 (HF/LLM) of this spec.
3. **New phases inserted:**

   ```
   Phase 0    Pre-install Windows                    [done]
   Phase 1    CachyOS install                        [done]
   Phase 1.5  NEW: ML storage subvols (this spec §2)
   Phase 2    NVIDIA + nvidia-container-toolkit
   Phase 3    Keyboard parity (kanata + Hyprland)
   Phase 4    Dev environment + chezmoi
   Phase 5    REPLACED: Container-first LLM (this spec §3, §5)
   Phase 5b   NEW: Isaac Lab/Sim + GR00T (this spec §4)
   Phase 5c   NEW: Networking — Tailscale, Cloudflare Tunnel, LiteLLM (this spec §8)
   Phase 6    Apps + локалізація
   Phase 7    Backup — add ~/ml-data/checkpoints (NOT hf-cache, NOT containers)
   Phase 8    Polish + power-limits + remote training UX (this spec §6, §7)
   ```

4. After this spec is approved, the writing-plans skill produces a detailed per-task implementation plan with verification steps.

---

## Open questions (none blocking — defaults chosen)

- **NGC API key signup** is manual and free; user creates account first time before Phase 5b.
- **Cloudflare Tunnel hostname** — using `nazarf.dev` (existing CF zone) implied; user confirms or picks different subdomain at Phase 5c.
- **24/7 vs WoL** — defaulting to 24/7; revisit after a month.

---

## References

- [PyTorch 2.7 Release notes — Blackwell stable cu128](https://pytorch.org/blog/pytorch-2-7/)
- [Isaac Lab — NVIDIA 50-series support discussion](https://github.com/isaac-sim/IsaacLab/discussions/1888)
- [Isaac-GR00T N1.7 — NVIDIA repo](https://github.com/NVIDIA/Isaac-GR00T)
- [Isaac Sim Container Installation](https://docs.isaacsim.omniverse.nvidia.com/5.0.0/installation/install_container.html)
- [Isaac Lab container on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/isaac-lab)
- [Isaac Sim container on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/isaac-sim)
- [vLLM Blackwell sm_120 deployment notes (issue #41614)](https://github.com/vllm-project/vllm/issues/41614)
- [Blackwell Validation: Isaac Lab RL (Zenn)](https://zenn.dev/atsurobo/articles/blackwell-isaac-lab-reinforcement-learning?locale=en)
- [Isaac Lab paper — GPU-Accelerated Multi-Modal Robot Learning](https://arxiv.org/html/2511.04831v1)
