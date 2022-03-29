SHELL = bash
# .ONESHELL:
# .SHELLFLAGS = -e
# See https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
.PHONY: default all build circleci-local-build check-binaries check-buildx check-docker-login docker-login-if-possible buildx-prepare prepare install-qemu uninstall-qemu \
        buildx test-arm32v7 test-arm64v8 test-amd64 test-images check build-one-image-for-test-purpose test-one-image

# DOCKER_REGISTRY: Nothing, or 'registry:5000/'
DOCKER_REGISTRY ?= docker.io/
# DOCKER_USERNAME: Nothing, or 'biarms'
DOCKER_USERNAME ?=
# DOCKER_PASSWORD: Nothing, or '********'
DOCKER_PASSWORD ?=
# BETA_VERSION: Nothing, or '-beta-123'
BETA_VERSION ?=
DOCKER_IMAGE_NAME = biarms/access-point
DOCKER_IMAGE_VERSION = 0.0.3
SOFTWARE_VERSION = 2.10
DOCKER_IMAGE_TAGNAME = ${DOCKER_REGISTRY}${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}
# See https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
# See https://microbadger.com/labels
VCS_REF=$(shell git rev-parse --short HEAD)

PLATFORM ?= linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/amd64

default: all

all: check-docker-login test-all-images build uninstall-qemu

build: buildx

test: test-all-images

# Launch a local build as on circleci, that will call the default target, but inside the 'circleci build and test env'
circleci-local-build: check-docker-login
	@ circleci local execute -e DOCKER_USERNAME="${DOCKER_USERNAME}" -e DOCKER_PASSWORD="${DOCKER_PASSWORD}"

check-binaries:
	@ which docker > /dev/null || (echo "Please install docker before using this script" && exit 1)
	@ which git > /dev/null || (echo "Please install git before using this script" && exit 2)
	@ # deprecated: which manifest-tool > /dev/null || (echo "Ensure that you've got the manifest-tool utility in your path. Could be downloaded from  https://github.com/estesp/manifest-tool/releases/" && exit 3)
	@ docker manifest --help | grep "docker manifest COMMAND" > /dev/null || (echo "docker manifest is needed. Consider upgrading docker" && exit 4)
	@ docker version -f '{{.Client.Experimental}}' | grep "true" > /dev/null || (echo "docker experimental mode is not enabled" && exit 5)
	# Debug info
	@ echo "DOCKER_REGISTRY: ${DOCKER_REGISTRY}"
	@ echo "BUILD_DATE: ${BUILD_DATE}"
	@ echo "VCS_REF: ${VCS_REF}"
	# Next line will fail if docker server can't be contacted
	docker version

check-docker-login: check-binaries
	@ if [[ "${DOCKER_USERNAME}" == "" ]]; then \
	    echo "DOCKER_USERNAME and DOCKER_PASSWORD env variables are mandatory for this kind of build"; \
	    echo "Consider one of these alternatives: "; \
	    echo "  - make build"; \
	    echo "  - DOCKER_USERNAME=biarms DOCKER_PASSWORD=******** BETA_VERSION='-local-test-pushed-on-docker-io' make"; \
	    echo "  - DOCKER_USERNAME=biarms DOCKER_PASSWORD=******** make circleci-local-build"; \
	    exit -1; \
	  fi

docker-login-if-possible: check-binaries
	if [[ ! "${DOCKER_USERNAME}" == "" ]]; then echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin; fi

# Test are qemu based. SHOULD_DO: use `docker buildx bake`. See https://github.com/docker/buildx#buildx-bake-options-target
install-qemu: check-binaries
	# @ # From https://github.com/multiarch/qemu-user-static:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

uninstall-qemu: check-binaries
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

# See https://docs.docker.com/buildx/working-with-buildx/
check-buildx: check-binaries
	docker buildx version

buildx-prepare: install-qemu check-buildx
	docker context create buildx-multi-arch-context || true
	docker buildx create buildx-multi-arch-context --name=buildx-multi-arch || true
	docker buildx use buildx-multi-arch
	# Debug info
	@ echo "DOCKER_IMAGE_TAGNAME: ${DOCKER_IMAGE_TAGNAME}"

buildx: docker-login-if-possible buildx-prepare
	docker buildx build --progress plain -f Dockerfile --push --platform "${PLATFORM}" --tag "${DOCKER_IMAGE_TAGNAME}" --build-arg SOFTWARE_VERSION="${SOFTWARE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" .
	docker buildx build --progress plain -f Dockerfile --push --platform "${PLATFORM}" --tag "$(DOCKER_REGISTRY)${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" --build-arg SOFTWARE_VERSION="${SOFTWARE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" .

# Fails with: "standard_init_linux.go:211: exec user process caused "no such file or directory"" if qemu is not installed...
test-all-images: test-arm32v6 test-arm32v7 test-arm64v8 test-amd64
	echo "All tests are OK :)"

test-arm32v6:
	# Logically, the test should be with "LINUX_ARCH=armv6l" (and not armv7l)
	# ARCH=arm32v6 LINUX_ARCH=armv6l DOCKER_IMAGE_VERSION=$(DOCKER_IMAGE_VERSION) make -f test-one-image
	# The pb is that 'docker run -it --rm arm32v6/alpine:3.11.6 uname -m' won't return armv6l, but armv7l.
	# So let's hack this 'very simple test' script to produce the armv6 image anyway:
	ARCH=arm32v6 LINUX_ARCH=armv7l DOCKER_IMAGE_VERSION=$(DOCKER_IMAGE_VERSION) make test-one-image

test-arm32v7:
	ARCH=arm32v7 LINUX_ARCH=armv7l DOCKER_IMAGE_VERSION=$(DOCKER_IMAGE_VERSION) make test-one-image

test-arm64v8:
	ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=$(DOCKER_IMAGE_VERSION) make test-one-image

test-amd64:
	ARCH=amd64 LINUX_ARCH=x86_64 DOCKER_IMAGE_VERSION=$(DOCKER_IMAGE_VERSION) make test-one-image

## Caution: this Makefile has 'multiple entries', which means that it is 'calling himself'.
# For instance, if you call 'make circleci-local-build':
# 1. CircleCi cli is invoked
# 2. After have installed a build environment (inside a docker container), CircleCI will call "make" without parameter, which correspond to a 'make all' build (because of default target)
# 3. And the 'all' target will run 4 times the "make test-one-image" for 3 different architecture (arm32v7, arm64v8 and amd64), via the 'test-all-images' target.
# See https://github.com/docker-library/official-images#architectures-other-than-amd64
# |---------|------------|
# |  ARCH   | LINUX_ARCH |
# |---------|------------|
# |  amd64  |   x86_64   |
# | arm32v6 |   armv6l   |
# | arm32v7 |   armv7l   |
# | arm64v8 |   aarch64  |
# |---------|------------|
ARCH ?= arm64v8
LINUX_ARCH ?= aarch64
BUILD_ARCH = $(ARCH)/
MULTI_ARCH_DOCKER_IMAGE_TAGNAME = ${DOCKER_REGISTRY}${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}-linux-${ARCH}${BETA_VERSION}

## Multi-arch targets

check: check-binaries
	@ if [[ "$(ARCH)" == "" ]]; then \
	    echo 'ARCH is $(ARCH) (MUST BE SET !)' && \
	    echo 'Correct usage sample: ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=1.2.3 make test-one-image' && \
	    echo '    or ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=1.2.3 make test-one-image' && \
        exit -1; \
	fi
	@ if [[ "$(LINUX_ARCH)" == "" ]]; then \
	    echo 'LINUX_ARCH is $(LINUX_ARCH) (MUST BE SET !)' && \
	    echo 'Correct usage sample: ' && \
	    echo '    ARCH=arm32v7 LINUX_ARCH=armv7l DOCKER_IMAGE_VERSION=1.2.3 make test-one-image' && \
	    echo '    or ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=1.2.3 make test-one-image' && \
        exit -2; \
	fi
	# Debug info
	@ echo "MULTI_ARCH_DOCKER_IMAGE_TAGNAME: ${MULTI_ARCH_DOCKER_IMAGE_TAGNAME}"

prepare: check install-qemu

# the build of this image is only for test-purpose. SHOULD_DO = test with buildx.
build-one-image: prepare
	docker build -t ${MULTI_ARCH_DOCKER_IMAGE_TAGNAME} --build-arg VERSION="${DOCKER_IMAGE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" --build-arg BUILD_ARCH="${BUILD_ARCH}" ${DOCKER_FILE} .

run-smoke-tests: prepare
	# Smoke tests:
	docker run --rm "${MULTI_ARCH_DOCKER_IMAGE_TAGNAME}" /bin/echo "Success." | grep "Success"
	docker run --rm "${MULTI_ARCH_DOCKER_IMAGE_TAGNAME}" uname -a
	docker run --rm "${MULTI_ARCH_DOCKER_IMAGE_TAGNAME}" uname -a | grep "${LINUX_ARCH}"
	(docker run --rm "$(MULTI_ARCH_DOCKER_IMAGE_TAGNAME)" hostapd -v || true) 2>&1 | grep "$(SOFTWARE_VERSION)"

test-one-image: build-one-image run-smoke-tests
