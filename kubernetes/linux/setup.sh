#!/bin/bash
set -e

TMPDIR="/opt"
cd $TMPDIR

sudo tdnf install ca-certificates-microsoft -y
sudo update-ca-trust

echo "Installing Fluentd..."

# Install ruby and fluentd
tdnf install -y gcc patch bzip2 openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel
wget https://github.com/rbenv/ruby-build/archive/refs/tags/v20250409.tar.gz -O ruby-build.tar.gz
tar -xzf ruby-build.tar.gz
PREFIX=/usr/local ./ruby-build-*/install.sh
ruby-build 3.3.8 /usr

# clean up the ruby-build files
rm ruby-build.tar.gz
rm -rf ruby-build-*

fluentd_version="1.18.0"
gem install fluentd -v $fluentd_version --no-document

# remove the test directory from fluentd
rm -rf /usr/lib/ruby/gems/3.1.0/gems/fluentd-$fluentd_version/test/

echo "$(fluentd --version)" >> packages_version.txt
fluentd --setup ./fluent

# Create directories for fluentd
mkdir -p /etc/fluentd
mkdir -p /var/log/fluentd

# Create a basic fluentd configuration file
cat > /etc/fluentd/fluent25.conf << 'EOL'
<system>
  workers 1
</system>

<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match **>
  @type stdout
</match>
EOL

echo "Fluentd installation and setup completed."
