#!/bin/bash

VERSION="2019.06.0"

user=""
TOKEN=""

OWNER="gridappsd"
gh="https://github.com/gridappsd/"

repos="GOSS-GridAPPS-D gridappsd-viz gridappsd-sample-app proven-docker Powergrid-Models gridappsd-docker-build gridappsd-data gridappsd-docker gridappsd-python"


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
  fi
  cd release_$VERSION
  if [ ! -d $myrepo ]; then
    git clone ${gh}$myrepo -b develop
    cd $myrepo
    git checkout -b releases/$VERSION
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
  API_JSON=$(printf '{"title": "Release of version %s", "body": "Release of version %s", "head":"%s:releases/%s", "base": "master"}' $VERSION $VERSION $OWNER $VERSION )
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

for repo in $repos; do
  #list open pull requests
  list_pr $repo

  # Create the release/$VERSION from develop
#  create_release_branch $repo

  # Test the releases/$VERSION 


  # From the releases/$VERSION branch, create the pull request to master
#  create_pull_request $repo

  # Assign and close the pull requests

  # After the pull request's are approved then create the Tagged Releases
#  create_release $repo
done






