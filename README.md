# RecoveryOS

**A bootable offline Windows recovery toolkit built on Alpine Linux.**

Boot it from a USB stick on a PC that won't start and work on the Windows install from the outside — no login required. RecoveryOS auto-launches a green-on-black text menu offering password reset, WiFi key recovery, file rescue, disk health and space analysis, system reporting, and more. All disk reads are read-only by default, and BitLocker-encrypted volumes are never bypassed.

<img width="1895" height="1135" alt="menu" src="https://github.com/user-attachments/assets/ff6edb88-e97a-4b76-a358-9dc9048850ab" />

## What it does

A single hybrid ISO (BIOS + UEFI) that runs entirely from RAM. On boot it auto-fits the console font to the panel, detects any Windows installation, and drops you into a numbered menu:

| Key | Tool | Purpose |
| --- | --- | --- |
| 1 | Reset Windows Password | Blank a local Windows account password (chntpw) |
| 2 | Recover WiFi Passwords | Decrypt saved WLAN keys offline via the SYSTEM DPAPI master key |
| 3 | Rescue User Files | Copy user files out to a local drive, SMB share, or SSH target |
| 4 | Smart File Recovery | Carve files from unmountable / failing disks (PhotoRec) |
| 5 | System Information Report | CPU, RAM, motherboard, BIOS, storage, network |
| 6 | Disk Health Check | SMART status; flags failing disks (smartmontools) |
| 7 | Disk Space Analyzer | Interactive disk-usage browser (ncdu), read-only |
| 8 | Disk Tools | Wipe / edit partitions (cfdisk, parted) |
| 9 | Network Diagnostics | Interfaces, DHCP lease, route, DNS, connectivity tests |
| 10 | Temperature & Sensors | CPU / board temps (lm-sensors, thermal zones) |
| 11 | Rootkit/Malware Scan | System integrity check (SUID, modules, hidden, world-writable) |
| 12 | Export JSON Report | Whole-machine diagnostics to a single JSON file |
| 13 | View Crash Logs | Inventory Windows minidumps and Event Logs |
| 14 | Disk Report | Dated file-tree of a chosen disk; export JSON/CSV |
| H | Help | Per-tool reference |
| S | Shell | Root command line |
| A | About | Version, author, license |

Two global toggles — **[V] Verbose** and **[J] JSON** — apply across the reporting tools.

## Quick start

1. **Download** `recoveryos-v3.23-x86_64.iso` and `…iso.sha256` from the [latest Release](../../releases/latest).
2. **Verify** the download matches the checksum (do not skip — you're trusting it with disks and passwords):
   - **Windows:** `certutil -hash file recoveryos-v3.23-x86_64.iso SHA256` and compare to the `.sha256` contents.
   - **Linux / macOS:** `sha256sum -c recoveryos-v3.23-x86_64.iso.sha256` → expect `OK`.
3. **Flash to a USB stick:**
   - **Windows:** [Rufus](https://rufus.ie) → select the ISO → when prompted, choose **DD Image mode** (ISO mode will *not* boot).
   - **Linux:** `sudo dd if=recoveryos-v3.23-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync` — triple-check `/dev/sdX` is the USB, not a real disk.
4. **Boot the target PC** from the USB (tap the boot-menu key at power-on — usually F12, F8, F9, or Esc; Macs are not supported).
5. The menu **auto-launches**. Pick a tool by number. Everything is read-only by default; press **[H]** for per-tool help.

> Runs entirely from RAM — once booted you can remove nothing is installed to the target. Use only on systems and data you own or are authorized to access.

## How it's built

- **Base:** Alpine Linux 3.23, diskless mode, ~470 MB hybrid ISO.
- **Tools:** about 20 POSIX sh scripts plus one Python helper, all under `tools/`. They share a mount helper (`recoveryos-mountlib`, read-only NTFS with a `ro,force` fallback for dirty volumes), a console auto-fit (`recoveryos-screenfit`), a boot-time Windows detector (`recoveryos-detect`), and a JSON serializer (`recoveryos-jsonlib`).
- **Image:** `build/mkimg.recoveryos.sh` (mkimage profile) plus `build/genapkovl-recoveryos.sh` (overlay generator). The overlay glob auto-copies every `recoveryos-*` tool into `/usr/local/bin`, so adding a tool needs no overlay edit. Adding a package requires editing both the profile's apks line and the overlay's world list.

See [docs/architecture.md](docs/architecture.md) for the full design.

### Build from source (outline)

Requires an Alpine build chroot with `alpine-sdk` and the `aports` scripts. Copy `tools/recoveryos-*` into the chroot's tools dir and `build/*.sh` into `aports/scripts/`, then run mkimage:

    cd aports/scripts
    sh mkimage.sh --tag v3.23 --outdir ~/iso --arch x86_64 \
      --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/main \
      --repository https://dl-cdn.alpinelinux.org/alpine/v3.23/community \
      --profile recoveryos

Flash the ISO with Rufus in **DD Image mode** (mandatory for Alpine hybrid ISOs), or `dd` on Linux.

## Design notes

- **Offline WiFi decryption** reads the SYSTEM and SECURITY registry hives and the machine DPAPI master key from a read-only mount, then unprotects each WLAN profile's keyMaterial — the same offline technique forensic tools use. Cleartext profiles are shown as-is; BitLocker-locked volumes are reported, never bypassed.
- **Verbose [V] error surfacing:** every mount/SMART/DHCP/decryptor helper normally hides stderr with `2>/dev/null`. When Verbose is toggled on (`/run/recoveryos/verbose` = `1`), the captured stderr is printed inline in red beneath the failure -- e.g. the ntfs-3g reason a dirty or failing NTFS volume won't mount. The quiet path is byte-identical when Verbose is off. The shared `recoveryos-mountlib` captures mount stderr into `ROS_MOUNT_ERR`; `ros_verr` emits it only in verbose mode.
- **BusyBox-safe enumeration:** interfaces are read from `/sys/class/net` rather than `ip -br` (BusyBox ip lacks `-br`), and DHCP falls back from dhcpcd to BusyBox udhcpc.
- **Network link timing:** real NICs autonegotiate slower than a VM's virtual link, so Network Diagnostics polls each interface's carrier for up to 12 s before attempting DHCP, instead of a fixed wait.

## Known limitations

- **Dual-monitor mirroring:** the console clones to all connected outputs. The build disables a second output via the kernel cmdline (`video=HDMI-A-1:d`), correct for the build hardware but a no-op on machines with different connector names. A portable adaptive fix would need an initramfs hook before fbcon binds — not yet implemented.
- The shipped cmdline contains a harmless malformed token (`video1920x1080`, missing `=`) that the kernel ignores; resolution is set by fbcon/EFI defaults. Left as-shipped to match the verified ISO.
- WiFi key decryption can't be exercised in QEMU (no real Windows DPAPI data); it's verified on physical hardware.

## Downloads

The prebuilt ISO and its `.sha256` are attached to the [latest Release](../../releases/latest). Always verify the checksum before flashing (see [Quick start](#quick-start)).

## Author and License

Created by **N.G. (SparklyBird)** — https://github.com/SparklyBird

Source-available, not OSI open source. Free for personal use; commercial or corporate use requires the author's permission; share unmodified with this notice and credit kept. See [LICENSE](LICENSE). No warranty — use only on systems and data you own or are allowed to access.
