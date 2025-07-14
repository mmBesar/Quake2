# Multi-stage build for Yamagi Quake II Dedicated Server
FROM ubuntu:22.04 AS builder

# Build arguments
ARG TARGETARCH
ARG BUILDPLATFORM
ARG TARGETOS

# Install build dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    libgl1-mesa-dev \
    libsdl2-dev \
    libopenal-dev \
    libcurl4-openssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . /src
WORKDIR /src

# Build the dedicated server
RUN make clean && \
    mkdir -p release/baseq2 && \
    make -j$(nproc) release/q2ded && \
    make -j$(nproc) release/baseq2/game.so && \
    strip release/q2ded release/baseq2/game.so

# Runtime stage
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies only
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libsdl2-2.0-0 \
    libopenal1 \
    libcurl4 \
    ca-certificates \
    python3 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy built binaries from builder stage
COPY --from=builder /src/release/q2ded /usr/local/bin/q2ded
COPY --from=builder /src/release/baseq2/game.so /usr/local/lib/baseq2/game.so

# Create directory structure that works with any UID:GID
RUN mkdir -p /quake2/baseq2/maps \
    /quake2/baseq2/models \
    /quake2/baseq2/sounds \
    /quake2/baseq2/pics \
    /quake2/baseq2/textures \
    /quake2/logs \
    /quake2/demos \
    /quake2/config \
    && chmod -R 755 /quake2 \
    && chmod -R 777 /quake2/logs /quake2/demos /quake2/config

# Copy game.so to the quake2 directory structure
RUN cp /usr/local/lib/baseq2/game.so /quake2/baseq2/game.so

# Copy startup script
COPY <<EOF /usr/local/bin/start-server.sh
#!/bin/bash
set -e

export HOME=/quake2

# Ensure writable directories exist and are writable by current user
mkdir -p /quake2/logs /quake2/demos /quake2/config /quake2/.yq2
chmod 755 /quake2/logs /quake2/demos 2>/dev/null || true
[ -w /quake2/config ] || echo "Warning: /quake2/config is not writable"

# Configuration with environment variables
SERVER_NAME=\${SERVER_NAME:-"Yamagi Quake II Server"}
MAX_PLAYERS=\${MAX_PLAYERS:-16}
SERVER_PORT=\${SERVER_PORT:-27910}
MAP_ROTATION=\${MAP_ROTATION:-"q2dm1,q2dm2,q2dm3,q2dm4,q2dm5,q2dm6,q2dm7,q2dm8"}
TIME_LIMIT=\${TIME_LIMIT:-10}
FRAG_LIMIT=\${FRAG_LIMIT:-25}
GAME_MOD=\${GAME_MOD:-"baseq2"}
ENABLE_BOTS=\${ENABLE_BOTS:-false}
BOT_COUNT=\${BOT_COUNT:-4}
ADMIN_PASSWORD=\${ADMIN_PASSWORD:-""}
RCON_PASSWORD=\${RCON_PASSWORD:-""}
PUBLIC_SERVER=\${PUBLIC_SERVER:-true}
ALLOW_DOWNLOAD=\${ALLOW_DOWNLOAD:-true}
DEDICATED_VALUE=\${DEDICATED_VALUE:-2}
GAME_TYPE=\${GAME_TYPE:-"deathmatch"}
FRIENDLY_FIRE=\${FRIENDLY_FIRE:-false}
WEAPONS_STAY=\${WEAPONS_STAY:-false}
INSTANT_ITEMS=\${INSTANT_ITEMS:-false}
QUAD_DROP=\${QUAD_DROP:-false}
QUAD_FIRE_DROP=\${QUAD_FIRE_DROP:-false}
FORCE_RESPAWN=\${FORCE_RESPAWN:-false}
TEAM_PLAY=\${TEAM_PLAY:-false}
CTFGAME=\${CTFGAME:-false}
SPECTATOR_PASSWORD=\${SPECTATOR_PASSWORD:-""}
FLOOD_MSGS=\${FLOOD_MSGS:-4}
FLOOD_PERSECOND=\${FLOOD_PERSECOND:-4}
FLOOD_WAITDELAY=\${FLOOD_WAITDELAY:-10}
LOG_LEVEL=\${LOG_LEVEL:-1}
CHEATS=\${CHEATS:-false}
SKILL_LEVEL=\${SKILL_LEVEL:-1}
CUSTOM_CONFIG=\${CUSTOM_CONFIG:-""}

# Generate server configuration
cat > /quake2/config/server.cfg << EOL
// Yamagi Quake II Server Configuration
// Auto-generated from environment variables

// Server identification
set hostname "\$SERVER_NAME"
set maxclients \$MAX_PLAYERS
set net_port \$SERVER_PORT
set dedicated \$DEDICATED_VALUE

// Game settings
set game \$GAME_MOD
set timelimit \$TIME_LIMIT
set fraglimit \$FRAG_LIMIT
set skill \$SKILL_LEVEL
set cheats \$([ "\$CHEATS" = "true" ] && echo "1" || echo "0")

// Gameplay options
set deathmatch \$([ "\$GAME_TYPE" = "deathmatch" ] && echo "1" || echo "0")
set coop \$([ "\$GAME_TYPE" = "coop" ] && echo "1" || echo "0")
set teamplay \$([ "\$TEAM_PLAY" = "true" ] && echo "1" || echo "0")
set ctf \$([ "\$CTFGAME" = "true" ] && echo "1" || echo "0")
set dmflags \$(python3 -c "
flags = 0
if '\$FRIENDLY_FIRE' == 'true': flags |= 1
if '\$WEAPONS_STAY' == 'true': flags |= 2
if '\$INSTANT_ITEMS' == 'true': flags |= 4
if '\$QUAD_DROP' == 'true': flags |= 8
if '\$QUAD_FIRE_DROP' == 'true': flags |= 16
if '\$FORCE_RESPAWN' == 'true': flags |= 32
print(flags)
")

// Security settings
EOL

# Add password settings if provided
if [ -n "\$ADMIN_PASSWORD" ]; then
    echo "set password \"\$ADMIN_PASSWORD\"" >> /quake2/config/server.cfg
fi

if [ -n "\$RCON_PASSWORD" ]; then
    echo "set rcon_password \"\$RCON_PASSWORD\"" >> /quake2/config/server.cfg
fi

if [ -n "\$SPECTATOR_PASSWORD" ]; then
    echo "set spectator_password \"\$SPECTATOR_PASSWORD\"" >> /quake2/config/server.cfg
fi

# Add flood protection and logging
cat >> /quake2/config/server.cfg << EOL

// Flood protection
set flood_msgs \$FLOOD_MSGS
set flood_persecond \$FLOOD_PERSECOND
set flood_waitdelay \$FLOOD_WAITDELAY

// Logging
set logfile \$([ "\$LOG_LEVEL" -gt "0" ] && echo "1" || echo "0")

// Download settings
set allow_download \$([ "\$ALLOW_DOWNLOAD" = "true" ] && echo "1" || echo "0")
set allow_download_players \$([ "\$ALLOW_DOWNLOAD" = "true" ] && echo "1" || echo "0")
set allow_download_models \$([ "\$ALLOW_DOWNLOAD" = "true" ] && echo "1" || echo "0")
set allow_download_sounds \$([ "\$ALLOW_DOWNLOAD" = "true" ] && echo "1" || echo "0")
set allow_download_maps \$([ "\$ALLOW_DOWNLOAD" = "true" ] && echo "1" || echo "0")

// Public server settings
set public \$([ "\$PUBLIC_SERVER" = "true" ] && echo "1" || echo "0")

EOL

# Add custom configuration if provided
if [ -n "\$CUSTOM_CONFIG" ]; then
    echo "// Custom configuration" >> /quake2/config/server.cfg
    echo "\$CUSTOM_CONFIG" >> /quake2/config/server.cfg
fi

# Create map rotation script
IFS=',' read -ra MAPS <<< "\$MAP_ROTATION"
cat > /quake2/config/maprotation.cfg << EOL
// Map rotation configuration
alias nextmap_dm1 "map q2dm2; set nextmap nextmap_dm2"
alias nextmap_dm2 "map q2dm3; set nextmap nextmap_dm3"
alias nextmap_dm3 "map q2dm4; set nextmap nextmap_dm4"
alias nextmap_dm4 "map q2dm5; set nextmap nextmap_dm5"
alias nextmap_dm5 "map q2dm6; set nextmap nextmap_dm6"
alias nextmap_dm6 "map q2dm7; set nextmap nextmap_dm7"
alias nextmap_dm7 "map q2dm8; set nextmap nextmap_dm8"
alias nextmap_dm8 "map q2dm1; set nextmap nextmap_dm1"
set nextmap nextmap_dm1
EOL

# Create dynamic map rotation based on MAP_ROTATION
if [ \${#MAPS[@]} -gt 1 ]; then
    cat > /quake2/config/maprotation.cfg << EOL
// Dynamic map rotation
EOL
    for i in "\${!MAPS[@]}"; do
        current_map=\${MAPS[i]}
        next_index=\$(( (i + 1) % \${#MAPS[@]} ))
        next_map=\${MAPS[next_index]}
        echo "alias nextmap_\${current_map} \"map \${next_map}; set nextmap nextmap_\${next_map}\"" >> /quake2/config/maprotation.cfg
    done
    first_map=\${MAPS[0]}
    echo "set nextmap nextmap_\${first_map}" >> /quake2/config/maprotation.cfg
fi

# Change to quake2 directory
cd /quake2

# Prepare command line arguments
ARGS=()

# Add basic server arguments
ARGS+=("-dedicated" "\$DEDICATED_VALUE")
ARGS+=("-game" "\$GAME_MOD")
ARGS+=("-port" "\$SERVER_PORT")
ARGS+=("-exec" "/quake2/config/server.cfg")
ARGS+=("-exec" "/quake2/config/maprotation.cfg")

# Add the first map
if [ -n "\$MAP_ROTATION" ]; then
    FIRST_MAP=\$(echo "\$MAP_ROTATION" | cut -d',' -f1)
    ARGS+=("-map" "\$FIRST_MAP")
fi

# Add bot support if enabled
if [ "\$ENABLE_BOTS" = "true" ]; then
    ARGS+=("-bots" "\$BOT_COUNT")
fi

# Display configuration
echo "================================================"
echo "Yamagi Quake II Dedicated Server"
echo "================================================"
echo "Server Name: \$SERVER_NAME"
echo "Max Players: \$MAX_PLAYERS"
echo "Port: \$SERVER_PORT"
echo "Game Mod: \$GAME_MOD"
echo "Map Rotation: \$MAP_ROTATION"
echo "Time Limit: \$TIME_LIMIT minutes"
echo "Frag Limit: \$FRAG_LIMIT"
echo "Bots Enabled: \$ENABLE_BOTS"
if [ "\$ENABLE_BOTS" = "true" ]; then
    echo "Bot Count: \$BOT_COUNT"
fi
echo "Public Server: \$PUBLIC_SERVER"
echo "Allow Downloads: \$ALLOW_DOWNLOAD"
echo "Running as UID:GID: \$(id -u):\$(id -g)"
echo "================================================"

# Start the server
exec /usr/local/bin/q2ded "\${ARGS[@]}"
EOF

# Make the startup script executable
RUN chmod +x /usr/local/bin/start-server.sh

# Set working directory
WORKDIR /quake2

# Expose default Quake II port
EXPOSE 27910/udp

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ss -ulpn | grep :27910 || exit 1

# Set default environment variables
ENV SERVER_NAME="Yamagi Quake II Server" \
    MAX_PLAYERS=16 \
    SERVER_PORT=27910 \
    MAP_ROTATION="q2dm1,q2dm2,q2dm3,q2dm4,q2dm5,q2dm6,q2dm7,q2dm8" \
    TIME_LIMIT=10 \
    FRAG_LIMIT=25 \
    GAME_MOD="baseq2" \
    ENABLE_BOTS=false \
    BOT_COUNT=4 \
    PUBLIC_SERVER=true \
    ALLOW_DOWNLOAD=true \
    DEDICATED_VALUE=2 \
    GAME_TYPE="deathmatch" \
    FRIENDLY_FIRE=false \
    WEAPONS_STAY=false \
    INSTANT_ITEMS=false \
    QUAD_DROP=false \
    QUAD_FIRE_DROP=false \
    FORCE_RESPAWN=false \
    TEAM_PLAY=false \
    CTFGAME=false \
    FLOOD_MSGS=4 \
    FLOOD_PERSECOND=4 \
    FLOOD_WAITDELAY=10 \
    LOG_LEVEL=1 \
    CHEATS=false \
    SKILL_LEVEL=1 \
    HOME=/quake2

# Labels for metadata
LABEL org.opencontainers.image.title="Yamagi Quake II Dedicated Server" \
      org.opencontainers.image.description="Containerized Yamagi Quake II dedicated server with full configuration control" \
      org.opencontainers.image.vendor="mmBesar" \
      org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.source="https://github.com/mmBesar/Quake2" \
      org.opencontainers.image.documentation="https://github.com/mmBesar/Quake2/README.md"

# Start the server
CMD ["/usr/local/bin/start-server.sh"]
