ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION}

ARG ALPINE_VERSION=3.20
ARG ROS_DISTRO="noetic"

RUN echo "https://alpine-ros.seqsense.org/v${ALPINE_VERSION}/backports" >> /etc/apk/repositories \
  && echo "https://alpine-ros.seqsense.org/v${ALPINE_VERSION}/ros/noetic" >> /etc/apk/repositories
COPY <<EOF /etc/apk/keys/builder@alpine-ros-experimental.rsa.pub
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnSO+a+rIaTorOowj3c8e
5St89puiGJ54QmOW9faDsTcIWhycl4bM5lftp8IdcpKadcnaihwLtMLeaHNJvMIP
XrgEEoaPzEuvLf6kF4IN8HJoFGDhmuW4lTuJNfsOIDWtLBH0EN+3lPuCPmNkULeo
iS3Sdjz10eB26TYiM9pbMQnm7zPnDSYSLm9aCy+gumcoyCt1K1OY3A9E3EayYdk1
9nk9IQKA3vgdPGCEh+kjAjnmVxwV72rDdEwie0RkIyJ/al3onRLAfN4+FGkX2CFb
a17OJ4wWWaPvOq8PshcTZ2P3Me8kTCWr/fczjzq+8hB0MNEqfuENoSyZhmCypEuy
ewIDAQAB
-----END PUBLIC KEY-----
EOF

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV ROS_DISTRO=${ROS_DISTRO}
ENV ROS_PYTHON_VERSION=3

RUN apk add --no-cache \
    bash \
    curl \
    findutils \
    git \
    github-cli \
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

ENV DRYRUN=true

COPY scripts /scripts

VOLUME /rosdistro1
WORKDIR /rosdistro1
RUN git config --global --add safe.directory /rosdistro1

ENTRYPOINT ["/scripts/update_aports.sh"]
