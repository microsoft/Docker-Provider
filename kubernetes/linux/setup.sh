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

# arm64 build breaks intermittently when installing ruby from global packages, so installing it from mariner packages
# the mariner package version is behind the global packages so we are using different versions for arm64 and x86_64
if [ "$ARCH" == "arm64" ]; then
    sudo tdnf install ruby-3.3.5-7.azl3.aarch64 -y
    sudo tdnf install zlib-devel openssl-devel -y
else
    tdnf install -y gcc patch bzip2 openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel
    wget https://github.com/rbenv/ruby-build/archive/refs/tags/v20251023.tar.gz -O ruby-build.tar.gz
    tar -xzf ruby-build.tar.gz
    PREFIX=/usr/local ./ruby-build-*/install.sh
    ruby-build 3.3.10 /usr -v

    rm ruby-build.tar.gz
fi

# remove unused default gem openssl, find as they have some known vulns
rm /usr/lib/ruby/gems/3.3.0/specifications/default/openssl-3.2.0.gemspec
rm -rf /usr/lib/ruby/gems/3.3.0/gems/openssl-3.2.0
rm /usr/lib/ruby/gems/3.3.0/specifications/default/find-0.2.0.gemspec
rm -rf /usr/lib/ruby/gems/3.3.0/gems/find-0.2.0
rm /usr/lib/ruby/gems/3.3.0/specifications/default/rdoc-6.6.3.1.gemspec
rm -rf /usr/lib/ruby/gems/3.3.0/gems/rdoc-6.6.3.1

# remove net-imap gem as it has a known CVE (CVE-2025-43857) and is not used by the agent
gem uninstall net-imap --force

# remove rexml gem as it has a known CVE (CVE-2025-58767) and is not used by the agent
gem uninstall rexml --force

sudo tdnf install -y azure-mdsd-1.42.0
cp -f $TMPDIR/mdsd.xml /etc/mdsd.d
cp -f $TMPDIR/envmdsd /etc/mdsd.d
rm /usr/sbin/telegraf

mdsd_version=$(sudo tdnf list installed | grep mdsd | awk '{print $2}')
echo "Azure mdsd: $mdsd_version" >> packages_version.txt

# log rotate conf for mdsd and can be extended for other log files as well
cp -f $TMPDIR/logrotate.conf /etc/logrotate.d/ci-agent

#download inotify tools for watching configmap changes
sudo tdnf check-update -y
sudo tdnf install inotify-tools -y

#used to parse response of kubelet apis
#ref: https://packages.ubuntu.com/search?keywords=jq
sudo tdnf install jq-1.7.1-1.azl3 -y

#used to setcaps for ruby process to read /proc/env
sudo tdnf install libcap -y

sudo tdnf install telegraf-agent-1.39.3 -y
telegraf_version=$(sudo tdnf list installed | grep telegraf | awk '{print $2}')
echo "telegraf $telegraf_version" >> packages_version.txt
mv /usr/bin/telegraf-agent /opt/telegraf

# Use wildcard version so that it doesnt require to touch this file
/$TMPDIR/docker-cimprov-*.*.*-*.*.sh --install
docker_cimprov_version=$(sudo tdnf list installed | grep docker-cimprov | awk '{print $2}')
echo "DOCKER_CIMPROV_VERSION=$docker_cimprov_version" >> packages_version.txt

#install fluent-bit
sudo tdnf install azcu-fluent-bit-5.0.4 -y
echo "$(fluent-bit --version)" >> packages_version.txt

# Retry wrapper for gem install commands.
# Native extension builds under QEMU emulation for arm64 can hit sporadic
# segfaults in GCC/make, so we retry transient failures automatically.
# Retries are cheap: gems that already installed successfully are skipped, so each
# attempt resumes where the previous one crashed rather than starting over.
gem_install_with_retry() {
    local max_retries=5
    local attempt=1
    while [ $attempt -le $max_retries ]; do
        echo "gem install attempt $attempt/$max_retries: gem install $*"
        if gem install "$@"; then
            return 0
        fi
        echo "WARNING: gem install failed (attempt $attempt/$max_retries): gem install $*"
        attempt=$((attempt + 1))
        sleep $((attempt * 5))
    done
    echo "ERROR: gem install failed after $max_retries attempts: gem install $*"
    exit 1
}

# install fluentd
# 1.19.3 is the first release that fixes CVE-2026-44024 (critical RCE), CVE-2026-44025,
# CVE-2026-44160 and CVE-2026-44161. Requires Ruby >= 3.2 (satisfied by the ruby 3.3.x installed above).
fluentd_version="1.19.3"
gem_install_with_retry fluentd -v $fluentd_version --no-document

# remove the test directory from fluentd
rm -rf /usr/lib/ruby/gems/3.3.0/gems/fluentd-$fluentd_version/test/

echo "$(fluentd --version)" >> packages_version.txt
fluentd --setup ./fluent

gem_install_with_retry gyoku iso8601 bigdecimal --no-doc
gem_install_with_retry tomlrb -v "2.0.1" --no-document
gem_install_with_retry ipaddress --no-document
gem_install_with_retry jwt -v "3.2.0" --no-document
gem_install_with_retry racc --no-document

# Reinstall zlib gem to fix CVE-2026-27820
gem_install_with_retry zlib -v "3.2.3" --no-document 
# uninstall old zlib gem
rm /usr/lib/ruby/gems/3.3.0/specifications/default/zlib-3.1.1.gemspec
rm -rf /usr/lib/ruby/gems/3.3.0/gems/zlib-3.1.1

# Reinstall erb gem to fix CVE-2026-41316.
# NOTE: when ruby is upgraded, check the default bundled erb version
# (`ruby -rerb -e 'p ERB::VERSION'`). If it's 4.0.3.1 or higher, remove
# this block and let the ruby package provide erb directly.
gem_install_with_retry erb -v "4.0.3.1" --no-document
# uninstall old erb default gem
rm -f /usr/lib/ruby/gems/3.3.0/specifications/default/erb-4.0.3.gemspec
rm -rf /usr/lib/ruby/gems/3.3.0/gems/erb-4.0.3

rm -f $TMPDIR/docker-cimprov*.sh
rm -f $TMPDIR/mdsd.xml
rm -f $TMPDIR/envmdsd

# Remove settings for cron.daily that conflict with the node's cron.daily. Since both are trying to rotate the same files
# in /var/log at the same time, the rotation doesn't happen correctly and then the *.1 file is forever logged to.
rm -f /etc/logrotate.d/azure-mdsd
