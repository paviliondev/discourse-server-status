#!/bin/sh

cd /var/discourse/shared/standalone/discourse-plugin-manager && git pull
cd /var/discourse && ./launcher rebuild app
