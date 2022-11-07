#!/bin/bash

TMPDIR="/opt"
cd $TMPDIR

if [ -z $1 ]; then
    ARCH="amd64"
else
    ARCH=$1
fi

#Download utf-8 encoding capability on the ama-logs container.
#upgrade apt to latest version
apt-get update && apt-get install -y apt && DEBIAN_FRONTEND=noninteractive apt-get install -y locales


curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
curl -sSL https://get.rvm.io | bash -s stable

# setup paths for ruby and rvm
if [ -f /etc/profile.d/rvm.sh ]; then
    source /etc/profile.d/rvm.sh
    echo "[ -f /etc/profile.d/rvm.sh ] && source /etc/profile.d/rvm.sh" >> ~/.bashrc
fi

rvm install 3.1.1
rvm --default use 3.1.1

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

#install oneagent - Official bits (3/14/2022)
if [ "${ARCH}" != "arm64" ]; then
    wget "https://github.com/microsoft/Docker-Provider/releases/download/official%2Fmdsd%2F1.23.3/azure-mdsd_1.23.3-build.master.24_x86_64.deb" -O azure-mdsd.deb
else
    wget "https://github.com/microsoft/Docker-Provider/releases/download/official%2Fmdsd%2F1.23.3/azure-mdsd_1.23.3-build.master.24_aarch64.deb" -O azure-mdsd.deb
fi

/usr/bin/dpkg -i $TMPDIR/azure-mdsd*.deb
cp -f $TMPDIR/mdsd.xml /etc/mdsd.d
cp -f $TMPDIR/envmdsd /etc/mdsd.d
rm /usr/sbin/telegraf

# log rotate conf for mdsd and can be extended for other log files as well
cp -f $TMPDIR/logrotate.conf /etc/logrotate.d/ci-agent

#download inotify tools for watching configmap changes
sudo apt-get update
sudo apt-get install inotify-tools -y

#used to parse response of kubelet apis
#ref: https://packages.ubuntu.com/search?keywords=jq
sudo apt-get install jq=1.5+dfsg-2 -y

#used to setcaps for ruby process to read /proc/env
sudo apt-get install libcap2-bin -y

wget https://dl.influxdata.com/telegraf/releases/telegraf-1.23.2_linux_$ARCH.tar.gz
tar -zxvf telegraf-1.23.2_linux_$ARCH.tar.gz

mv /opt/telegraf-1.23.2/usr/bin/telegraf /opt/telegraf

chmod 544 /opt/telegraf

# Use wildcard version so that it doesnt require to touch this file
/$TMPDIR/docker-cimprov-*.*.*-*.*.sh --install

#download and install fluent-bit(td-agent-bit)
wget -qO - https://packages.fluentbit.io/fluentbit.key | sudo apt-key add -
sudo echo "deb https://packages.fluentbit.io/ubuntu/bionic bionic main" >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install td-agent-bit=1.7.8 -y

# fluentd v1 gem
gem install fluentd -v "1.14.6" --no-document
fluentd --setup ./fluent
gem install gyoku iso8601 --no-doc
gem install tomlrb -v "2.0.1" --no-document


rm -f $TMPDIR/docker-cimprov*.sh
rm -f $TMPDIR/azure-mdsd*.deb
rm -f $TMPDIR/mdsd.xml
rm -f $TMPDIR/envmdsd
rm -f $TMPDIR/telegraf-*.tar.gz

# remove build dependencies
sudo apt-get remove gcc make -y
sudo apt autoremove -y

# Remove settings for cron.daily that conflict with the node's cron.daily. Since both are trying to rotate the same files
# in /var/log at the same time, the rotation doesn't happen correctly and then the *.1 file is forever logged to.
rm /etc/logrotate.d/alternatives /etc/logrotate.d/apt /etc/logrotate.d/azure-mdsd /etc/logrotate.d/rsyslog
