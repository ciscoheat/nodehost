#!/usr/bin/env bash

# Nodehost startup file, do not change the file name! It is used by systemd.
# The & for nodemon is required to allow editing of this file, when the service is running:

nodemon --quiet --ignore public/ app.js & 
