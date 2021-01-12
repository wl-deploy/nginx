#!/bin/bash
## Do for Red Hat && CentOS && NeoKylin ##
##########################################

# check dependencies && try to install
#set -euo pipefail
#trap "echo 'error: Script failed: see failed command above'" ERR

if [[ `id -u` -eq 0 ]];then
  export ngx_dir=${1:-/opt}
else
  export ngx_dir=${1:-$HOME}
fi

# shellcheck disable=SC2006
export ngx_version=`cd ./src && ls nginx-*tar.gz|sort -r|sed 's/.tar.gz//g'`
# shellcheck disable=SC2006
export sys_version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
export ngx_user="nginx"

[[ `id -u` -eq 0 ]] && useradd -m nginx;echo "1234%^&*" | passwd --stdin neusnginxoft

# check nginx had been installed or not
if [[ -d ${ngx_dir}/nginx ]];then
  echo -e "\e[36mNginx has beened installed in the default directory,will you overlay the current nginx?\e[0m"
  echo -e "\e[36mPlease input yes or no.\e[0m"
  read -t 5 -p "yes | no: " entry
  if [[ "$entry" != "yes" ]];then
	  exit
  else
	  echo "$entry"
  fi
fi

NGINX_DEPENDEMCE=(gcc pcre-devel zlib-devel)
## install dependencies
set -x
check_dep=0
for i in ${NGINX_DEPENDEMCE[@]}
do
  # 检测是否已安装
  rpm -qa|grep "^${i}" &> /dev/null
  if [[ $? -eq 0 ]]; then
    echo "check dependence ${i} pass..."
  else
    yum install -y ${i}
    if [[ $? -eq 0 ]]; then
      echo "check dependence ${i} failed, check yum..."
    fi
  fi
done
set +x

# check user
egrep "^$ngx_user" /etc/passwd &> /dev/nul
if [[ $? -ne 0 ]] && [[ `id -u` -eq 0 ]];then
    useradd -m ${ngx_user}  && echo "1234%^&*" | passwd --stdin ${ngx_user}
fi

# extract tarball
for i in `find src -name *.gz`
   do
     tar zxvf $i -C ./src/tmp
done

# make perl5
echo "install perl5..."
if [[ -x ./src/tmp/perl-5.28.0 ]];then
  cd ./src/tmp/perl-5.28.0 && ./Configure -des -Dprefix=/usr/local/perl -Dusethreads -Uversiononly
  make -j $(nproc) && make install
  if [[ -f /usr/bin/perl ]];then
    mv /usr/bin/perl /usr/bin/perl.old
  fi
  ln -s /usr/local/perl/bin/perl /usr/bin/perl
  perl -v
  cd -
fi


# make install lua
if [[ -x ./src/tmp/LuaJIT-2.0.5 ]] && [[ ! -d /usr/local/lj2 ]];then
  cd ./src/tmp/LuaJIT-2.0.5 && make -j $(nproc) && \
  make install PREFIX=/usr/local/lj2 && \
  export LUAJIT_LIB=/usr/local/lj2/lib && \
  export LUAJIT_INC=/usr/local/lj2/include/luajit-2.0 && \
  sed -i '/\/usr\/local\/lib/d' /etc/ld.so.conf && \
  echo "/usr/local/lib" >> /etc/ld.so.conf && \
  ldconfig && ln -s /usr/local/lj2/lib/libluajit-5.1.so.2 /lib64/libluajit-5.1.so.2 && \
  ln -s /usr/local/lj2/lib/libluajit-5.1.so.2 /lib/libluajit-5.1.so.2
  cd -
else
    export LUAJIT_LIB=/usr/local/lj2/lib
    export LUAJIT_INC=/usr/local/lj2/include/luajit-2.0
fi


# install goaccess
#if [ -d ./src/tmp/goaccess-1.3 ];then
#    cd ./src/tmp/goaccess-1.3
    #./configure --enable-utf8 --enable-geoip=legacy --with-openssl=../openssl-1.0.2r --sysconfdir=/etc/
#    ./configure --enable-utf8
#    make -j2 && make install
#    cd -
#    ln -s /usr/local/bin/goaccess /usr/bin/goaccess
#fi

function FNC_INSTALL_NGX() {
  cd ./src/tmp/${ngx_version} && /bin/bash ../../configure
  if [[ $? -ne 0 ]]; then
      return 1
  else
      make -j $(nproc) && make install && cd -
      if [[ $? -ne 0 ]]; then
	  return 1
      fi
      return 0
  fi
};FNC_INSTALL_NGX && [[ $? -ne 0 ]] && exit 1

# create dirs
for i in ${ngx_dir}/nginx/cache ~/.vim
do
  mkdir -p $i
done

sed -i "s#/usr/local#${ngx_dir}#g" ${ngx_dir}/nginx/conf/nginx.conf
#nginx vim style
cp -r ./src/tmp/${ngx_version}/contrib/vim/* ~/.vim/

cp -r -v ./conf/* ${ngx_dir}/nginx/conf/

cat > ~/.vim/filetype.vim <<EOF
au BufRead,BufNewFile ${ngx_dir}/nginx/conf/conf.d/*.conf set ft=nginx
EOF

#拷贝错误页
cp -r -v ./html ${ngx_dir}/nginx/

#拷贝索引页面主题
[[ `id -u` -eq 0 ]] && cp -r -v ./static /

#清理安装包
[[ -d ./src/tmp ]] && rm -rf ./src/tmp/*

# root config
if [[ `id -u` -eq 0 ]];then
  /bin/bash ./shell/root-config.sh
  mkdir -p /static/www && chown -R neusoft.neusoft /static
else
    sed -i "s#user root;##g" ${ngx_dir}/nginx/conf/nginx.conf
fi

# 配置中文
#if [ "$sys_version" == "6" ];then
#    echo "to do"
#    exit
#elif [ "$sys_version" == "7" ];then
#    yum install kde-l10n-Chinese -y
#    yum reinstall glibc-common -y
#    echo "LANG=\"zh_CN.UTF-8\"" > /etc/locale.conf
#    source /etc/locale.conf
#fi

# ngx command alias
cat >> ~/.bashrc <<EOF
alias ng.start='ng.test && ${ngx_dir}/nginx/sbin/nginx -c ${ngx_dir}/nginx/conf/nginx.conf'
alias ng.test='${ngx_dir}/nginx/sbin/nginx -t -c ${ngx_dir}/nginx/conf/nginx.conf'
alias ng.stop='ng.test && ${ngx_dir}/nginx/sbin/nginx -s stop'
alias ng.reload='ng.test && ${ngx_dir}/nginx/sbin/nginx -s reload'
alias ng.log='/usr/local/bin/goaccess -f ${ngx_dir}/nginx/logs/access.log --real-time-html -o ${ngx_dir}/nginx/html/report.html --time-format='%H:%M:%S' --date-format='%d/%b/%Y' --log-format=COMBINED'
EOF
. ~/.bashrc
${ngx_dir}/nginx/sbin/nginx
