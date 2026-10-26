
# syntax=docker/dockerfile:1

# Build the SDK in a separate stage. This stage is not the final
# sandbox image and does not replace the agent's workload.
FROM dhi.io/debian-base:trixie-dev AS build

ARG FLUTTER_VERSION=3.47.8

USER root

RUN apt-get update 

RUN apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	xz-utils \
	libglu1-mesa \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
	"https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
	-o /tmp/flutter.tar.xz \
	&& mkdir -p /opt \
	&& tar -xJf /tmp/flutter.tar.xz -C /opt \
	&& rm /tmp/flutter.tar.xz

# A v3 mixin must be an overlay. Do not inherit the build stage's
# entrypoint, user, environment, or other image configuration.
FROM scratch

COPY --from=build --chown=1000:1000 /opt/flutter /opt/flutter

# These are additive mixin settings. Docker Sandbox merges PATH
# with the workload's PATH during composition.
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=/opt/flutter/bin
