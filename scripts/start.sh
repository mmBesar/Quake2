#!/usr/bin/env bash
set -e

# Directories
Q2DIR=/srv/quake2
CONFIG=${Q2DIR}/config
GAME=${Q2DIR}/game

echo "┌────────────────────────────────────────"
echo "│ Starting Quake2 Server"
echo "├────────────────────────────────────────"
echo "│ Game mod:        $Q2_GAME"
echo "│ Game mode:       $Q2_GAME_MODE"
echo "│ Public (1/0):    $Q2_PUBLIC"
echo "│ Max clients:     $Q2_MAXCLIENTS"
echo "│ Timelimit:       $Q2_TIMELIMIT"
echo "│ Fraglimit:       $Q2_FRAGLIMIT"
echo "│ Port:            $Q2_PORT"
echo "│ Hostname:        $Q2_HOSTNAME"
echo "│ Map:             $Q2_MAP"
echo "│ Bots enabled:    $Q2_BOTS"
echo "│ Bot skill:       $Q2_BOT_SKILL"
echo "├────────────────────────────────────────"

# Mount logic
if [ -d "$GAME" ] && [ "$(ls -A $GAME)" ]; then
  echo "Using mounted game folder"
else
  echo "No /srv/quake2/game mount detected, using built-in"
  ln -sf "${Q2DIR}/${Q2_GAME}" game
fi

# Build command‑line args
ARGS="+set dedicated 1"
ARGS+=" +set port $Q2_PORT"
ARGS+=" +set hostname \"$Q2_HOSTNAME\""
ARGS+=" +set maxclients $Q2_MAXCLIENTS"
ARGS+=" +set timelimit $Q2_TIMELIMIT"
ARGS+=" +set fraglimit $Q2_FRAGLIMIT"
ARGS+=" +set public $Q2_PUBLIC"
ARGS+=" +set password \"$Q2_PASSWORD\""
ARGS+=" +set game $Q2_GAME"

# Game mode flags
case "$Q2_GAME_MODE" in
  deathmatch)        ARGS+=" +set deathmatch 1 +set coop 0 +set teamplay 0" ;;
  deathmatch-teamplay) ARGS+=" +set deathmatch 1 +set coop 0 +set teamplay 1" ;;
  coop)              ARGS+=" +set deathmatch 0 +set coop 1 +set teamplay 0" ;;
  coop-teamplay)     ARGS+=" +set deathmatch 0 +set coop 1 +set teamplay 1" ;;
  *) echo "Unknown Q2_GAME_MODE: $Q2_GAME_MODE"; exit 1 ;;
esac

# Map rotation config
ARGS+=" +exec config/maprotation.cfg"

# Start map
ARGS+=" +map $Q2_MAP"

# Bot flags
if [ "$Q2_BOTS" = "1" ]; then
  echo "Enabling built‑in AceBot (skill $Q2_BOT_SKILL)"
  ARGS+=" +set skill $Q2_BOT_SKILL +set bot_num $Q2_BOTS"
fi

echo "└────────────────────────────────────────"
echo "Final command: ./q2ded $ARGS"
exec ./q2ded $ARGS
