#!/usr/bin/env bash

echo "=== Setting password for user ubuntu to ubuntu"

echo "ubuntu:ubuntu" | chpasswd

echo "=== Starting provision script..."

cd /vagrant

echo "=== Adding 'cd /vagrant' to .profile"
cat >> /home/ubuntu/.profile <<EOL

cd /vagrant
EOL

echo "=== Updating apt..."
apt-get update >/dev/null 2>&1

# Used in many dependencies:
apt-get install python-software-properties curl git -y

echo "=== Renaming host..."
sed -i "s/`cat /etc/hostname`/nodehost/g" /etc/hosts
echo nodehost > /etc/hostname
systemctl restart systemd-logind.service

echo "=== Provision script finished!"
echo "Start with 'vagrant reload && vagrant ssh'."
echo "Change timezone: sudo dpkg-reconfigure tzdata"
