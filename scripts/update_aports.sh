#!/bin/bash

set -e

alpine_version=$(cat /etc/alpine-release | cut -d. -f1-2)

ros_distro=${ROS_DISTRO:-noetic}
short_hash=$(git log --format=%h -n1 ${ros_distro})
upstream_commit_msg=$(git log --format=%B ${short_hash}^..${short_hash} \
  | sed ':a; N; $!b a; s/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g;')
aports_slug='seqsense/aports-ros-experimental'
aports_fork_slug='alpine-ros-bot/aports-ros-experimental'

title=${ros_distro}-${alpine_version}

generate_opts="--split-dev"
case "${ALPINE_VERSION}" in
  3.20) ;;
  *)
    generate_opts="${generate_opts} --cmake-var CMAKE_POLICY_VERSION_MINIMUM=3.10"
    ;;
esac

branch="rosdistro1-${title}-${short_hash}"

if git ls-remote --exit-code \
  https://github.com/${aports_fork_slug}.git \
  refs/heads/${branch}; then
  echo "The change is already pushed"
  exit 0
fi

# Setup local rosdistro

rosdistro_build_cache index.yaml ${ros_distro}
export ROSDISTRO_INDEX_URL="file://$(pwd)/index.yaml"
rosdep update

# Sync aports fork
if ! ${DRYRUN:-true}; then
  gh api \
    -X POST repos/${aports_fork_slug}/merge-upstream \
    -f branch=master
else
  echo "Sync aports fork"
fi

# Clone and update aports

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

git clone https://github.com/${aports_fork_slug}.git ${tmpdir}
cd ${tmpdir}
git remote add upstream https://github.com/${aports_slug}.git
git pull upstream master

mkdir -p ${tmpdir}/v${alpine_version}/ros/${ros_distro}
cd ${tmpdir}/v${alpine_version}/ros/${ros_distro}

git config user.name "alpine-ros-bot"
git config user.email "214657941+alpine-ros-bot@users.noreply.github.com"

generate-rospkg-apkbuild-multi --all ${ros_distro} ${generate_opts}

git checkout -b ${branch}
git add .

if git diff --cached --exit-code; then
  echo "No update found"
  exit 0
fi

git commit -m "Update ${title} aports (rosdistro1 ${short_hash})"

# Push and open PR

pr_request_body=$(
  cat <<EOS
{
  "title": "Update ${title} aports (rosdistro1 ${short_hash})",
  "body": "Upstream commit messages\\n\`\`\`\\n${upstream_commit_msg}\\n\`\`\`",
  "head": "$(dirname ${aports_fork_slug}):${branch}",
  "base": "master"
}
EOS
)
echo ${pr_request_body}

if ! ${DRYRUN:-true}; then
  if ! git push origin ${branch}; then
    if git ls-remote --exit-code \
      https://github.com/${aports_fork_slug}.git \
      refs/heads/${branch}; then
      echo "The change is already pushed"
      exit 0
    fi
  fi

  echo "${pr_request_body}" | gh api \
    -X POST repos/${aports_slug}/pulls \
    --input - \
    || (
      echo "Failed to open a pull request. GitHub personal access token for api.github.com is not set up."
      echo "Please manually open the pull request."
      echo
      exit 1
    )
fi
