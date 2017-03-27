# nodehost

Quick Node.js hosting on ubuntu:

- Multiple Node apps, served with nginx (virtual host)
- Service based (systemd)
- Can be set to separate user per service
- Restarts automatically using nodemon
- SSL support with letsencrypt
- *Alpha version*

## Install

As root, in the repo dir:

```bash
# Install Node.js if needed
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && sudo apt-get install -y nodejs

# First time build
npm install && npm run build

# For shell usage
npm link

# "username" is the default user the services should run under, for example "ubuntu".
# That user will also have write rights to "/app/hosting/dir"
nodehost setup /app/hosting/dir username --install-dependencies
```

## Building

```bash
npm run build
```

## Running

```
nodehost help
nodehost list
sudo nodehost create example.com
sudo nodehost <restart/disable/enable/remove> example.com
nodehost status example.com
```

## Useful files and dirs

After creating a host, `example.com` will have some points of interest:

- Base dir: `/app/hosting/dir/example.com`
- Service execution file: `/app/hosting/dir/example.com/example.com`
- www dir: `/app/hosting/dir/example.com/www`
- static files dir: `/app/hosting/dir/example.com/www/public`

Default behavior for the service execution file is to start nodemon for an `app.js` file in the `www` dir. Change the content as suited, but don't change the filename, since systemd depends on it.

Other useful locations for nodehost itself:

`/etc/nginx/nodehost.conf.json` - configuration file, created during setup
`/etc/nginx/sites-available/nodehost*.conf` - nginx files for each host
`/etc/systemd/system/nodehost*.service` - systemd files for each host

## SSL/TLS/HTTPS

`/etc/nginx/sites-available/nodehost*.conf` contains details for generating either a self-signed certificate, or a real one with `letsencrypt`. Note that only nginx is using the cert, the proxied connection between nginx and the Node app is http only (because they're on the same server).
