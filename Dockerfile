# Stage 1: Base image contains the release build
FROM debian:bullseye-slim

LABEL maintainer="mmBesar"
LABEL org.opencontainers.image.source="https://github.com/mmBesar/Quake2"

# Required runtime packages
RUN apt-get update && apt-get install -y \
    libstdc++6 tzdata curl unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create quake2 user (default UID:GID 1000, override via Docker args or compose)
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} quake2 && useradd -u ${UID} -g quake2 -m -s /bin/bash quake2

ENV TZ=UTC

# Game environment
ENV Q2_DIR=/srv/quake2
ENV Q2_PORT=27910
ENV Q2_HOSTNAME="Docker Quake2 Server"
ENV Q2_MAXCLIENTS=8
ENV Q2_TIMELIMIT=20
ENV Q2_FRAGLIMIT=30
ENV Q2_PASSWORD=""
ENV Q2_PUBLIC=0
ENV Q2_MAP=q2dm1
ENV Q2_GAME=baseq2
ENV Q2_GAME_MODE=deathmatch
ENV Q2_BOTS=0
ENV Q2_BOT_SKILL=1

WORKDIR ${Q2_DIR}

# Copy build artifacts from builder workflow
COPY . .

# Default map rotation config if not mounted
RUN mkdir -p config game && \
    echo 'set dm1 "map q2dm1; set nextmap vstr dm2"' > config/maprotation.cfg && \
    echo 'set dm2 "map q2dm2; set nextmap vstr dm1"' >> config/maprotation.cfg

# Startup script
COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

# Expose UDP port
EXPOSE ${Q2_PORT}/udp

# Volumes for game files and user configs
VOLUME ["/config", "/game"]

# Health check: make sure port is listening
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD netstat -uln | grep ":${Q2_PORT}" || exit 1

USER quake2
ENTRYPOINT ["/start.sh"]
