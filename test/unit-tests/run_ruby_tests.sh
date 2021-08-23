# this script will exit with an error if any commands exit with an error
set -e

# NOTE: to run a specific test (instead of all) use the following arguments: --name test_name
# ex:  run_ruby_tests.sh --name test_basic_single_node

OLD_PATH=$(pwd)
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# cd $SCRIPTPATH/../../source/plugins/ruby
echo "# Running ruby $SCRIPTPATH/test_driver.rb $1 $2"
ruby $SCRIPTPATH/test_driver.rb $1 $2

cd $OLD_PATH
