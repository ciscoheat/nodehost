#!/usr/bin/env bash

# systemd execution file for nodehost, do not change the file name!
# Working directory is www.
# The & at the end is required to allow editing of this file, when the service is running:

`npm bin -g`/nodemon --quiet --ignore public/ app.js & 
