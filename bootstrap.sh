#! /bin/sh

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
nomad-desktop
'


# -- Make /bin, /sbin and /usr/sbin, symlinks to /usr/bin.

mv /bin/* /usr/bin
mv /sbin/* /usr/bin
mv /usr/sbin/* /usr/bin
rm -rf /bin /sbin /usr/sbin
ln -s /usr/bin /bin
ln -s /usr/bin /sbin
ln -s /usr/bin /usr/sbin


# -- Install basic packages.

apt-get -y -qq update
apt-get -y -qq install -y apt-transport-https wget ca-certificates gnupg2 apt-utils --no-install-recommends


# -- Use optimized sources.list. The LTS repositories are used to support the KDE Neon repository since these
# -- packages are built against the latest LTS release of Ubuntu.

wget -q https://archive.neon.kde.org/public.key -O neon.key
echo ee86878b3be00f5c99da50974ee7c5141a163d0e00fccb889398f1a33e112584 neon.key | sha256sum -c &&
	apt-key add neon.key

wget -q http://repo.nxos.org/public.key -O nxos.key
echo b51f77c43f28b48b14a4e06479c01afba4e54c37dc6eb6ae7f51c5751929fccc nxos.key | sha256sum -c &&
	apt-key add nxos.key

cp /configs/sources.list /etc/apt/sources.list

rm neon.key
rm nxos.key


# -- Update packages list and install packages. Install Nomad Desktop meta package avoiding recommended packages from deps.

apt-get -y -qq update
apt-get -y -qq install -y $(echo $PACKAGES | tr '\n' ' ') --no-install-recommends > /dev/null
apt-get -yy -q install --only-upgrade base-files=10.4+nxos
apt-get -y -qq clean


# -- Install AppImages.

APPS='
https://github.com/Nitrux/znx/releases/download/continuous/znx
'

mkdir /Applications

for x in $(echo $APPS | tr '\n' ' '); do
	wget -qP /Applications $x
done

chmod +x /Applications/*


# -- Add znx-gui.

cp /configs/znx-gui.desktop /usr/share/applications
wget -q https://raw.githubusercontent.com/Nitrux/znx-gui/master/znx-gui -O /bin/znx-gui
chmod +x /bin/znx-gui


# -- Install the latest stable kernel.

kfiles='
http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.18.13/linux-headers-4.18.13-041813_4.18.13-041813.201810100332_all.deb
http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.18.13/linux-headers-4.18.13-041813-generic_4.18.13-041813.201810100332_amd64.deb
http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.18.13/linux-image-unsigned-4.18.13-041813-generic_4.18.13-041813.201810100332_amd64.deb
http://kernel.ubuntu.com/~kernel-ppa/mainline/v4.18.13/linux-modules-4.18.13-041813-generic_4.18.13-041813.201810100332_amd64.deb
'

mkdir latest_kernel

for x in $kfiles; do
	wget -q -P latest_kernel $x
done

dpkg -iR latest_kernel
rm -r latest_kernel


# -- Install Maui Apps Debs.

mauipkgs='
https://raw.githubusercontent.com/UriHerrera/storage/master/mauikit-framework_0.1-1_amd64.deb
https://raw.githubusercontent.com/UriHerrera/storage/master/vvave_0.1-1_amd64.deb
https://raw.githubusercontent.com/UriHerrera/storage/master/pix_0.1-1_amd64.deb
https://raw.githubusercontent.com/UriHerrera/storage/master/index_0.1-1_amd64.deb
https://raw.githubusercontent.com/UriHerrera/storage/master/buho_0.1-1_amd64.deb
'

mkdir maui_debs

for x in $mauipkgs; do
	wget -q -P maui_debs $x
done

dpkg -iR maui_debs
rm -r maui_debs


# -- Install Software Center Maui port.

nxsc='
https://raw.githubusercontent.com/UriHerrera/storage/master/libappimageinfo_0.1-1_amd64.deb
https://raw.githubusercontent.com/UriHerrera/storage/master/nx-software-center_2.3-1_amd64.deb
'

mkdir nxsc_deps

for x in $nxsc; do
	wget -q -P nxsc_deps $x
done
dpkg --force-all -iR nxsc_deps
rm -r nxsc_deps


# -- For now, the software center, libappimage and libappimageinfo provide the same library and to install each one it must be overriden each time.

ln -sv /usr/lib/x86_64-linux-gnu/libbfd-2.30-multiarch.so /usr/lib/x86_64-linux-gnu/libbfd-2.31.1-multiarch.so # needed for the software center
ln -sv /usr/lib/x86_64-linux-gnu/libboost_filesystem.so.1.65.1 /usr/lib/x86_64-linux-gnu/libboost_filesystem.so.1.67.0 # needed for the software center
ln -sv /usr/lib/x86_64-linux-gnu/libboost_system.so.1.65.1 /usr/lib/x86_64-linux-gnu/libboost_system.so.1.67.0 # needed for the software center


# -- Add /Applications to $PATH.

printf "PATH=$PATH:/Applications\n" > /etc/environment
sed -i "s|secure_path\=.*$|secure_path=\"$PATH:/Applications\"|g" /etc/sudoers
sed -i "/env_reset/d" /etc/sudoers


# -- Add config for SDDM.

cp /configs/sddm.conf /etc
