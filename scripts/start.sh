#!/bin/bash
set -e

# Use mounted config if available
CONFIG_DIR="${Q2_DIR}/config"
GAME_DIR="${Q2_DIR}/game"

MAP_ROTATION_FILE="$CONFIG_DIR/maprotation.cfg"
DEFAULT_GAME_DIR="$Q2_DIR/${Q2_GAME}"

# Print environment info
echo ">>> Quake2 Server Startup"
echo "Game directory: $DEFAULT_GAME_DIR"
echo "Config directory: $CONFIG_DIR"
echo "Game mode: $Q2_GAME_MODE"
echo "Bot support: ${Q2_BOTS}"
echo "Hostname: $Q2_HOSTNAME"
echo "Port: $Q2_PORT"
echo "Map rotation: $MAP_ROTATION_FILE"

# Prepare game directory symlink
if [ -d "$GAME_DIR" ]; then
    echo "Using mounted game directory: $GAME_DIR"
else
    echo "No external game dir mounted, using: $DEFAULT_GAME_DIR"
    ln -sf "$DEFAULT_GAME_DIR" "$GAME_DIR"
fi

# Game mode logic
GAME_MODE_FLAGS=""
case "$Q2_GAME_MODE" in
  deathmatch)
    GAME_MODE_FLAGS="+set deathmatch 1 +set coop 0 +set teamplay 0"
    ;;
  deathmatch-teamplay)
    GAME_MODE_FLAGS="+set deathmatch 1 +set coop 0 +set teamplay 1"
    ;;
  coop)
    GAME_MODE_FLAGS="+set deathmatch 0 +set coop 1 +set teamplay 0"
    ;;
  coop-teamplay)
    GAME_MODE_FLAGS="+set deathmatch 0 +set coop 1 +set teamplay 1"
    ;;
  *)
    echo "Unknown Q2_GAME_MODE: $Q2_GAME_MODE"
    exit 1
    ;;
esac

# Add bots if requested and ACEBot is available
BOT_FLAGS=""
if [[ "$Q2_BOTS" == "1" ]]; then
    if [[ -f "${Q2_DIR}/acebot/game.so" ]]; then
        echo "ACEBot found and enabled (skill=$Q2_BOT_SKILL)"
        Q2_GAME="acebot"
        BOT_FLAGS="+set skill $Q2_BOT_SKILL"
    else
        echo "Warning: ACEBot requested but not found!"
    fi
fi

# Default map if not set
if [[ -z "$Q2_MAP" ]]; then
    Q2_MAP="q2dm1"
fi

# Ensure correct permissions
chown -R quake2:quake2 "${Q2_DIR}"

# Start the server
exec "${Q2_DIR}/q2ded" \
    +set dedicated 1 \
    +set port "${Q2_PORT}" \
    +set hostname "${Q2_HOSTNAME}" \
    +set maxclients "${Q2_MAXCLIENTS}" \
    +set timelimit "${Q2_TIMELIMIT}" \
    +set fraglimit "${Q2_FRAGLIMIT}" \
    +set public "${Q2_PUBLIC}" \
    +set password "${Q2_PASSWORD}" \
    +set game "${Q2_GAME}" \
    +exec "config/maprotation.cfg" \
    $GAME_MODE_FLAGS \
    $BOT_FLAGS \
    +map "${Q2_MAP}"
