#!/bin/bash -x
set -e

mkdir -p /app
mkdir /app/local
mkdir /app/local/lib
mkdir /app/local/bin
mkdir /app/local/include
mkdir /app/apache
mkdir /app/php

cd /tmp
curl -O https://mirrors.edge.kernel.org/ubuntu/pool/universe/m/mcrypt/mcrypt_2.6.8-6_amd64.deb
curl -O https://mirrors.edge.kernel.org/ubuntu/pool/universe/libm/libmcrypt/libmcrypt4_2.5.8-7_amd64.deb
curl -O https://mirrors.edge.kernel.org/ubuntu/pool/universe/libm/libmcrypt/libmcrypt-dev_2.5.8-7_amd64.deb
ls -tr *.deb > packages.txt
while read l; do
    ar x $l
    file data.tar.zst
    tar xvf data.tar.zst
    rm data.tar.zst
done < packages.txt

cp -a /tmp/usr/include/* /app/local/include
cp -a /tmp/usr/lib/* /app/local/lib
cp -a /tmp/usr/lib/x86_64-linux-gnu/* /app/local/lib/

export APACHE_MIRROR_HOST="https://downloads.apache.org/"
export HTTPD_VERSION=2.4.54
export APR_VERSION=1.7.0
export APR_UTIL_VERSION=1.6.1
export ZLIB_VERSION=1.2.12
export PHP_VERSION=5.6.40
export PCRE_VERSION=8.45
export EXPAT_VERSION=2.4.8
export LIBXML2_VERSION=2.9.14
export OPENSSL_VERSION=1_1_1q
export CURL_VERSION=7.84.0


echo "downloading pcre"
curl -L https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz/download -o /tmp/pcre-${PCRE_VERSION}.tar.gz
echo "downloading apr"
curl -L ${APACHE_MIRROR_HOST}/apr/apr-${APR_VERSION}.tar.gz -o /tmp/apr-${APR_VERSION}.tar.gz
echo "downloading apr-util"
curl -L ${APACHE_MIRROR_HOST}/apr/apr-util-${APR_UTIL_VERSION}.tar.gz -o /tmp/apr-util-${APR_UTIL_VERSION}.tar.gz
echo "downloading httpd"
curl -L ${APACHE_MIRROR_HOST}/httpd/httpd-${HTTPD_VERSION}.tar.gz -o /tmp/httpd-${HTTPD_VERSION}.tar.gz
echo "downloading php"
curl -L http://us.php.net/get/php-${PHP_VERSION}.tar.gz/from/us2.php.net/mirror -o /tmp/php-${PHP_VERSION}.tar.gz
echo "download zlib"
curl -L http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz -o /tmp/zlib-${ZLIB_VERSION}.tar.gz
echo "downloading expat"
curl -L https://github.com/libexpat/libexpat/releases/download/R_2_4_8/expat-${EXPAT_VERSION}.tar.gz -o /tmp/expat-${EXPAT_VERSION}.tar.gz 
echo "downloading libxml2"
curl -L https://download.gnome.org/sources/libxml2/2.9/libxml2-${LIBXML2_VERSION}.tar.xz -o /tmp/libxml2-${LIBXML2_VERSION}.tar.xz

echo "downloading ssl"
curl -L https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_${OPENSSL_VERSION}.tar.gz -o /tmp/OpenSSL_${OPENSSL_VERSION}.tar.gz

echo "downloading curl"
curl -L https://github.com/curl/curl/releases/download/curl-7_84_0/curl-${CURL_VERSION}.tar.gz -o /tmp/curl-${CURL_VERSION}.tar.gz

tar -C /tmp -xzf /tmp/pcre-${PCRE_VERSION}.tar.gz
tar -C /tmp -xzf /tmp/httpd-${HTTPD_VERSION}.tar.gz

tar -C /tmp/httpd-${HTTPD_VERSION}/srclib -xzf /tmp/apr-${APR_VERSION}.tar.gz
mv /tmp/httpd-${HTTPD_VERSION}/srclib/apr-${APR_VERSION} /tmp/httpd-${HTTPD_VERSION}/srclib/apr

tar -C /tmp/httpd-${HTTPD_VERSION}/srclib -xzf /tmp/apr-util-${APR_UTIL_VERSION}.tar.gz
mv /tmp/httpd-${HTTPD_VERSION}/srclib/apr-util-${APR_UTIL_VERSION} /tmp/httpd-${HTTPD_VERSION}/srclib/apr-util

tar -C /tmp -xzf /tmp/php-${PHP_VERSION}.tar.gz
tar -C /tmp -xzf /tmp/zlib-${ZLIB_VERSION}.tar.gz
tar -C /tmp -xzf /tmp/expat-${EXPAT_VERSION}.tar.gz
tar -C /tmp -xf /tmp/libxml2-${LIBXML2_VERSION}.tar.xz
tar -C /tmp -xf /tmp/OpenSSL_${OPENSSL_VERSION}.tar.gz
tar -C /tmp -xf /tmp/curl-${CURL_VERSION}.tar.gz


export CFLAGS='-g0 -O2 -s -m64 -march=core2 -mtune=generic -pipe '
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="-I/app/local/include"
export LD_LIBRARY_PATH="/app/local/lib"
export MAKE="/usr/bin/make"

cd /tmp/zlib-${ZLIB_VERSION}
./configure --prefix=/app/local --64
${MAKE} && ${MAKE} install

cd /tmp/pcre-${PCRE_VERSION}
./configure --prefix=/app/local --enable-jit --enable-utf8
${MAKE} && ${MAKE} install

cd /tmp/expat-${EXPAT_VERSION}
./configure --prefix=/app/local
${MAKE} && ${MAKE} install

cd /tmp/openssl-OpenSSL_${OPENSSL_VERSION}
./config --prefix=/app/local --openssldir=/app/local
${MAKE} depend
${MAKE} all
${MAKE} install

cd /tmp/curl-${CURL_VERSION}
./configure --with-openssl=/app/local/ --prefix=/app/local
${MAKE} && ${MAKE} install

cd /app/local/include
ln -s /app/local/include/x86_64-linux-gnu/curl curl




cd /tmp/libxml2-${LIBXML2_VERSION}
./configure --prefix=/app/local
${MAKE} && ${MAKE} install



cd /tmp/httpd-${HTTPD_VERSION}
./configure --prefix=/app/apache --enable-rewrite --enable-so --enable-deflate --enable-expires --enable-headers --enable-proxy-fcgi --with-mpm=event --with-included-apr --with-crypto --with-openssl=/app/local/openssl/lib --with-z=/app/local --with-expat=/app/local --with-pcre=/app/local/bin/pcre-config
${MAKE} && ${MAKE} install

cd /tmp
git clone https://github.com/ByteInternet/libapache-mod-fastcgi.git
cd /tmp/libapache-mod-fastcgi/
patch -p1 < debian/patches/byte-compile-against-apache24.diff 
sed -e "s%/usr/local/apache2%/app/apache%" Makefile.AP2 > Makefile
${MAKE} && ${MAKE} install

cd /tmp/php-${PHP_VERSION}
./configure --prefix=/app/php  --with-libxml-dir=/app/local --with-iconv --with-gd --with-curl=/app/local/ --with-config-file-path=/app/php --enable-soap=shared --enable-mbstring --with-mhash --with-pear --with-jpeg-dir --with-png-dir --with-mcrypt=/app/local --enable-static --enable-fpm --with-pcre-dir=/app/local --disable-cgi --enable-zip --with-openssl-dir=/app/local
${MAKE}
${MAKE} install

/app/php/bin/pear config-set php_dir /app/php

echo '${HTTPD_VERSION}' > /app/apache/VERSION
echo '${PHP_VERSION}' > /app/php/VERSION
mkdir /tmp/build
mkdir /tmp/build/local
mkdir /tmp/build/local/lib
mkdir /tmp/build/local/lib/sasl2
cp -a /app/apache /tmp/build/
cp -a /app/php /tmp/build/
cp -aL /app/local/lib/libmcrypt.so.* /tmp/build/local/lib/
cp -aL /app/local/lib/libpcre.so.* /tmp/build/local/lib/

rm -rf /tmp/build/apache/manual/


