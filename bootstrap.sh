#! /bin/bash


export LANG=C
export LC_ALL=C


# -- Packages to install.

PACKAGES='
dhcpcd5
user-setup
localechooser-data
cifs-utils
casper
lupin-casper
xz-utils
nomad-desktop
'


# -- Install basic packages.

apt -qq update > /dev/null
apt -yy -qq install apt-transport-https wget ca-certificates gnupg2 apt-utils --no-install-recommends > /dev/null


# -- Add key for our repository.
# -- Add key for the Graphics Driver PPA.
# -- Add key for the Ubuntu-X PPA.

wget -q http://repo.nxos.org/public.key -O nxos.key
printf "b51f77c43f28b48b14a4e06479c01afba4e54c37dc6eb6ae7f51c5751929fccc nxos.key" | sha256sum -c &&
	apt-key add nxos.key > /dev/null
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1118213C > /dev/null
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys AF1CDFA9 > /dev/null

# -- Remove key files

rm nxos.key


# -- Use optimized sources.list.

cp /configs/sources.list /etc/apt/sources.list


# -- Update packages list and install packages. Install Nomad Desktop meta package and base-files package
# -- avoiding recommended packages.

apt -qq update > /dev/null
apt -yy -qq upgrade > /dev/null
apt -yy -qq install ${PACKAGES//\\n/ } --no-install-recommends > /dev/null
apt -yy -qq purge --remove vlc > /dev/null


# -- Add /Applications to $PATH.

printf "PATH=$PATH:/Applications\n" > /etc/environment
sed -i "s|secure_path\=.*$|secure_path=\"$PATH:/Applications\"|g" /etc/sudoers
sed -i "/env_reset/d" /etc/sudoers


# -- Add AppImages.
# -- Create /Applications dirrectory for users. This directory "should" be created by the Software Center.
# -- Downloading AppImages with the SC will fail if this directory doesn't exist.
# -- Rename AppImageUpdate and znx.

APPS_SYS='
https://github.com/Nitrux/znx/releases/download/continuous-stable/znx_stable
https://github.com/AppImage/AppImageUpdate/releases/download/continuous/AppImageUpdate-x86_64.AppImage
'

mkdir /Applications

for x in $APPS_SYS; do
	wget -q -P /Applications $x
done

chmod +x /Applications/*
mkdir -p /etc/skel/Applications

APPS_USR='
https://github.com/icflorescu/vlc-3-appimage/releases/download/3.0.3/VLC_media_player-x86_64.AppImage
http://repo.nxos.org/appimages/ungoogled-chromium_71.0.3578.98-2_linux.AppImage
http://libreoffice.soluzioniopen.com/stable/basic/LibreOffice-6.2.0-x86_64.AppImage
'

for x in $APPS_USR; do
    wget -q -P /etc/skel/Applications $x
done

chmod +x /etc/skel/Applications/*

mv /Applications/AppImageUpdate-x86_64.AppImage /Applications/AppImageUpdate
mv /Applications/znx_stable /Applications/znx

# -- Add znx-gui.

cp /configs/znx-gui.desktop /usr/share/applications
wget -q -O /bin/znx-gui https://raw.githubusercontent.com/Nitrux/nitrux-iso-tool/development/configs/znx-gui
chmod +x /bin/znx-gui


# -- Install AppImage daemon. AppImages that are downloaded to the dirs monitored by the daemon should be integrated automatically.
# -- firejail should be automatically used by the daemon to sandbox AppImages.

appimgd='
https://github.com/AppImage/appimaged/releases/download/continuous/appimaged_1-alpha-git369c33a.travis92_amd64.deb
'

mkdir appimaged_deb

for x in $appimgd; do
	wget -q -P appimaged_deb $x
done

dpkg -iR appimaged_deb > /dev/null
rm -r appimaged_deb


# -- Add config for SDDM.
# -- Fix for https://bugs.launchpad.net/ubuntu/+source/network-manager/+bug/1638842.
# -- Add kservice menu item for Dolphin for AppImageUpdate.
# -- Add custom launchers for Maui apps.
# -- Add policykit file for KDialog.

cp /configs/sddm.conf /etc
cp /configs/10-globally-managed-devices.conf /etc/NetworkManager/conf.d/
cp /configs/appimageupdate.desktop /usr/share/kservices5/ServiceMenus/
cp /configs/org.kde.* /usr/share/applications
cp /configs/org.freedesktop.policykit.kdialog.policy /usr/share/polkit-1/actions/


# -- Add vfio modules and files.

echo "install vfio-pci /bin/vfio-pci-override-vga.sh" >> /etc/initramfs-tools/modules
echo "install vfio_pci /bin/vfio-pci-override-vga.sh" >> /etc/initramfs-tools/modules
echo "softdep nvidia pre: vfio vfio_pci" >> /etc/initramfs-tools/modules
echo "softdep amdgpu pre: vfio vfio_pci" >> /etc/initramfs-tools/modules
echo "vfio" >> /etc/initramfs-tools/modules
echo "vfio_iommu_type1" >> /etc/initramfs-tools/modules
echo "vfio_virqfd" >> /etc/initramfs-tools/modules
echo "options vfio_pci ids=" >> /etc/initramfs-tools/modules
echo "vfio_pci ids=" >> /etc/initramfs-tools/modules
echo "vfio_pci" >> /etc/initramfs-tools/modules
echo "nvidia" >> /etc/initramfs-tools/modules
echo "amdgpu" >> /etc/initramfs-tools/modules

echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
echo "vfio_pci ids=" >> /etc/modules

cp /configs/asound.conf /etc/
cp /configs/asound.conf /etc/skel/.asoundrc

cp /configs/initramfs.conf /etc/initramfs-tools/

cp /configs/iommu_unsafe_interrupts.conf /etc/modprobe.d/

cp /configs/amdgpu.conf /etc/modprobe.d/
cp /configs/kvm.conf /etc/modprobe.d/
cp /configs/nvidia.conf /etc/modprobe.d/
cp /configs/qemu-system-x86.conf /etc/modprobe.d
cp /configs/vfio_pci.conf /etc/modprobe.d/
cp /configs/vfio-pci.conf /etc/modprobe.d/

cp /configs/vfio-pci-override-vga.sh /bin/


# -- Install the latest stable kernel.

printf "INSTALLING NEW KERNEL."


kfiles='
https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.20.11/linux-headers-4.20.11-042011_4.20.11-042011.201902200535_all.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.20.11/linux-headers-4.20.11-042011-generic_4.20.11-042011.201902200535_amd64.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.20.11/linux-image-unsigned-4.20.11-042011-generic_4.20.11-042011.201902200535_amd64.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.20.11/linux-modules-4.20.11-042011-generic_4.20.11-042011.201902200535_amd64.deb
'

mkdir latest_kernel

for x in $kfiles; do
	printf "$x"
	wget -q -P latest_kernel $x
done

dpkg -iR latest_kernel > /dev/null
rm -r latest_kernel


# -- Add itch.io store launcher.

mkdir -p /etc/skel/.local/share/applications

cp /configs/install.itch.io.desktop /etc/skel/.local/share/applications
wget -q -O /etc/skel/.config/itch-setup https://raw.githubusercontent.com/UriHerrera/storage/master/Files/itch-setup
chmod +x /etc/skel/.config/itch-setup


# -- Update the initramfs.

cat /configs/persistence >> /usr/share/initramfs-tools/scripts/casper-bottom/05mountpoints_lupin
update-initramfs -u


# -- Clean the filesystem.

apt -yy -qq purge --remove casper lupin-casper > /dev/null
apt -yy -qq autoremove > /dev/null
apt -yy -qq clean > /dev/null

