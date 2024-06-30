NAME ?=talos-orangepi5

REGISTRY ?= ghcr.io
USERNAME ?= si0ls
REGISTRY_AND_USERNAME ?= $(REGISTRY)/$(USERNAME)
SOURCE ?= https://github.com/${USERNAME}/${NAME}.git
AUTHORS ?= Louis S. <louis@schne.id>
PUSH ?= false
ARTIFACTS_FOLDER ?= ./out

TAG ?= $(shell git describe --tag --always --dirty)

KERNEL_TAG ?= 6.8
KERNEL_SOURCE ?= https://git.kernel.org/stable/t/linux-${KERNEL_TAG}.tar.gz
KERNEL_TAG_SEMVER ?= $(shell echo $(KERNEL_TAG) | sed 's/^\([0-9]*\.[0-9]*\)$$/\1.0/')
KERNEL_TAINT ?= -$(NAME)
KERNEL_VERSION ?= $(KERNEL_TAG_SEMVER)$(KERNEL_TAINT)
KERNEL_OUTPUT_NAME ?= $(NAME)-kernel
KERNEL_OUTPUT_TAG ?= $(KERNEL_TAG)-$(TAG)
KERNEL_OUTPUT_IMAGE ?= $(REGISTRY_AND_USERNAME)/$(KERNEL_OUTPUT_NAME):$(KERNEL_OUTPUT_TAG)

TALOS_TAG ?= v1.7.5
TALOS_SOURCE ?= https://github.com/siderolabs/talos.git
TALOS_VERSION ?= $(TALOS_TAG)
TALOS_AMD64_KERNEL ?= ghcr.io/siderolabs/kernel:v1.7.0-21-gc58ed7f
IMAGER_TALOS ?= talos/$(TALOS_VERSION)
IMAGER_OUTPUT_NAME ?= $(NAME)-imager
IMAGER_OUTPUT_TAG ?= $(TALOS_VERSION)-$(TAG)
IMAGER_OUTPUT_IMAGE ?= $(REGISTRY_AND_USERNAME)/$(IMAGER_OUTPUT_NAME):$(IMAGER_OUTPUT_TAG)

INSTALLER_VERSION ?= $(TAG)
INSTALLER_OUTPUT_NAME ?= $(NAME)-installer
INSTALLER_OUTPUT_TAG ?= $(TAG)
INSTALLER_OUTPUT_IMAGE ?= $(REGISTRY_AND_USERNAME)/$(INSTALLER_OUTPUT_NAME):$(INSTALLER_OUTPUT_TAG)

IMAGE_FILENAME ?= $(NAME)
IMAGE_OUTPUT_KIND ?= 
IMAGE_KIND ?= metal
IMAGE_EXTENSIONS :=
IMAGER_ARGS := --arch=arm64
IMAGER_ARGS += --overlay-name=orangepi-5
IMAGER_ARGS += --overlay-image=$(INSTALLER_OUTPUT_IMAGE)
IMAGER_ARGS += --output-kind=$(IMAGE_OUTPUT_KIND)
IMAGER_ARGS += $(forach IMAGE_EXTENSION,$(IMAGE_EXTENSIONS),--system-extension-image=$(IMAGE_EXTENSION))

INITIAL_COMMIT_SHA := $(shell git rev-list --max-parents=0 HEAD)
SOURCE_DATE_EPOCH ?= $(shell git log $(INITIAL_COMMIT_SHA) --pretty=%ct)

BUILD := docker buildx build
PROGRESS ?= auto
PLATFORM ?= linux/arm64
BUILD_COMMON_ARGS := --progress="$(PROGRESS)"
BUILD_COMMON_ARGS += --platform="$(PLATFORM)"
BUILD_COMMON_ARGS += --push="$(PUSH)"
BUILD_COMMON_ARGS += --build-arg="IMAGE_SOURCE="$(SOURCE)"
BUILD_COMMON_ARGS += --build-arg="IMAGE_AUTHORS="$(AUTHORS)"
BUILD_COMMON_ARGS += --build-arg="SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH)"

RUN := docker container run
RUN_COMMON_ARGS := --platform=$(PLATFORM)
RUN_COMMON_ARGS += --pull=always
RUN_COMMON_ARGS += --rm

EXPORT := crane export

.PHONY: all
all: build artifacts

.PHONY: build-%
build-%:
	$(BUILD) \
		$(BUILD_COMMON_ARGS) \
		--file="$*/Dockerfile" \
		--target="$*" \
		$(BUILD_ARGS) \
		$*


###### Build ######

.PHONY: build
build: kernel imager installer

.PHONY: kernel
kernel:
	$(MAKE) build-kernel \
		BUILD_ARGS="--tag=\"$(KERNEL_OUTPUT_IMAGE)\" \
			--build-arg=\"KERNEL_VERSION=$(KERNEL_VERSION)\" \
			--build-arg=\"KERNEL_SOURCE=$(KERNEL_SOURCE)\" \
			$(BUILD_ARGS)"

# TOREMOVE: Dirty hack to patch the Talos imager to use the correct kernel version and modules
$(IMAGER_TALOS):
	git clone --depth 1 --single-branch --branch $(TALOS_TAG) $(TALOS_SOURCE) $@ && \
		sed -i "s/DefaultKernelVersion = \".*\"/DefaultKernelVersion = \"$(KERNEL_VERSION)\"/g" $@/pkg/machinery/constants/constants.go && \
		rm $@/hack/modules-arm64.txt && cp imager/modules.txt $@/hack/modules-arm64.txt

.PHONY: talos
talos: $(IMAGER_TALOS)

.PHONY: imager
imager: talos
	$(MAKE) -C $(IMAGER_TALOS) \
		REGISTRY="$(REGISTRY)" \
		USERNAME="$(USERNAME)" \
		TAG="$(TALOS_TAG)" \
		PKG_KERNEL="$(KERNEL_OUTPUT_IMAGE)" \
		PLATFORM=$(PLATFORM) \
		ARCH=arm64 \
		PUSH=$(PUSH) \
		target-$@ \
		TARGET_ARGS="--output=\"type=image,name=$(IMAGER_OUTPUT_IMAGE)\" \
			--label=\"org.opencontainers.image.name=$(IMAGER_OUTPUT_NAME)\" \
			--label=\"org.opencontainers.image.title=Talos Orange Pi 5 imager\" \
			--label=\"org.opencontainers.image.description=Talos Orange Pi 5 imager\" \
			--label=\"org.opencontainers.image.source=$(SOURCE)\" \
			--label=\"org.opencontainers.image.authors=$(AUTHORS)\" \
			--label=\"org.opencontainers.image.vendor=Sidero Labs, Inc.\" \
			--label=\"org.opencontainers.image.version=$(IMAGER_OUTPUT_TAG)\" \
			--build-context=\"pkg-kernel-amd64=docker-image://$(TALOS_AMD64_KERNEL)\" \
			$(BUILD_ARGS)"

.PHONY: installer
installer:
	$(MAKE) build-installer \
		BUILD_ARGS="--tag=\"$(INSTALLER_OUTPUT_IMAGE)\" \
			--build-arg=KERNEL=\"$(KERNEL_OUTPUT_IMAGE)\" \
			--build-arg=VERSION=\"$(INSTALLER_VERSION)\" \
			$(BUILD_ARGS)"


###### Artifacts ######
.PHONY: artifacts
artifacts: images dt

$(ARTIFACTS_FOLDER):
	mkdir -p $@

.PHONY: dt
dt: $(ARTIFACTS_FOLDER)
	$(EXPORT) $(INSTALLER_OUTPUT_IMAGE) - | tar -xf - -C $(ARTIFACTS_FOLDER) artifacts/dtb && \
		mv $(ARTIFACTS_FOLDER)/artifacts/dtb $(ARTIFACTS_FOLDER)/dtb && \
		rm -rf $(ARTIFACTS_FOLDER)/artifacts

###### Images ######

.PHONY: images
images: image-metal image-pxe

.PHONY: image
image: $(ARTIFACTS_FOLDER)
	$(RUN) \
		$(RUN_COMMON_ARGS) \
		--privileged \
		--net=host \
		-v /dev:/dev \
		-v $(ARTIFACTS_FOLDER):/out \
		"$(IMAGER_OUTPUT_IMAGE)" \
		$(IMAGE_KIND) \
		--arch=arm64 \
		--overlay-name=orangepi-5 \
		--overlay-image=$(INSTALLER_OUTPUT_IMAGE) \
		$(IMAGER_ARGS)

.PHONY: image-metal
image-metal:
	$(MAKE) image && \
		mv "$(ARTIFACTS_FOLDER)/metal-arm64.raw.xz" "$(ARTIFACTS_FOLDER)/$(strip $(IMAGE_FILENAME)).raw.xz"

.PHONY: image-pxe
image-pxe: image-kernel image-initramfs

.PHONY: image-kernel
image-kernel:
	$(MAKE) image \
		IMAGE_KIND="iso" \
		IMAGE_OUTPUT_KIND="kernel"

.PHONY: image-initramfs
image-initramfs:
	$(MAKE) image \
		IMAGE_KIND="iso" \
		IMAGE_OUTPUT_KIND="initramfs"


###### Clean ######

.PHONY: clean
clean:
	rm -rf $(IMAGER_TALOS) $(ARTIFACTS_FOLDER)

.PHONY: distclean
distclean: clean
	docker image rm $(KERNEL_OUTPUT_IMAGE) $(IMAGER_OUTPUT_IMAGE) $(INSTALLER_OUTPUT_IMAGE)


###### Misc ######

# Print the version of the dependencies, needed by the CI
.PHONY: depver
depver:
	@echo "KERNEL_TAG=$(KERNEL_TAG)"
	@echo "TALOS_TAG=$(TALOS_TAG)"
