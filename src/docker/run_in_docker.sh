#!/usr/bin/env bash
# Build the tooling image (cached) and run it once.
export PS4='[\D{%H:%M:%S}] ${BASH_SOURCE##*/}:${LINENO}> '
set -xeuo pipefail

IMAGE=loop-lab-disktools
docker build -t "$IMAGE" -f src/docker/Dockerfile src/docker
docker run --rm --privileged \
	-v /dev:/dev \
	-v "$PWD":/work -w /work \
  "$IMAGE"
