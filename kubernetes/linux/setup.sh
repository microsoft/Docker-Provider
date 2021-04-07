TMPDIR="/opt"
cd $TMPDIR

#Download utf-8 encoding capability on the omsagent container.
#upgrade apt to latest version
apt-get update && apt-get install -y apt && DEBIAN_FRONTEND=noninteractive apt-get install -y locales

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_v1.10.0-1/omsagent-1.10.0-1.universal.x64.sh

#create file to disable omi service startup script
touch /etc/.omi_disable_service_control

chmod 775 $TMPDIR/*.sh

#Extract omsbundle
$TMPDIR/omsagent-*.universal.x64.sh --extract
mv $TMPDIR/omsbundle* $TMPDIR/omsbundle
#Install omi
/usr/bin/dpkg -i $TMPDIR/omsbundle/110/omi*.deb

#Install scx
/usr/bin/dpkg -i $TMPDIR/omsbundle/110/scx*.deb
#$TMPDIR/omsbundle/bundles/scx-1.6.*-*.universal.x64.sh --install

#Install omsagent

/usr/bin/dpkg -i $TMPDIR/omsbundle/110/omsagent*.deb
#/usr/bin/dpkg -i $TMPDIR/omsbundle/100/omsconfig*.deb

#install oneagent - Official bits (10/18)
wget https://github.com/microsoft/Docker-Provider/releases/download/10182020-oneagent/azure-mdsd_1.5.126-build.master.99_x86_64.deb
/usr/bin/dpkg -i $TMPDIR/azure-mdsd*.deb
cp -f $TMPDIR/mdsd.xml /etc/mdsd.d
cp -f $TMPDIR/envmdsd /etc/mdsd.d

#Assign permissions to omsagent user to access docker.sock
sudo apt-get install acl

#download inotify tools for watching configmap changes
sudo apt-get update
sudo apt-get install inotify-tools -y

#used to parse response of kubelet apis
#ref: https://packages.ubuntu.com/search?keywords=jq
sudo apt-get install jq=1.5+dfsg-2 -y

#used to setcaps for ruby process to read /proc/env
echo "installing libcap2-bin"
sudo apt-get install libcap2-bin -y
#/$TMPDIR/omsbundle/oss-kits/docker-cimprov-1.0.0-*.x86_64.sh --install
#Use downloaded docker-provider instead of the bundled one

#download and install telegraf
#wget https://dl.influxdata.com/telegraf/releases/telegraf_1.10.1-1_amd64.deb
#sudo dpkg -i telegraf_1.10.1-1_amd64.deb

#service telegraf stop

#wget https://github.com/microsoft/Docker-Provider/releases/download/5.0.0.0/telegraf

#1.18 pre-release
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

rm -rf $TMPDIR/omsbundle
rm -f $TMPDIR/omsagent*.sh
rm -f $TMPDIR/docker-cimprov*.sh
rm -f $TMPDIR/azure-mdsd*.deb
rm -f $TMPDIR/mdsd.xml
rm -f $TMPDIR/envmdsd

# Remove settings for cron.daily that conflict with the node's cron.daily. Since both are trying to rotate the same files
# in /var/log at the same time, the rotation doesn't happen correctly and then the *.1 file is forever logged to.
rm /etc/logrotate.d/alternatives /etc/logrotate.d/apt /etc/logrotate.d/azure-mdsd /etc/logrotate.d/rsyslog
