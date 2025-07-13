# Stage 1: Download and unpack the Quake2 release
FROM curlimages/curl:latest AS downloader

ARG TAG
ARG ARCH
ARG GAME_DIR=Quake2

WORKDIR /tmp
RUN curl -fL -o quake2.zip \
      https://github.com/mmBesar/Quake2/releases/download/${TAG}/quake2-${ARCH}-${TAG}.zip \
    && unzip quake2.zip \
    && mv ${GAME_DIR} quake2

# Stage 2: Runtime image
FROM debian:bullseye-slim

LABEL maintainer="mmBesar"
LABEL org.opencontainers.image.source="https://github.com/mmBesar/Quake2"

# Install runtime deps
RUN apt-get update \
 && apt-get install -y libstdc++6 tzdata ca-certificates libopenal1 libsdl2-2.0-0 libgl1 curl unzip \
 && rm -rf /var/lib/apt/lists/*

# Create quake2 user
ARG PUID=1000
ARG PGID=1000
RUN groupadd -g ${PGID} quake2 \
 && useradd -u ${PUID} -g quake2 -m -s /bin/bash quake2

ENV TZ=UTC
ENV Q2_DIR=/srv/quake2
# (other ENV vars…)

# Copy the unpacked files from Stage 1
COPY --from=downloader /tmp/quake2 ${Q2_DIR}

# Setup config & game dirs
RUN mkdir -p ${Q2_DIR}/config ${Q2_DIR}/game \
 && echo 'set dm1 "map q2dm1; set nextmap vstr dm2"' > ${Q2_DIR}/config/maprotation.cfg \
 && echo 'set dm2 "map q2dm2; set nextmap vstr dm1"' >> ${Q2_DIR}/config/maprotation.cfg

# Copy entrypoint
COPY scripts/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR ${Q2_DIR}
VOLUME ["/srv/quake2/config","/srv/quake2/game"]
EXPOSE ${Q2_PORT}/udp

USER quake2
ENTRYPOINT ["/usr/local/bin/start.sh"]

EXPOSE ${Q2_PORT}/udp
