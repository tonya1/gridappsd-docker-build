#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 -b Build the docker image"
  /bin/echo "           -p Push image to dockerhub"
  exit 2
}

IMAGE="gridappsd/gridappsd_base:dev"

trigger_gridappsd_build() {
body='{
  "request": {
  "branch":"master"
}}'

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token $BUILD_AUTH_TOKEN" \
   -d "$body" \
   https://api.travis-ci.org/repo/GRIDAPPSD%2FGOSS-GridAPPS-D/requests
}
# parse options
while getopts bp option ; do
  case $option in
    b) # Pass gridappsd tag to docker-compose
      docker build --no-cache --rm=true -f Dockerfile.gridappsd_base -t $IMAGE .
      ;;
    p) # Pass gridappsd tag to docker-compose
      docker push $IMAGE
      trigger_gridappsd_build
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`
