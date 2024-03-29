#!/bin/sh -x

# Credit: http://www.aisecure.net/2011/05/01/root-on-zfs-freebsd-current/

NAME=$1

# create disks
gpart create -s gpt ada0
gpart add -b 34 -s 94 -t freebsd-boot ada0
gpart add -t freebsd-ufs -l disk0 ada0
gnop create -S 4096 /dev/gpt/disk0
newfs -U gpt/disk0
gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ada0

# mount
mount -t ufs /dev/gpt/disk0 /mnt/

# align disks
#gnop create -S 4096 /dev/gpt/disk0
#zpool create -o altroot=/mnt -o cachefile=/tmp/zpool.cache zroot /dev/gpt/disk0.nop
#zpool export zroot
#gnop destroy /dev/gpt/disk0.nop
#zpool import -o altroot=/mnt -o cachefile=/tmp/zpool.cache zroot

#zpool set bootfs=zroot zroot
#zfs set checksum=fletcher4 zroot

# set up zfs pools
#zfs create zroot/usr
#zfs create zroot/usr/home
#zfs create zroot/var
#zfs create -o compression=on   -o exec=on  -o setuid=off zroot/tmp
#zfs create -o compression=lzjb             -o setuid=off zroot/usr/ports
#zfs create -o compression=off  -o exec=off -o setuid=off zroot/usr/ports/distfiles
#zfs create -o compression=off  -o exec=off -o setuid=off zroot/usr/ports/packages
#zfs create -o compression=lzjb -o exec=off -o setuid=off zroot/usr/src
#zfs create -o compression=lzjb -o exec=off -o setuid=off zroot/var/crash
#zfs create                     -o exec=off -o setuid=off zroot/var/db
#zfs create -o compression=lzjb -o exec=on  -o setuid=off zroot/var/db/pkg
#zfs create                     -o exec=off -o setuid=off zroot/var/empty
#zfs create -o compression=lzjb -o exec=off -o setuid=off zroot/var/log
#zfs create -o compression=gzip -o exec=off -o setuid=off zroot/var/mail
#zfs create                     -o exec=off -o setuid=off zroot/var/run
#zfs create -o compression=lzjb -o exec=on  -o setuid=off zroot/var/tmp

# fixup
mkdir /mnt/tmp
chmod 1777 /mnt/tmp
mkdir -p /mnt/usr/home
cd /mnt ; ln -s usr/home home
sleep 10
mkdir -p /mnt/var/tmp
chmod 1777 /mnt/var/tmp

# set up swap
#zfs create -V 2G zroot/swap
#zfs set org.freebsd:swap=on zroot/swap
#zfs set checksum=off zroot/swap

# Install the OS
cd /usr/freebsd-dist
cat base.txz | tar --unlink -xpJf - -C /mnt
cat lib32.txz | tar --unlink -xpJf - -C /mnt
cat kernel.txz | tar --unlink -xpJf - -C /mnt
cat src.txz | tar --unlink -xpJf - -C /mnt

# cp /tmp/zpool.cache /mnt/boot/zfs/zpool.cache

sleep 10
# Enable required services
cat >> /mnt/etc/rc.conf << EOT
hostname="${NAME}"
ifconfig_em0="dhcp"
sshd_enable="YES"
EOT

# Tune and boot from zfs
cat >> /mnt/boot/loader.conf << EOT
vm.kmem_size="200M"
vm.kmem_size_max="200M"
EOT

# Enable swap
echo \
'/dev/gpt/disk0 / ufs rw 0 0
' > /mnt/etc/fstab

# Install a few requirements
echo 'nameserver 8.8.8.8' > /mnt/etc/resolv.conf

# Set up user accounts
echo "vagrant" | pw -V /mnt/etc useradd vagrant -h 0 -s csh -G wheel -d /home/vagrant -c "Vagrant User"
echo "vagrant" | pw -V /mnt/etc usermod root -h 0

mkdir /mnt/home/vagrant
chown 1001:1001 /mnt/home/vagrant

# Fix su permissions
sed -i.bak 's/requisite/sufficient/' /mnt/etc/pam.d/su

# Reboot
reboot

