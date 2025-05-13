#!/bin/bash

set -e

alpine_version=$(cat /etc/alpine-release | cut -d. -f1-2)

ros_distro=${ROS_DISTRO:-noetic}
short_hash=$(git log --format=%h -n1 ${ros_distro})
upstream_commit_msg=$(git log --format=%B ${short_hash}^..${short_hash} \
  | sed ':a; N; $!b a; s/\\/\\\\/g; s/\t/\\t/g; s/"/\\"/g; s/\n/\\n/g; s/\r/\\r/g;')
aports_slug='seqsense/aports-ros-experimental'

distro_dir=${ros_distro}
case ${ros_distro} in
  "noetic")
    distro_dir=${ros_distro}.v${alpine_version};;
  *)
    echo "Unsupported ROS_DISTRO"
    ;;
esac

generate_opts=
case "${ALPINE_VERSION}" in
  3.20)
    generate_opts="${generate_opts} --split-dev"
    ;;
  *)
    ;;
esac

branch="rosdistro1-${distro_dir}-${short_hash}"

if git ls-remote --exit-code \
  https://github.com/${aports_slug}.git \
  refs/heads/${branch}
then
  echo "The change is already pushed"
  exit 0
fi

# Setup local rosdistro

rosdistro_build_cache index.yaml ${ros_distro}
export ROSDISTRO_INDEX_URL="file://$(pwd)/index.yaml"
rosdep update


# Clone and update aports

tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

git clone https://github.com/${aports_slug}.git ${tmpdir}
mkdir -p ${tmpdir}/ros/${distro_dir}
cd ${tmpdir}/ros/${distro_dir}

git config user.name "at-wat"
git config user.email "8390204+at-wat@users.noreply.github.com"


generate-rospkg-apkbuild-multi --all ${ros_distro} ${generate_opts}


git checkout -b ${branch}
git add .

if git diff --cached --exit-code
then
  echo "No update found"
  exit 0
fi

git commit -m "Update ${distro_dir} aports (rosdistro ${short_hash})"


# Push and open PR

pr_request_body=$(cat << EOS
{
  "title": "Update ${distro_dir} aports (rosdistro ${short_hash})",
  "body": "Upstream commit messages\\n\`\`\`\\n${upstream_commit_msg}\\n\`\`\`",
  "head": "${branch}",
  "base": "master"
}
EOS
)
echo ${pr_request_body}

if ! ${DRYRUN:-true}
then
  if ! git push origin ${branch}
  then
    if git ls-remote --exit-code \
      https://github.com/${aports_slug}.git \
      refs/heads/${branch}
    then
      echo "The change is already pushed"
      exit 0
    fi
  fi

  curl https://api.github.com/repos/${aports_slug}/pulls -d "${pr_request_body}" -XPOST -n \
    || (echo "Failed to open a pull request. GitHub personal access token for api.github.com is not set up."; \
        echo "Please manually open the pull request."; echo; exit 1)
fi
