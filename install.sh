#!/bin/bash

# Install dependencies
apt-get update
apt-get install -y nginx docker.io lsof

# Set up systemd service
cp devopsfetch.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable devopsfetch.service
systemctl start devopsfetch.service

# Set up log rotation
cat <<EOL > /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    postrotate
        systemctl restart devopsfetch.service
    endscript
}
EOL

