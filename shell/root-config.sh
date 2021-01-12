#!/bin/bash
sys_version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
ports=`grep "listen" /opt/nginx/conf/conf.d/*.conf|awk '{print $3}'| sed 's/;//g'`
for i in ${ports[@]};do
    if [[ "$sys_version" == "6" ]];then
	iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport $i -j ACCEPT
	#保存
	/etc/rc.d/init.d/iptables save
        #重载
        service iptables restart
	/bin/bash ./shell/el6-service.sh
    elif [[ "$sys_version" == "7" ]];then
	firewall-cmd --zone=public --add-port=$i/tcp --permanent
	firewall-cmd --reload
	/bin/bash ./shell/el7-service.sh
    else 
	echo "Don't support current system!"
    fi
done

# split logfile
if [[ ! -f /etc/logrotate.d/nginx ]];then
    tee /etc/logrotate.d/nginx < ./logrotate.d/nginx
    sed -i "s#/opt#${ngx_dir}#g" /etc/logrotate.d/nginx
    sed -i '/\/etc\/logrotate.d\/nginx/d' /etc/crontab
    echo "0 0 * * * root bash /usr/sbin/logrotate -f /etc/logrotate.d/nginx" >> /etc/crontab
fi

# modify open files num
if [[ `ulimit -n` -le 65535 ]] ;then
    echo "* soft nofile 655350" >> /etc/security/limits.conf
    echo "* hard nofile 655350" >> /etc/security/limits.conf
    echo "* soft nproc 65535" >> /etc/security/limits.conf
    echo "* hard nproc 65535" >> /etc/security/limits.conf
    ulimit -n 655350
fi

chmod +s ${ngx_dir}/nginx/sbin/nginx
chmod a+rw ${ngx_dir}/nginx/conf/conf.d/
chown ${ngx_user}.${ngx_user} /static

tee /usr/local/sbin/nginx-bakup < ./shell/nginx-bakup
chmod +x /usr/local/sbin/nginx-bakup
sed -i '/nginx-bak.sh/d' /etc/crontab
echo "0 0 * * * root bash /usr/local/sbin/nginx-bak.sh" >> /etc/crontab

rpm -ivh ./src/filebeat-7.4.2-x86_64.rpm
chkconfig filebeat on	
service filebeat start	
cp -r -v ./src/filebeat.yml /etc/filebeat/filebeat.yml
service filebeat restart
