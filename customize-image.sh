#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4
ARCH=$5
BOARDFAMILY=$6

#--------------------------------------------------------------------------------------------------------------------------------
# Let's have unique way of displaying alerts
#--------------------------------------------------------------------------------------------------------------------------------
display_alert()
{
	local tmp=""
	[[ -n $2 ]] && tmp="[\e[0;33m $2 \x1B[0m]"

	case $3 in
		err)
		echo -e "[\e[0;31m error \x1B[0m] $1 $tmp"
		;;

		wrn)
		echo -e "[\e[0;35m warn \x1B[0m] $1 $tmp"
		;;

		ext)
		echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m$1\x1B[0m $tmp"
		;;

		info)
		echo -e "[\e[0;32m o.k. \x1B[0m] $1 $tmp"
		;;

		*)
		echo -e "[\e[0;32m .... \x1B[0m] $1 $tmp"
		;;
	esac
}

config_root_password() {
	# remove armbian first login flag
	rm /root/.not_logged_in_yet

	# assign rearm password to root user
	echo root:rearm | chpasswd
}

config_pi_user() {
	# create pi user
	adduser pi --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password

	# assign rearm password to pi user
	echo pi:rearm | chpasswd

	# add pi user to video e input group
	usermod -a -G video pi
	usermod -a -G audio pi
	usermod -a -G input pi

	#
	rm -f /etc/systemd/system/getty@.service.d/override.conf
	rm -f /etc/systemd/system/serial-getty@.service.d/override.conf

	# add pi user to sudoers
	echo 'pi ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

set_hostname() {
	echo 'rearm' > /etc/hostname
}

config_audio_h3() {
	# create asound.conf
	cat > /etc/asound.conf << _EOF_
pcm.!default {
  type plug
  slave.pcm "dmixer"
}

pcm.dmixer  {
  type dmix
  ipc_key 1024
  slave {
    pcm "hw:1,0" # "hw:0,0" means HDMI change to "hw:0,0" for analog lineout jack output
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 44100
  }
  bindings {
    0 0
    1 1
  }
}

ctl.dmixer {
  type hw
  card 0
}

ctl.!default {
    type hw
    card 0
}
_EOF_
}

config_audio_h6() {
	# create asound.conf
	cat > /etc/asound.conf << _EOF_
pcm.!default {
  type plug
  slave.pcm "dmixer"
}

pcm.dmixer  {
  type dmix
  ipc_key 1024
  slave {
    pcm "hw:0,0" # "hw:0,0" means HDMI change to "hw:0,0" for analog lineout jack output
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 44100
  }
  bindings {
    0 0
    1 1
  }
}

ctl.dmixer {
  type hw
  card 0
}

ctl.!default {
    type hw
    card 0
}
_EOF_
}

config_audio_h616() {
	# create asound.conf
	cat > /etc/asound.conf << _EOF_
pcm.!default {
  type plug
  slave.pcm "dmixer"
}

pcm.dmixer  {
  type dmix
  ipc_key 1024
  slave {
    pcm "hw:0,0" # "hw:0,0" means HDMI change to "hw:0,0" for analog lineout jack output
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 44100
  }
  bindings {
    0 0
    1 1
  }
}

ctl.dmixer {
  type hw
  card 0
}

ctl.!default {
    type hw
    card 0
}
_EOF_
}

config_audio_rk3399() {
	# create asound.conf
	cat > /etc/asound.conf << _EOF_
pcm.!default {
  type plug
  slave.pcm "dmixer"
}

pcm.dmixer  {
  type dmix
  ipc_key 1024
  slave {
    pcm "hw:0,0" # "hw:0,0" means HDMI change to "hw:0,0" for analog lineout jack output
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 44100
  }
  bindings {
    0 0
    1 1
  }
}

ctl.dmixer {
  type hw
  card 0
}

ctl.!default {
    type hw
    card 0
}
_EOF_
}

config_audio() {
	case $BOARDFAMILY in
		sun50iw9)
			config_audio_h616
			;;
		rk3399)
			config_audio_rk3399
			;;
		sun8i)
			config_audio_h3
			;;
		sun50iw6)
			config_audio_h6
			;;
  	esac
}	

config_uboot() {
	# sed -i 's/setenv console \"both\"/setenv console \"serial\"/g' /boot/boot.cmd
	# sed -i 's/setenv disp_mem_reserves \"off\"/setenv disp_mem_reserves \"on\"/g' /boot/boot.cmd
	# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
	# sed -i 's/console=both/console=serial/g' /boot/armbianEnv.txt

	#"extraargs=video=HDMI-A-1:1280x720@60e" >> /boot/orangepiEnv.txt
	# vmalloc=320M

	sed -i 's/^bootlogo.*/bootlogo=true/' /boot/orangepiEnv.txt || echo 'bootlogo=true' >> /boot/orangepiEnv.txt
}

clone_retropie() {
	git clone https://github.com/arnaldovalente/RetroPie-Setup /home/pi/RetroPie-Setup
	chown -R pi /home/pi/RetroPie-Setup
}

binary_builder_retropie() {

	display_alert "EXPORT PUBLIC KEY" "/tmp/overlay/public.key" "Info"
	gpg --import "/tmp/overlay/public.key"
	display_alert "EXPORT PRIVATE KEY" "/tmp/overlay/private.key" "Info"
	gpg --pinentry-mode loopback --passphrase-file="/tmp/overlay/passphrase" --import "/tmp/overlay/private.key"

 	if gpg --list-keys "gleam2003@msn.com" &>/dev/null; then
		display_alert "KEY INSTALLED" "gleam2003@msn.com" "Info"

		mapfile -t modules < "/tmp/overlay/${platform}.list"

#		su -c "sudo -S __platform=${platform} __nodialog=1 /home/pi/RetroPie-Setup/retropie_packages.sh builder section core" - pi
		
		for module in "${modules[@]}"; do
			display_alert "START BUILD MODULE" "${module}" "Info"
			su -c "sudo -S __platform=${platform} __nodialog=1 /home/pi/RetroPie-Setup/retropie_packages.sh builder module ${module}" - pi
			display_alert "END BUILD MODULE" "${module}" "Info"
		done
	fi

}

install_retropie() {

	if [ ! -z "$platform" ]; then

		modules=(
			'libdrm'
			'mesa3d'
			'setup basic_install'
			'bluetooth depends'
			'raspbiantools enable_modules'
			'autostart enable'
			'usbromservice'
			'samba depends'
			'samba install_shares'
			'xpad'
		)

		for module in "${modules[@]}"; do
			su -c "sudo -S __platform=${platform} __nodialog=1 /home/pi/RetroPie-Setup/retropie_packages.sh ${module}" - pi
		done
	fi

	rm -rf /home/pi/RetroPie-Setup/tmp
	chown -R pi /home/pi/RetroPie-Setup

	sudo apt-get clean

}

delete_orangepi_user() {
	userdel orangepi
	rm -rf /home/orangepi
}

set_platform() {
	case $BOARDFAMILY in
		sun8i)
			platform=sun8i-h3
			;;
		sun50iw6)
			platform=sun50i-h6
			;;
		sun50iw9)
			platform=sun50i-h616
			;;
		rk3399)
			platform=rk3399
			;;
	esac
}

Main() {

	set_platform

	display_alert "ReARM.it customization script" "customize-image.sh" "Info"
	display_alert "BOARD" "$BOARD" "Info"
	display_alert "BOARDFAMILY" "$BOARDFAMILY" "Info"
	display_alert "PLATFORM" "$platform" "Info"

	display_alert "User configuration start..."
	delete_orangepi_user
	config_root_password
	config_pi_user

	display_alert "Configure uboot start..."
	config_uboot

	display_alert "Configure audio..."
	config_audio

	display_alert "Set host name..."
	set_hostname

	display_alert "RetroPi installation start..."
	clone_retropie
	install_retropie
#	binary_builder_retropie
} # Main

Main "$@"
