#!/usr/bin/env bash

echo "=== Setting password for user ubuntu to ubuntu"

echo "ubuntu:ubuntu" | chpasswd

echo "=== Starting provision script..."

cd /vagrant

echo "=== Updating apt..."
apt-get update >/dev/null 2>&1

# Used in many dependencies:
apt-get install python-software-properties curl git -y

echo "=== Installing Node.js 6.x..."
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && sudo apt-get install -y nodejs

sudo -u ubuntu -i mkdir /home/ubuntu/.npm-global
sudo -u ubuntu -i npm config set prefix '~/.npm-global'

sudo -u ubuntu -i cat >> /home/ubuntu/.profile <<EOL
PATH=~/.npm-global/bin:\$PATH
cd /vagrant
EOL

# Install Haxe
add-apt-repository ppa:haxe/releases -y
apt-get update
apt-get install haxe -y
sudo -u ubuntu -i mkdir /home/ubuntu/haxelib 
sudo -u ubuntu -i haxelib setup /home/ubuntu/haxelib

# First time build
sudo -u ubuntu -i npm install
sudo -u ubuntu -i haxelib install nodehost.hxml --always --quiet
sudo -u ubuntu -i npm run build
sudo -u ubuntu -i npm link

# Run to see if it works
sudo -u ubuntu -i nodehost help

echo "=== Provision script finished!"
echo "Start with 'vagrant ssh'"
