#!/bin/sh

# Check provided two arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <github-repo> <docker-image>"
  exit 1
fi

fail() {
  echo "FAIL: $1"
  exit 1
}

cleanup() {
  rm -rf "$TEMP_DIR"
}  

TEMP_DIR="$(mktemp -d)"
GITHUB_REPO="$1"
DOCKER_IMAGE="$2"

# Registers the cleanup function to be called on script exit
trap cleanup EXIT

# Repo name must consist of two parts divided by a "/" slash:
# <user_name>/<repo_name>.
# As github and dockerhub follow slightly different rules in user and 
# repository naming, different regular expressions are used to check repo names.
# Second argument informs which to use: "github" or "dockerhub".
# Some reference concerning docker regexp:
# https://docs.docker.com/reference/api/registry/latest/
repo_name_correct() {
  local repo_name="$1" marker="$2"
  local github_exp
  local dockerhub_exp
  github_exp="^[a-z0-9]+([-][a-z0-9]+)*/[a-z0-9_-]+[a-z0-9._-]*$"
  dockerhub_exp="^[a-z0-9]+([._-][a-z0-9]+)*/[a-z0-9]+([._-][a-z0-9]+)*$"
  
  case "$marker" in
    "github") exp="$github_exp" ;;
    "dockerhub") exp="$dockerhub_exp" ;;
    *) return 1 ;;
  esac

  echo "$repo_name" | grep -qE "$exp"
}

# Check github and docker repository names are correct.
repo_name_correct "$GITHUB_REPO" "github" || fail "repo name '$GITHUB_REPO' seems incorrect" 
repo_name_correct "$DOCKER_IMAGE" "dockerhub" || fail "repo name '$DOCKER_IMAGE' seems incorrect"

repo_url="https://github.com/$GITHUB_REPO.git"

# Clone repository
output="$(git clone -q $repo_url $TEMP_DIR 2>&1)"
[ "$?" -eq 0 ] || fail "'git clone $repo_url': $output"

# Docker login
output="$(docker login -u $DOCKER_USER -p $DOCKER_PWD 2>&1)"
[ "$?" -eq 0 ] || fail "'docker login -u $DOCKER_USER -p $DOCKER_PWD': $output"

# Build 
output="$(docker build -t $DOCKER_IMAGE $TEMP_DIR 2>&1)"
[ "$?" -eq 0 ] || fail "'docker build -t $DOCKER_IMAGE $TEMP_DIR': $output"

# Publish to dockerhub
output="$(docker push $DOCKER_IMAGE 2>&1)"
[ "$?" -eq 0 ] || fail "'docker push $DOCKER_IMAGE': $output"
