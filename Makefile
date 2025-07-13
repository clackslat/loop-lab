# loop-lab/Makefile  – no fanciness, just explicit options
ARCH ?= x64                  # x64 or aarch64
IMAGE := loop-lab-disktools  # built by src/docker/Dockerfile
DEV_MNT := -v /dev:/dev      # ← always give container the host /dev

.PHONY: build esp rootfs all clean

build:                       ## Step 0/1 – create & partition image
	docker run --rm -it --privileged $(DEV_MNT) \
	  -v $(PWD):/work $(IMAGE) \
	  /work/src/docker/build_image.sh

esp: build                   ## Step 2-A – prepare ESP (UEFI Shell default)
	docker run --rm -it --privileged $(DEV_MNT) \
	  -v $(PWD):/work $(IMAGE) \
	  /work/scripts/prep_esp.sh $(ARCH)

rootfs: esp                  ## Step 2-B – unpack Ubuntu + install GRUB
	docker run --rm -it --privileged $(DEV_MNT) \
	  -v $(PWD):/work $(IMAGE) \
	  /work/scripts/import_rootfs.sh $(ARCH)

all: rootfs                  ## Full workflow

clean:
	rm -f template.img
