#!/usr/bin/env bash

# The & is required, to allow editing of this file after the service has started:
nodemon --ignore public/ app.js & 
