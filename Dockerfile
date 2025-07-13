###############################################################################
# Stage 1: Download pre‑built Quake2 binaries (multi‑arch)
###############################################################################
FROM curlimages/curl:latest AS downloader

ARG TAG
ARG ARCH

WORKDIR /tmp

# Fetch the ZIP for the right arch/tag, unpack into /quake2
RUN curl -fL -o quake2.zip \
      https://github.com/mmBesar/Quake2/releases/download/${TAG}/quake2-linux-${ARCH}-${TAG}.zip \
    && unzip quake2.zip \
    && mv Quake2 /quake2

###############################################################################
# Stage 2: Runtime image
###############################################################################
FROM debian:bullseye-slim

LABEL maintainer="mmBesar"
LABEL org.opencontainers.image.source="https://github.com/mmBesar/Quake2"

# Install runtime deps
RUN apt-get update && apt-get install -y \
    libsdl2-2.0-0 libopenal1 libcurl4 tzdata ca-certificates unzip \
  && rm -rf /var/lib/apt/lists/*

# Create quake2 user
ARG PUID=1000
ARG PGID=1000
RUN groupadd -g ${PGID} quake2 \
 && useradd -u ${PUID} -g quake2 -m -s /bin/bash quake2

# Default ENV values (override at docker run)
ENV TZ=UTC \
    Q2_DIR=/srv/quake2 \
    Q2_PORT=27910 \
    Q2_HOSTNAME="Docker Quake2 Server" \
    Q2_MAXCLIENTS=8 \
    Q2_TIMELIMIT=20 \
    Q2_FRAGLIMIT=30 \
    Q2_PASSWORD="" \
    Q2_PUBLIC=0 \
    Q2_MAP=q2dm1 \
    Q2_GAME=baseq2 \
    Q2_GAME_MODE=deathmatch \
    Q2_BOTS=0 \
    Q2_BOT_SKILL=1

# Copy the binaries into place
COPY --from=downloader /quake2 ${Q2_DIR}

# Prepare config & game dirs
RUN mkdir -p ${Q2_DIR}/config ${Q2_DIR}/game \
 && echo 'set dm1 "map q2dm1; set nextmap vstr dm2"' > ${Q2_DIR}/config/maprotation.cfg \
 && echo 'set dm2 "map q2dm2; set nextmap vstr dm1"' >> ${Q2_DIR}/config/maprotation.cfg

# Copy entrypoint script
COPY scripts/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

WORKDIR ${Q2_DIR}
VOLUME ["/srv/quake2/config","/srv/quake2/game"]
EXPOSE ${Q2_PORT}/udp

USER quake2
ENTRYPOINT ["/usr/local/bin/start.sh"]
