#!/bin/bash
#
#  This scripts builds docker provider shell bundle, docker image and pushes to specified image to docker hub or azure acr registry

set -e
set -o pipefail

image=""
imageTag=""
dockerUser=""
usage()
{
    local basename=`basename $0`
    echo
    echo "Build and publish docker image:"
    echo "$basename --image <name of docker image> --ubuntu <mcr url of ubuntu image> --golang <mcr url of golang image>"
    echo "$basename --image <name of docker image> --ubuntu <mcr url of ubuntu image> --golang <mcr url of golang image> --multiarch"
}

parse_args()
{

 if [ $# -le 1 ]
  then
    usage
    exit 1
 fi

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--image")  set -- "$@" "-i" ;;
    "--multiarch")  set -- "$@" "-m" ;;
    "--ubuntu")  set -- "$@" "-u" ;;
    "--golang")  set -- "$@" "-g" ;;
    "--"*)   usage ;;
    *)        set -- "$@" "$arg"
  esac
done

local OPTIND opt

while getopts 'hi:u:g:m' opt; do
    case "$opt" in
      h)
      usage
        ;;

      i)
        image="$OPTARG"
        echo "image is $OPTARG"
        ;;

      m)
        multi=1
        echo "using multiarch dockerfile"
        ;;
      u)
        ci_base_image=$OPTARG
        ;;
      g)
        golang_base_image=$OPTARG
        ;;
      ?)
        usage
        exit 1
        ;;
    esac
  done
  shift "$(($OPTIND -1))"


 if [ -z "$image" ]; then
    echo "-e invalid image. please try with valid values"
    exit 1
 fi

 if [ -z "$ci_base_image" ]; then
    echo "-e invalid ubuntu image url. please try with valid values from internal wiki. do not use 3P entries"
    exit 1
 fi

 if [ -z "$golang_base_image" ]; then
    echo "-e invalid golang image url. please try with valid values from internal wiki. do not use 3P entries"
    exit 1
 fi

 # extract image tag
 imageTag=$(echo ${image} | sed "s/.*://")

 if [ -z "$imageTag" ]; then
    echo "-e invalid image. please try with valid values"
    exit 1
 fi

if [ $image = $imageTag ]; then
  echo "-e invalid image format. please try with valid values"
  exit 1
fi

#  if [ -z "$dockerUser" ]; then
#     echo "-e missing docker username. please try with valid username for the docker login"
#     exit 1
#  fi

}

# parse and validate args
parse_args $@

currentDir=$PWD

## TODO figureout better way than this
linuxDir=$(dirname $PWD)
kubernetsDir=$(dirname $linuxDir)
baseDir=$(dirname $kubernetsDir)
buildDir=$baseDir/build/linux
dockerFileDir=$baseDir/kubernetes/linux

echo "source code base directory: $baseDir"
echo "build directory for docker provider: $buildDir"
echo "docker file directory: $dockerFileDir"

echo "build docker image: $image and image tage is $imageTag"

if [ -n "$multi" ] && [ "$multi" -eq "1" ]; then
  echo "building multiarch"
  cd $baseDir
  docker buildx build --platform linux/arm64/v8,linux/amd64 -t $image --build-arg IMAGE_TAG=$imageTag --build-arg CI_BASE_IMAGE="$ci_base_image" --build-arg GOLANG_BASE_IMAGE="$golang_base_image" -f $linuxDir/Dockerfile.multiarch --push .
else
  echo "building amd64"
  cd $baseDir
  docker buildx build --platform linux/amd64 -t $image --build-arg IMAGE_TAG=$imageTag --build-arg CI_BASE_IMAGE="$ci_base_image" --build-arg GOLANG_BASE_IMAGE="$golang_base_image" -f $linuxDir/Dockerfile.multiarch --push .
fi

echo "build and push docker image completed"

cd $currentDir