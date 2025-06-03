ARG ALPINE_VERSION=3.20
FROM ghcr.io/alpine-ros/alpine-ros:noetic-${ALPINE_VERSION}-bare

ARG ALPINE_VERSION=3.20
ENV ROS_PYTHON_VERSION=3

RUN apk add --no-cache \
    bash \
    curl \
    findutils \
    git \
    py3-pip \
    py3-rosdep \
    py3-rosinstall-generator \
    py3-yaml \
    python3

RUN <<EOF
case ${ALPINE_VERSION} in
  3.17)
    pip3 install \
      git+https://github.com/alpine-ros/ros-abuild-docker.git
    ;;
  *)
    pip3 install --break-system-packages \
      git+https://github.com/alpine-ros/ros-abuild-docker.git
    ;;
esac
EOF

RUN rosdep init \
  && sed -i -e 's|ros/rosdistro/master|alpine-ros/rosdistro/alpine-custom-apk|' \
    /etc/ros/rosdep/sources.list.d/20-default.list

ENV HOME="/root"

ARG ROS_DISTRO="noetic"
ENV ROS_DISTRO=${ROS_DISTRO}
ENV DRYRUN=true

COPY scripts /scripts

VOLUME /rosdistro1
WORKDIR /rosdistro1
RUN git config --global --add safe.directory /rosdistro1

ENTRYPOINT ["/scripts/update_aports.sh"]
