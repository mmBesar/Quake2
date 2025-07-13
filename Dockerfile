# --- Stage 1: Fetch the correct binary release ---
FROM curlimages/curl:latest AS downloader

ARG ARCH=linux-amd64
ARG TAG=QUAKE2_8_51

WORKDIR /tmp

RUN curl -L -o quake2.zip \
    https://github.com/mmBesar/Quake2/releases/download/${TAG}/quake2-${ARCH}-${TAG}.zip && \
    unzip quake2.zip && \
    mv Quake2 /quake2

# --- Stage 2: Runtime image ---
FROM debian:bullseye-slim

LABEL maintainer="mmBesar"
LABEL org.opencontainers.image.source="https://github.com/mmBesar/Quake2"

ENV Q2_DIR=/srv/quake2
ENV Q2_GAME=baseq2
ENV Q2_GAME_MODE=deathmatch
ENV Q2_MAP=q2dm1
ENV Q2_PORT=27910
ENV Q2_HOSTNAME="Quake2 Docker Server"
ENV Q2_MAXCLIENTS=8
ENV Q2_TIMELIMIT=20
ENV Q2_FRAGLIMIT=30
ENV Q2_PUBLIC=0
ENV Q2_PASSWORD=""
ENV Q2_BOTS=0
ENV Q2_BOTS_MOD=acebot
ENV PUID=1000
ENV PGID=1000
ENV TZ=Etc/UTC

# Required packages
RUN apt update && apt install -y libopenal1 libcurl4 libgl1 && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Create user
RUN groupadd -g ${PGID} quake2 && useradd -u ${PUID} -g ${PGID} -m quake2

# Copy binaries
COPY --from=downloader /quake2 /tmp/quake2

# Setup directories
RUN mkdir -p ${Q2_DIR}/config ${Q2_DIR}/game && \
    cp -r /tmp/quake2/* ${Q2_DIR}/ && \
    chown -R quake2:quake2 ${Q2_DIR}

WORKDIR ${Q2_DIR}

# Default map rotation config
RUN echo 'set dm1 "map q2dm1; set nextmap vstr dm2"' > ${Q2_DIR}/config/maprotation.cfg && \
    echo 'set dm2 "map q2dm2; set nextmap vstr dm3"' >> ${Q2_DIR}/config/maprotation.cfg && \
    echo 'vstr dm1' >> ${Q2_DIR}/config/server.cfg

# Copy acebot if requested (built-in placeholder)
# (Replace this with real bot install if you include others)
RUN mkdir -p ${Q2_DIR}/acebot && echo "// Acebot placeholder" > ${Q2_DIR}/acebot/game.so

USER quake2

EXPOSE ${Q2_PORT}/udp

ENTRYPOINT ["./q2ded"]
CMD [
  "+set", "dedicated", "1",
  "+set", "game", "${Q2_BOTS} == 1 ? Q2_BOTS_MOD : Q2_GAME}",
  "+set", "deathmatch", "${Q2_GAME_MODE}" == "deathmatch" ? "1" : "0",
  "+set", "coop", "${Q2_GAME_MODE}" == "coop" ? "1" : "0",
  "+set", "teamplay", "${Q2_GAME_MODE}" == "deathmatch-teamplay" || "${Q2_GAME_MODE}" == "coop-teamplay" ? "1" : "0",
  "+set", "hostname", "${Q2_HOSTNAME}",
  "+set", "port", "${Q2_PORT}",
  "+set", "maxclients", "${Q2_MAXCLIENTS}",
  "+set", "timelimit", "${Q2_TIMELIMIT}",
  "+set", "fraglimit", "${Q2_FRAGLIMIT}",
  "+set", "public", "${Q2_PUBLIC}",
  "+set", "password", "${Q2_PASSWORD}",
  "+exec", "config/server.cfg"
]
