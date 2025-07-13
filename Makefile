# loop-lab/Makefile  — minimal, explicit, multi-arch

ARCH  ?= x64                   # x64  |  aarch64
IMAGE := loop-lab-disktools    # built by src/docker/Dockerfile
DEV   := -v /dev:/dev          # give container the host /dev
WORK  := -v $(PWD):/work       # bind repo root into /work inside the container

.PHONY: build esp rootfs all clean

# Step 0/1 – create template.img + partitions
build:
	docker run --rm -it --privileged $(DEV) $(WORK) $(IMAGE) \
	  /work/src/docker/build_image.sh

# Step 2-A – populate the ESP with the UEFI Shell default
esp: build
	docker run --rm -it --privileged $(DEV) $(WORK) $(IMAGE) \
	  /work/src/docker/prep_esp.sh $(ARCH)

# Step 2-B – unpack a minimal Ubuntu rootfs and install GRUB/shim
rootfs: esp
	docker run --rm -it --privileged $(DEV) $(WORK) $(IMAGE) \
	  /work/src/docker/import_rootfs.sh $(ARCH)

all: rootfs                    # full chain

clean:
	rm -f template.img
