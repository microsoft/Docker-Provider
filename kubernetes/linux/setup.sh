#!/bin/bash

TMPDIR="/opt"
cd $TMPDIR

if [ -z $1 ]; then
    ARCH="amd64"
else
    ARCH=$1
fi

sudo tdnf install ca-certificates-microsoft -y
sudo update-ca-trust

# sudo tdnf install ruby-3.1.3 -y
tdnf install -y gcc patch bzip2 openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel
wget https://github.com/rbenv/ruby-build/archive/refs/tags/v20230330.tar.gz -O ruby-build.tar.gz
tar -xzf ruby-build.tar.gz
PREFIX=/usr/local ./ruby-build-*/install.sh
ruby-build 3.1.3 /usr

# clean up the ruby-build files
rm ruby-build.tar.gz
rm -rf ruby-build-*

# remove unused default gem openssl, find as they have some known vulns
rm /usr/lib/ruby/gems/3.1.0/specifications/default/openssl-3.0.1.gemspec
rm -rf /usr/lib/ruby/gems/3.1.0/gems/openssl-3.0.1
rm /usr/lib/ruby/gems/3.1.0/specifications/default/find-0.1.1.gemspec
rm -rf /usr/lib/ruby/gems/3.1.0/gems/find-0.1.1

if [ "${ARCH}" != "arm64" ]; then
    wget "https://github.com/microsoft/Docker-Provider/releases/download/official%2Fmdsd%2F1.26.1/azure-mdsd-1.26.1-build.master.97.x86_64.rpm" -O azure-mdsd.rpm
else
    wget "https://github.com/microsoft/Docker-Provider/releases/download/official%2Fmdsd%2F1.26.1/azure-mdsd-1.26.1-build.master.97.aarch64.rpm" -O azure-mdsd.rpm
fi
sudo tdnf install -y azure-mdsd.rpm
cp -f $TMPDIR/mdsd.xml /etc/mdsd.d
cp -f $TMPDIR/envmdsd /etc/mdsd.d
rm /usr/sbin/telegraf
rm azure-mdsd.rpm

mdsd_version=$(sudo tdnf list installed | grep mdsd | awk '{print $2}')
echo "Azure mdsd: $mdsd_version" >> packages_version.txt

# log rotate conf for mdsd and can be extended for other log files as well
cp -f $TMPDIR/logrotate.conf /etc/logrotate.d/ci-agent

#download inotify tools for watching configmap changes
sudo tdnf check-update -y
sudo tdnf install inotify-tools -y

#used to parse response of kubelet apis
#ref: https://packages.ubuntu.com/search?keywords=jq
sudo tdnf install jq-1.6-1.cm2 -y

#used to setcaps for ruby process to read /proc/env
sudo tdnf install libcap -y

sudo tdnf install telegraf-1.25.2 -y
telegraf_version=$(sudo tdnf list installed | grep telegraf | awk '{print $2}')
echo "telegraf $telegraf_version" >> packages_version.txt
mv /usr/bin/telegraf /opt/telegraf

# Use wildcard version so that it doesnt require to touch this file
/$TMPDIR/docker-cimprov-*.*.*-*.*.sh --install
docker_cimprov_version=$(sudo tdnf list installed | grep docker-cimprov | awk '{print $2}')
echo "DOCKER_CIMPROV_VERSION=$docker_cimprov_version" >> packages_version.txt

#install fluent-bit
sudo tdnf install fluent-bit-2.0.9 -y
echo "$(fluent-bit --version)" >> packages_version.txt

# install fluentd using the mariner package
# sudo tdnf install rubygem-fluentd-1.14.6 -y
gem install fluentd -v "1.14.6" --no-document
echo "$(fluentd --version)" >> packages_version.txt
fluentd --setup ./fluent

gem install gyoku iso8601 bigdecimal --no-doc
gem install tomlrb -v "2.0.1" --no-document


rm -f $TMPDIR/docker-cimprov*.sh
rm -f $TMPDIR/mdsd.xml
rm -f $TMPDIR/envmdsd

# Remove settings for cron.daily that conflict with the node's cron.daily. Since both are trying to rotate the same files
# in /var/log at the same time, the rotation doesn't happen correctly and then the *.1 file is forever logged to.
rm /etc/logrotate.d/azure-mdsd
