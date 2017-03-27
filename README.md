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
# Install Node.js
curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - && sudo apt-get install -y nodejs

npm install && npm link

# "username" is the default user the services should run under
# it will also have write rights to /app/hosting/dir
nodehost setup /app/hosting/dir username --install-dependencies
```

After installation:

```bash
nodehost help
nodehost list
sudo nodehost create example.com
sudo nodehost disable example.com
sudo nodehost enable example.com
sudo nodehost remove example.com
```

`example.com` will have the following paths: 

- Location: `/app/hosting/dir/example.com`
- Service execution file: `/app/hosting/dir/example.com/example.com`
- www dir: `/app/hosting/dir/example.com/www`
- static files dir: `/app/hosting/dir/example.com/www/public`
