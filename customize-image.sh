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
    usermod -a -G input pi

    #
    rm -f /etc/systemd/system/getty@.service.d/override.conf
    rm -f /etc/systemd/system/serial-getty@.service.d/override.conf

	# add pi user to sudoers
    echo 'pi ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
}

set_hostname() {
    echo 'rearm' >> /etc/hostname
}

config_audio() {
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
    pcm "hw:1,0" # "hw:1,0" means HDMI change to "hw:0,0" for analog lineout jack output
    period_time 0
    period_size 1024
    buffer_size 4096
    rate 48000
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

set_cpu() {
    sed -i "/^MIN_SPEED=/s/=.*/=480000/" /etc/default/cpufrequtils
    sed -i "/^MAX_SPEED=/s/=.*/=1400000/" /etc/default/cpufrequtils

	echo 'overlays=analog-codec cir cpu-clock-1.2GHz-1.3v cpu-clock-1.368GHz-1.3v cpu-clock-1.3GHz-1.3v' >> /boot/armbianEnv.txt
	# echo 'overlays=analog-codec cir cpu-clock-1.2GHz-1.3v cpu-clock-1.3GHz-1.3v' >> /boot/armbianEnv.txt
    echo 'extraargs=maxcpus=2' >> /boot/armbianEnv.txt
}

config_mali400() {
	echo mali > /etc/modules-load.d/mali.conf
    echo KERNEL==\"mali\", MODE=\"0660\", GROUP=\"video\" > /etc/udev/rules.d/50-mali.rules
	echo 'blacklist lima' > /etc/modprobe.d/blacklist-lima.conf
	tar -xhzvf /tmp/overlay/sun8i/mali.tar.gz -C /
	
	# set mali freq and governor on boot
    sed -i -e '$i \echo 432000000 > /sys/devices/platform/mali-utgard.0/devfreq/mali-utgard.0/max_freq\n' /etc/rc.local
	sed -i -e '$i \echo performance > /sys/devices/platform/mali-utgard.0/devfreq/mali-utgard.0/governor\n' /etc/rc.local
}

install_mali400_userspace() {

	git clone https://github.com/arnaldovalente/libmali /root/libmali
	cd /root/libmali

	cmake . "-DMALI_VARIANT=400" "-DMALI_ARCH=arm-linux-gnueabihf" "-DCMAKE_INSTALL_LIBDIR=lib/arm-linux-gnueabihf"
	cmake -DCMAKE_INSTALL_PREFIX=/usr/local -P cmake_install.cmake

	ldconfig
	export PKG_CONFIG_PATH="/usr/local/lib/arm-linux-gnueabihf/pkgconfig"
}

config_uboot() {
    # sed -i 's/setenv console \"both\"/setenv console \"serial\"/g' /boot/boot.cmd
    sed -i 's/setenv disp_mem_reserves \"off\"/setenv disp_mem_reserves \"on\"/g' /boot/boot.cmd
    mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
    # sed -i 's/console=both/console=serial/g' /boot/armbianEnv.txt
}


install_retropie() {

	git clone https://github.com/arnaldovalente/RetroPie-Setup /home/pi/RetroPie-Setup

	platform="sun8i-h3"
	
#	modules=(
#	    'retroarch'
#	    'emulationstation'
#		'runcommand install'
#		'retropiemenu install'
#	    'autostart enable'
#		'joy2key'
#    )
	
	modules=(
	    'setup basic_install'
	    'autostart enable'
        'usbromservice'
        'samba depends'
        'samba install_shares'
		'joy2key'
    )

	for module in "${modules[@]}"; do
	   su -c "sudo -S __platform=${platform} __nodialog=1 /home/pi/RetroPie-Setup/retropie_packages.sh ${module}" - pi
	done

	rm -rf /home/pi/RetroPie-Setup/tmp

	sudo apt-get clean
}

Main() {

    # echo $RELEASE buster
    # echo $LINUXFAMILY sunxi
    # echo $BOARD orangepipc
	
    config_root_password
    config_pi_user
	config_audio
	config_uboot

	set_hostname
	set_cpu

	config_mali400
	# install_mali400_userspace

	install_retropie
	
} # Main

Main "$@"
