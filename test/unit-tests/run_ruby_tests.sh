#TODO: add support for running a single specific test

OLD_PATH=$(pwd)
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SCRIPTPATH/../../source/plugins/ruby
ruby test_driver.rb

cd $OLD_PATH
