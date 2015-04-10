#!/bin/bash
set -e 
export LUA_VERSION=5.1.5
export LUAROCKS_VERSION=2.2.1
export OPENRESTY_VERSION=1.7.10.1
export KONG_VERSION=0.1.1beta-2
export FPM_OPTIONS="--vendor Mashape --license MIT --url http://getkong.org --description 'Kong is an open distributed platform for your APIs, focused on high performance and reliability.' -m 'support@mashape.com'"

if [[ -z $AWS_ACCESS_KEY_ID && -z $AWS_SECRET_ACCESS_KEY && -z $AWS_BUCKET ]] ; then
    echo "Please set variables"
    echo "export AWS_ACCESS_KEY_ID=<KEY_ID>"
    echo "export AWS_SECRET_ACCESS_KEY=<SECRET_KEY>"
    echo "export AWS_BUCKET=<BUCKET_NAME>"
    exit 0
fi

rm -f /mnt/kong*
apt-get update && apt-get -y install docker.io ruby ruby-dev  zlib1g-dev python-pip createrepo
apt-get -y install wget tar make gcc g++ libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl unzip git ruby-dev rpm
gem install deb-s3
pip install s3cmd
ln -sf /usr/bin/docker.io /usr/local/bin/docker
sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io
update-rc.d docker.io defaults
docker pull ubuntu

mkdir -p /root/kong_builder

FILE=/root/kong_builder/Dockerfile

/bin/cat <<EOM >${FILE}
#Base image
FROM ubuntu:14.04.2

MAINTAINER n.serev@gmail.com
ADD /build_setup.sh /root/
ADD /list_files /root/
EOM

DIR_LIST=/root/kong_builder/list_files
/bin/cat <<EOF >${DIR_LIST}
/usr/local/bin
/usr/local/include
/usr/local/lib/luarocks/rocks
/usr/local/man/man1
/usr/local/share/lua/5.1
/usr/local/lib/lua/5.1
/usr/local/etc/luarocks
/usr/local/openresty
/etc/kong
EOF

BUILD_SETUP=/root/kong_builder/build_setup.sh
/bin/cat <<EOF >${BUILD_SETUP}
#!/bin/bash

apt-get update && apt-get -y install wget tar make gcc g++ libreadline-dev libncurses5-dev libpcre3-dev libssl-dev perl unzip git ruby-dev rpm
gem install fpm

cd /tmp
wget http://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz
tar xzf lua-$LUA_VERSION.tar.gz
cd lua-$LUA_VERSION

make linux
make install

cd /tmp
wget http://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz
tar xzf luarocks-$LUAROCKS_VERSION.tar.gz
cd luarocks-$LUAROCKS_VERSION
./configure
make build
make install

cd /tmp
wget http://openresty.org/download/ngx_openresty-$OPENRESTY_VERSION.tar.gz
tar xzf ngx_openresty-$OPENRESTY_VERSION.tar.gz
cd ngx_openresty-$OPENRESTY_VERSION
./configure --with-pcre-jit --with-ipv6 --with-http_realip_module --with-http_ssl_module --with-http_stub_status_module

make
make install

luarocks install kong $KONG_VERSION

mkdir -p /etc/kong
cp /usr/local/lib/luarocks/rocks/kong/$KONG_VERSION/conf/kong.yml /etc/kong/kong.yml

cd /root
fpm -s dir -t deb -n kong -v ${KONG_VERSION} --inputs /root/list_files ${FPM_OPTIONS}
fpm -s dir -t rpm -n kong -v ${KONG_VERSION} --inputs /root/list_files ${FPM_OPTIONS}
cp kong* /mnt
EOF

chmod +x  ~/kong_builder/build_setup.sh
cd ~/kong_builder
#Start the rpm and deb package build
docker build --no-cache -t kong_builder --force-rm .
docker run -t -i -v /mnt:/mnt kong_builder /root/build_setup.sh
#Updating deb repo
deb-s3 upload -c `lsb_release -sc` --bucket ${AWS_BUCKET} /mnt/kong*.deb
#Updating yum repo
mkdir -pv ~/kong-repo/amzn/{x86_64,noarch}/
wget https://kong-packages.s3.amazonaws.com/amzn/noarch/kong-repo-1-0.1.noarch.rpm -P kong-repo/amzn/noarch/
cp /mnt/kong*rpm ~/kong-repo/amzn/noarch/
for a in ~/kong-repo/amzn{/x86_64,/noarch} ; do createrepo -v --update --deltas $a/ ; done
s3cmd -P sync --access_key=${AWS_ACCESS_KEY_ID} --secret_key=${AWS_SECRET_ACCESS_KEY} ~/kong-repo/amzn/ s3://kong-packages/amzn/ --delete-removed
