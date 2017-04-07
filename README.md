# nodehost

Quick Node.js hosting on ubuntu:

- Multiple Node apps, served with nginx (as virtual hosts)
- Service based (systemd)
- Can be set to separate user per service
- Restarts automatically on file update using nodemon
- SSL support with letsencrypt/certbot
- *Alpha version*

## Install for using

As the user that should be the administrator of the hosting:

```bash
# Install Node.js if needed
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && sudo apt-get install -y nodejs

npm install -g node-host
nodehost setup /hosting/dir --install-dependencies
```

(If you cannot install globally with a non-root user, check out [how to fix the npm permissions](https://docs.npmjs.com/getting-started/fixing-npm-permissions).)

## Install for building/development

As the user that should be the administrator of the hosting:

```bash
# Install Node.js if needed
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && sudo apt-get install -y nodejs

# Install Haxe if needed
sudo add-apt-repository ppa:haxe/releases -y
sudo apt-get update
sudo apt-get install haxe -y
mkdir ~/haxelib && haxelib setup ~/haxelib

# Clone the repo
git clone https://github.com/ciscoheat/nodehost.git && cd nodehost

# First time build
npm install
haxelib install nodehost.hxml
npm run build && npm link

# Setup
nodehost setup /hosting/dir --install-dependencies
```

### Building

```bash
npm run build
```

## Running

```
nodehost help
nodehost <command> [options...]
```

## Useful files and dirs

After creating a host, `example.com` will have some points of interest:

- Base dir: `/hosting/dir/example.com`
- Service execution file: `/hosting/dir/example.com/example.com`
- www dir: `/hosting/dir/example.com/www`
- static files dir: `/hosting/dir/example.com/www/public`

Default behavior for the service execution file is to start nodemon for an `app.js` file in the `www` dir. Change the content as suited, but don't change the filename, since systemd depends on it.

Other useful locations for nodehost itself:

- `/etc/nginx/nodehost.conf.json` - configuration file, created during setup
- `/etc/nginx/sites-available/nodehost*.conf` - nginx files for each host
- `/etc/systemd/system/nodehost*.service` - systemd files for each host

## SSL/TLS/HTTPS

`/etc/nginx/sites-available/nodehost*.conf` contains details for generating either a self-signed certificate, or a real one with `certbot`. Note that only nginx is using the cert, the proxied connection between nginx and the Node app is http only (because they're on the same server).

## How to uninstall

Until an uninstall command is in place:

1. `nodehost remove <hostname>` for all hosts
1. Delete `/etc/nginx/nodehost.conf.json`
1. Delete `/hosting/dir`
