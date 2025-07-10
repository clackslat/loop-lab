FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup \
    && rm -rf /var/lib/apt/lists/*

ARG IMG_SIZE IMG_PATH
COPY ../build_image.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/build_image.sh"]
