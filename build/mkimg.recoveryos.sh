profile_recoveryos() {
	profile_standard
	title="RecoveryOS"
	desc="Offline Windows recovery toolkit"
	image_name="recoveryos"
	hostname="recoveryos"
	kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage,nvme quiet fbcon=font:TER16x32 video=1920x1080 video=HDMI-A-1:d console=tty1"
	apks="$(echo $apks | sed -e 's/openssh-server\S*//g' -e 's/openssh-client\S*//g' -e 's/openssh-sftp-server//g' -e 's/openssh-keygen//g' -e 's/chrony\S*//g' -e 's/openntpd\S*//g' -e 's/ppp\S*//g' -e 's/tiny-cloud\S*//g' -e 's/doas//g' -e 's/network-extras//g' -e 's/\bvlan\b//g')"
	apks="$apks chntpw dialog newt util-linux util-linux-misc ntfs-3g ntfs-3g-progs rsync smartmontools dmidecode lshw pciutils usbutils parted gptfdisk nano less htop curl ca-certificates kbd font-terminus coreutils findutils grep sed gawk testdisk ncdu lm-sensors lm-sensors-detect cifs-utils openssh-client bind-tools iputils python3 py3-impacket"
	apkovl="genapkovl-recoveryos.sh"
}
