#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 -b Build the docker image"
  /bin/echo "           -p Push image to dockerhub"
  exit 2
}

TAG="$TRAVIS_BRANCH"

ORG=`echo $DOCKER_PROJECT | tr '[:upper:]' '[:lower:]'`
ORG="${ORG:+${ORG}/}"
IMAGE="${ORG}gridappsd_base"
TIMESTAMP=`date +'%y%m%d%H'`
GITHASH=`git log -1 --pretty=format:"%h"`

BUILD_VERSION="${TIMESTAMP}_${GITHASH}${TRAVIS_BRANCH:+:$TRAVIS_BRANCH}"
echo "BUILD_VERSION $BUILD_VERSION"

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
      docker build --no-cache --rm=true --build-arg TIMESTAMP="${BUILD_VERSION}" -f Dockerfile.gridappsd_base -t ${IMAGE}:$TIMESTAMP .
      ;;
    p) # Pass gridappsd tag to docker-compose
      if [ -n "$TAG" -a -n "$ORG" ]; then
        echo "docker push ${IMAGE}:${TIMESTAMP}_${GITHASH}"
        docker push ${IMAGE}:${TIMESTAMP}_${GITHASH}
        docker tag ${IMAGE}:${TIMESTAMP}_${GITHASH} ${IMAGE}:$TAG
        echo "docker push ${IMAGE}:$TAG"
        docker push ${IMAGE}:$TAG
        trigger_gridappsd_build
      fi
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`
