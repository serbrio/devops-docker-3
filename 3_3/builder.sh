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

github_repo="$1"
docker_image="$2"

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
    *) echo "Error: wrong marker in $FUNCNAME"
       return 1 ;;
  esac

  echo "$repo_name" | grep -qE "$exp"
}

# Check github and docker repository names are correct.
repo_name_correct "$github_repo" "github" || fail "repo name '$github_repo' seems incorrect" 
repo_name_correct "$docker_image" "dockerhub" || fail "repo name '$docker_image' seems incorrect"

repo_dir="$( echo $github_repo | cut -d/ -f2)"
repo_url="https://github.com/$github_repo.git"

# Clone repository
output="$(git clone -q $repo_url 2>&1)"
[ "$?" -eq 0 ] || fail "'git clone $repo_url': $output"

# Build 
output="$(docker build -t $docker_image "$repo_dir" 2>&1)"
[ "$?" -eq 0 ] || fail "'docker build $repo_dir': $output"

# Publish to dockerhub
output="$(docker push $docker_image 2>&1)"
[ "$?" -eq 0 ] || fail "'docker push $docker_image': $output"
