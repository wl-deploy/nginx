cat > /usr/lib/systemd/system/nginx.service <<EOF
 
[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target
 
[Service]
Type=forking
ExecStartPre=${ngx_dir}/nginx/sbin/nginx -t
ExecStart=${ngx_dir}/nginx/sbin/nginx -c ${ngx_dir}/nginx/conf/nginx.conf
ExecReload=${ngx_dir}/nginx/sbin/nginx -s reload
ExecStop=${ngx_dir}/nginx/sbin/nginx -s stop
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
EOF

systemctl enable nginx.service
#systemctl start nginx.service
