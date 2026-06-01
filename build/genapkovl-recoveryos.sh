#!/bin/sh -e

HOSTNAME="$1"
: ${HOSTNAME:="recoveryos"}
TOOLS="/home/builder/recoveryos-tools"

cleanup() { rm -rf "$tmp"; }
makefile() {
	OWNER="$1"; PERMS="$2"; FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
}
rc_add() {
	mkdir -p "$tmp/etc/runlevels/$2"
	ln -sf /etc/init.d/$1 "$tmp/etc/runlevels/$2/$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

mkdir -p "$tmp/etc" "$tmp/etc/apk" "$tmp/root" "$tmp/usr/local/bin"

makefile root:root 0644 "$tmp/etc/hostname" <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "$tmp/etc/apk/world" <<EOF
alpine-base
busybox
busybox-suid
busybox-openrc
chntpw
python3
py3-impacket
dialog
newt
ntfs-3g
ntfs-3g-progs
rsync
smartmontools
dmidecode
lshw
parted
gptfdisk
pciutils
usbutils
util-linux
nano
less
htop
font-terminus
kbd
lm-sensors
lm-sensors-detect
iputils
bind-tools
ncdu
cifs-utils
openssh-client
testdisk
ncdu
cifs-utils
openssh-client
testdisk
EOF

makefile root:root 0644 "$tmp/etc/inittab" <<EOF
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
tty1::respawn:/sbin/agetty --autologin root --noclear tty1 linux
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF

# Copy all tool scripts from the tools folder into the image
for f in "$TOOLS"/recoveryos-*; do
	[ -e "$f" ] || continue
	dest="$tmp/usr/local/bin/$(basename "$f")"
	cp "$f" "$dest"
	chown root:root "$dest"
	chmod 0755 "$dest"
done

makefile root:root 0644 "$tmp/root/.profile" <<'PROFILE'
if [ -z "$RECOVERYOS_MENU_STARTED" ]; then
	export RECOVERYOS_MENU_STARTED=1
	/usr/local/bin/recoveryos-menu
fi
PROFILE

rc_add devfs sysinit
rc_add dmesg sysinit
rc_add mdev sysinit
rc_add hwdrivers sysinit
rc_add modloop sysinit
rc_add hwclock boot
rc_add modules boot
rc_add sysctl boot
rc_add hostname boot
rc_add bootmisc boot
rc_add syslog boot
rc_add mount-ro shutdown
rc_add killprocs shutdown
rc_add savecache shutdown

tar -c -C "$tmp" etc root usr | gzip -9n > $HOSTNAME.apkovl.tar.gz
