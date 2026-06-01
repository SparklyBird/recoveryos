# RecoveryOS — Architecture

## Overview
RecoveryOS is a diskless Alpine Linux 3.23 image that boots from USB on BIOS or
UEFI, runs entirely from RAM, and auto-launches a text menu of recovery tools.
The Windows install is never booted; all work happens from outside it.

## Boot flow
1. Kernel + initramfs load from the hybrid ISO; the squashfs modloop and apks
   come from the boot media.
2. The overlay (apkovl) applies: hostname, auto-login on tty1, the package world
   list, and all `recoveryos-*` tools copied to `/usr/local/bin` (chmod 0755).
3. On login, `recoveryos-screenfit` picks the largest Terminus font giving at
   least 34 rows / 100 cols for the panel and runs `setfont`.
4. `recoveryos-detect` scans every partition (`blkid`), mounts NTFS volumes
   read-only, looks for `.../System32/config/SAM`, and records the Windows
   partition + version in `/run/recoveryos/win.conf`. BitLocker volumes are
   flagged as locked, never unlocked.
5. `recoveryos-menu` renders the centered green TUI and dispatches keys to tools.

## Shared infrastructure
- **recoveryos-mountlib** — `ros_mount_ro` / `ros_mount_rw`. NTFS via ntfs-3g
  with a `ro,force` fallback for dirty (Fast-Startup) volumes; generic mount
  otherwise. Never writes to a source volume in read-only mode.
- **recoveryos-screenfit** — console font/size auto-fit; writes `screen.conf`.
- **recoveryos-detect** — one-shot Windows detection; writes `win.conf`.
- **recoveryos-jsonlib** — JSON serialization for the `[J]` toggle and `[12]`.

## Build pipeline
- `build/mkimg.recoveryos.sh` is the mkimage profile. Its `apks=` line lists every
  package baked onto the media. Its `kernel_cmdline` sets the console font, the
  dual-monitor `video=...:d` disable, and `console=tty1`.
- `build/genapkovl-recoveryos.sh` generates the overlay: the package world list,
  auto-login, and the tool-copy glob.
- **Hard-won lesson:** a package must appear in BOTH the profile `apks=` line and
  the overlay world list. A name that doesn't exist in the target Alpine release
  aborts the whole apk resolve and silently produces a stale ISO. Tool-only edits
  carry no repo-resolve risk and are preferred.

## Notable tool internals

### [2] WiFi decryption (recoveryos-wifi + recoveryos-wifidecrypt)
The shell tool mounts the Windows volume read-only and calls a Python helper
(impacket). The helper:
1. Extracts the DPAPI_SYSTEM secret from the `SYSTEM` + `SECURITY` hives.
2. Decrypts the `S-1-5-18` machine master keys.
3. For each WLAN profile, builds a DPAPI blob from `keyMaterial`, matches it to a
   master key by GUID, and decrypts the passphrase.
Output is `SSID <tab> AUTH <tab> STATUS <tab> KEY`, where STATUS is decrypted,
cleartext, open, or locked. The hives are copied to a tmpfs first so impacket's
read-write open doesn't fail against the read-only mount.

### Verbose [V] error surfacing (recoveryos-mountlib + ros_verr)
Tools normally silence mount/SMART/DHCP/decryptor stderr with `2>/dev/null` for a clean TUI.
The `[V]` key toggles `/run/recoveryos/verbose` between `0` and `1`. When `1`, `mountlib`
captures each failed mount's stderr into `ROS_MOUNT_ERR`, and `ros_verr` prints it indented
in red beneath the failure line -- e.g. `Failed to read NTFS $Bitmap: I/O error` on a
dirty or failing volume. With Verbose off the quiet path is byte-identical. Surfaced across
all mounting tools (rescue, recover, diskreport, export, resetpw, wifi) plus SMART and DHCP.

### [9] Network Diagnostics (recoveryos-netdiag)
Enumerates interfaces from `/sys/class/net`. Brings them up, then polls each
interface's `carrier` for up to 12 s (real NIC autonegotiation is slower than a
VM's instant link) before running `dhcpcd`, falling back to BusyBox `udhcpc`.
Then reports addresses, route, DNS, and runs gateway / 8.8.8.8 / DNS-lookup tests.

### [14] Disk Report (recoveryos-diskreport)
Mounts a chosen partition read-only and produces a dated file tree on-screen, or
exports JSON (ncdu) / CSV. Uses GNU `find -printf` when available, else a BusyBox
`find | stat | gawk` fallback producing identical fields.

## Testing
Iterate in QEMU on the WSL host (fast, no flashing). QEMU validates package
presence, tool execution, menu layout, and DHCP. It cannot test dirty-NTFS
mounts, failing-disk carving, or DPAPI decryption (no real Windows data) — those
are verified by flashing to USB and booting real hardware.
