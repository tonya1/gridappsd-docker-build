#!/bin/bash

VERSION="2019.12.0"

user="YOURGITHUBUSERNAME"
TOKEN="YOURGITHUBTOKEN"

OWNER="GRIDAPPSD"
gh="https://github.com/gridappsd/"

# 2019.12.0 
repos="GOSS-GridAPPS-D gridappsd-viz gridappsd-sample-app proven-docker gridappsd-docker-build gridappsd-data gridappsd-docker gridappsd-python Powergrid-Models"

VERSIONU=$(echo $VERSION | sed 's/\./-/'g)

list_pr() {
  myrepo=$1
  #list open pull requests
  echo "$myrepo"
  curl -s https://api.github.com/repos/${OWNER}/$myrepo/pulls  | jq '.[] | {head: .head.label, base: .base.label, url: .url, updated: .updated_at}'
  echo " "
} 

create_release_branch() {
  myrepo=$1
  # Create the release/$VERSION from develop
  if [ ! -d release_$VERSION ]; then
     mkdir release_$VERSION
  else
    echo "Directory already exists release_$VERSION"
    #exit 1
  fi
  cd release_$VERSION
  if [ ! -d $myrepo ]; then
    git clone ${gh}$myrepo -b develop
    cd $myrepo
    git checkout -b releases/$VERSION

    if [ "$myrepo" == "gridappsd-docker" ]; then
      sed -i'.bak' "s/^GRIDAPPSD_TAG=':develop'/GRIDAPPSD_TAG=':v$VERSION'/" run.sh
      rm run.sh.bak
      git add run.sh
      git commit -m "Updated default version for release: $VERSION"
    fi

    #echo "Pushing new release version"
    git push -u origin releases/$VERSION
    cd ..
  else
    echo "Repo $myrepo exists, skipping"
  fi
  cd ..
}

create_pull_request() {
  myrepo=$1
  # From the releases/$VERSION branch, create the pull request to master
  #"title":"testPR","base":"master", "head":"user-repo:master"
  API_JSON=$(printf '{"title": "Release of version %s", "body": "Release of version %s", "head": "%s:releases/%s", "base": "master"}' $VERSION $VERSION $OWNER $VERSION )
  echo "curl -u ${user}:${TOKEN} --data \"$API_JSON\" https://api.github.com/repos/${OWNER}/$myrepo/pulls"
  curl -u ${user}:${TOKEN} --data "$API_JSON" https://api.github.com/repos/${OWNER}/$myrepo/pulls
}

create_release() {
  myrepo=$1
  if [ `list_pr $myrepo | grep -c release` -gt 0 ]; then
    echo "Exiting, open release pull requests $myrepo"
    exit 1
  else
    API_JSON=$(printf '{"tag_name": "v%s", "target_commitish": "master", "name": "%s release", "body": "See https://gridappsd.readthedocs.io/en/master/overview/index.html#version-%s for release notes.","draft": false,"prerelease": false}' $VERSION $VERSION $VERSIONU)
    echo "curl -u ${user}:${TOKEN} --data \"$API_JSON\" https://api.github.com/repos/${OWNER}/$myrepo/releases"
    curl -u ${user}:${TOKEN} --data "$API_JSON" https://api.github.com/repos/${OWNER}/$myrepo/releases
  fi
}

release_status=".${VERSION}.status"

#for repo in $repos; do
  #list open pull requests
#  list_pr $repo | grep -c "releases/$VERSION"
#done

#exit

docker pull gridappsd/blazegraph:develop

if [ ! -f $release_status ]; then
  status="Start"
else
  status=$(tail -1 $release_status)
fi

echo " "
echo "test: $status"
echo " "

case "$status" in
  "Start")
   
    echo "Step 1: Create the release/$VERSION from develop"
    for repo in $repos; do
      create_release_branch $repo
    done
    echo " "
    echo "Creating gridappsd/blazegraph:release_$VERSION"
    echo "docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:releases_$VERSION"
    docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:releases_$VERSION
    echo "docker push gridappsd/blazegraph:releases_$VERSION"
    docker push gridappsd/blazegraph:releases_$VERSION
    echo "Step1 Complete" > $release_status
    echo " "
    echo " "
    echo "Verify containers were built and "
    echo "test the:releases_$VERSION version before running the next step"
    echo "./run.sh -t releases_$VERSION"
    ;;
  "Step1 Complete")
    echo "Step 2: From the releases/$VERSION branch, create the pull requests to master"
    for repo in $repos; do
      create_pull_request $repo
    done
    echo " "
    echo "Creating gridappsd/blazegraph:master"
    echo "docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:master"
    docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:master
    echo "docker push gridappsd/blazegraph:master"
    docker push gridappsd/blazegraph:master
    echo "Step2 Complete" > $release_status
    echo " "
    echo " "
    echo "Assign and close the pull requests before running the next step"
    ;; 
  "Step2 Complete")
    echo "Step 3: After the pull request's are approved then create the Tagged Releases"
    for repo in $repos; do
      if [ $(list_pr $repo | grep -c "releases/$VERSION") -gt 0 ]; then
        echo "Error: there are open pull requests for releass/$VERSION"
        exit 1
      fi
    done
    for repo in $repos; do
      create_release $repo
    done
    echo " "
    echo "Creating gridappsd/blazegraph:v$VERSION"
    docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:v$VERSION
    echo "docker tag gridappsd/blazegraph:develop gridappsd/blazegraph:v$VERSION"
    docker push gridappsd/blazegraph:v$VERSION
    echo "docker push gridappsd/blazegraph:v$VERSION"
    echo "Step3 Complete" > $release_status
    echo " "
    echo " "
    echo "Release complete"
    echo "Verify containers were built and "
    echo "test the:v$VERSION version"
    echo "./run.sh -t v$VERSION"
    ;;
  *)
      echo "Something didn't work correctly"
      exit 1
esac






