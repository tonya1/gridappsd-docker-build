#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 -b Build the docker image"
  /bin/echo "           -p Push image to dockerhub"
  exit 2
}

TAG="$TRAVIS_BRANCH"

ORG=`echo $DOCKER_PROJECT | tr '[:upper:]' '[:lower:]'`
ORG="${ORG:-gridappsd}"
ORG="${ORG:+${ORG}/}"
IMAGE="${ORG}gridappsd_base"
TIMESTAMP=`date +'%y%m%d%H'`
GITHASH=`git log -1 --pretty=format:"%h"`


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
      BUILD_VERSION="${TIMESTAMP}_${GITHASH}${TRAVIS_BRANCH:+:$TRAVIS_BRANCH}"
      echo "BUILD_VERSION $BUILD_VERSION"
      echo "DOCKER TAG ${IMAGE}:${TIMESTAMP}_${GITHASH}"
      docker build --no-cache --rm=true --build-arg TIMESTAMP="${BUILD_VERSION}" -f Dockerfile.gridappsd_base -t ${IMAGE}:${TIMESTAMP}_${GITHASH} .
      ;;
    p) # Pass gridappsd tag to docker-compose
      docker images
      if [ -n "$TAG" -a -n "$ORG" ]; then
        # Get the built container name, for builds that cross the hour boundary
        CONTAINER=`docker images --format "{{.Repository}}:{{.Tag}}" ${IMAGE}`
        echo "$CONTAINER"
        echo "docker push ${CONTAINER}"
        docker push ${CONTAINER}
        docker tag ${CONTAINER} ${IMAGE}:$TAG
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
