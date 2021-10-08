TMPDIR="/opt"
cd $TMPDIR

#Download utf-8 encoding capability on the omsagent container.
#upgrade apt to latest version
apt-get update && apt-get install -y apt && DEBIAN_FRONTEND=noninteractive apt-get install -y locales

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

#install oneagent - Official bits (10/7/2021)
wget https://github.com/microsoft/Docker-Provider/releases/download/1.14/azure-mdsd_1.14.0-build.master.279_x86_64.deb

/usr/bin/dpkg -i $TMPDIR/azure-mdsd*.deb
cp -f $TMPDIR/mdsd.xml /etc/mdsd.d
cp -f $TMPDIR/envmdsd /etc/mdsd.d

#log rotate conf for mdsd and can be extended for other log files as well
cp -f $TMPDIR/logrotate.conf /etc/logrotate.d/ci-agent

#download inotify tools for watching configmap changes
sudo apt-get update
sudo apt-get install inotify-tools -y

#used to parse response of kubelet apis
#ref: https://packages.ubuntu.com/search?keywords=jq
sudo apt-get install jq=1.5+dfsg-2 -y

#used to setcaps for ruby process to read /proc/env
sudo apt-get install libcap2-bin -y

wget https://dl.influxdata.com/telegraf/releases/telegraf-1.18.0_linux_amd64.tar.gz
tar -zxvf telegraf-1.18.0_linux_amd64.tar.gz

mv /opt/telegraf-1.18.0/usr/bin/telegraf /opt/telegraf

chmod 777 /opt/telegraf

# Use wildcard version so that it doesnt require to touch this file
/$TMPDIR/docker-cimprov-*.*.*-*.x86_64.sh --install

#download and install fluent-bit(td-agent-bit)
wget -qO - https://packages.fluentbit.io/fluentbit.key | sudo apt-key add -
sudo echo "deb https://packages.fluentbit.io/ubuntu/xenial xenial main" >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install td-agent-bit=1.6.8 -y

# install ruby2.6
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F5DA5F09C3173AA6
sudo echo "deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu bionic main" >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install ruby2.6 ruby2.6-dev gcc make -y
# fluentd v1 gem
gem install fluentd -v "1.12.2" --no-document
fluentd --setup ./fluent
gem install gyoku iso8601 --no-doc


rm -f $TMPDIR/docker-cimprov*.sh
rm -f $TMPDIR/azure-mdsd*.deb
rm -f $TMPDIR/mdsd.xml
rm -f $TMPDIR/envmdsd

# remove build dependencies
sudo apt-get remove ruby2.6-dev gcc make -y

# Remove settings for cron.daily that conflict with the node's cron.daily. Since both are trying to rotate the same files
# in /var/log at the same time, the rotation doesn't happen correctly and then the *.1 file is forever logged to.
rm /etc/logrotate.d/alternatives /etc/logrotate.d/apt /etc/logrotate.d/azure-mdsd /etc/logrotate.d/rsyslog

#Remove gemfile.lock for http_parser gem 0.6.0
#see  - https://github.com/fluent/fluentd/issues/3374 https://github.com/tmm1/http_parser.rb/issues/70
if [  -e "/var/lib/gems/2.6.0/gems/http_parser.rb-0.6.0/Gemfile.lock" ]; then
      #rename
      echo "Renaming unused gemfile.lock for http_parser 0.6.0"
      mv /var/lib/gems/2.6.0/gems/http_parser.rb-0.6.0/Gemfile.lock /var/lib/gems/2.6.0/gems/http_parser.rb-0.6.0/renamed_Gemfile_lock.renamed
fi
