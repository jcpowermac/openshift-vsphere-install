#!/bin/bash

IMAGE="openshift-vsphere-install:latest"

sudo podman build -t ${IMAGE} -f Dockerfile .

sudo podman run -it --rm -v ${PWD}:/srv/origin:Z ${IMAGE}
