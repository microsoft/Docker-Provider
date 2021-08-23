set -e

OLD_PATH=$(pwd)
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $SCRIPTPATH/../../source/plugins/go/src
echo "# Runnign go generate"
go generate

echo "# Running go test ."
go test .

cd $OLD_PATH
