FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      util-linux gdisk dosfstools e2fsprogs kpartx udev dmsetup vim-common \
    && rm -rf /var/lib/apt/lists/*
ARG IMG_SIZE ARG IMG_PATH
COPY build_template.sh /usr/local/bin/
CMD ["bash"]
