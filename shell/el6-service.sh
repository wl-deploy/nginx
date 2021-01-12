#!/usr/bin/env bash
cp ./shell/nginx /etc/rc.d/init.d/
chmod +x /etc/rc.d/init.d/nginx
chkconfig nginx on
service nginx start
