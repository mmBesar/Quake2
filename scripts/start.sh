#!/usr/bin/env bash
set -e

Q2DIR=/srv/quake2
CONFIG=${Q2DIR}/config
GAME=${Q2DIR}/game

echo "Starting Quake2 Server:"
echo " ─ Game:       $Q2_GAME"
echo " ─ Mode:       $Q2_GAME_MODE"
echo " ─ Map:        $Q2_MAP"
echo " ─ Bots:       $Q2_BOTS (skill $Q2_BOT_SKILL)"
echo " ─ Clients:    $Q2_MAXCLIENTS"
echo " ─ Timelimit:  $Q2_TIMELIMIT"
echo " ─ Fraglimit:  $Q2_FRAGLIMIT"
echo " ─ Port:       $Q2_PORT"
echo " ─ Hostname:   $Q2_HOSTNAME"
echo

# If user mounted a complete game folder, use it; else symlink built-in
if [ -d "$GAME" ] && [ "$(ls -A $GAME)" ]; then
  echo "Using mounted game directory"
else
  echo "No /srv/quake2/game mount, using built-in $Q2_GAME"
  ln -sf "${Q2DIR}/${Q2_GAME}" "$GAME"
fi

# Compose base args
ARGS="+set dedicated 1"
ARGS+=" +set port $Q2_PORT"
ARGS+=" +set hostname \"$Q2_HOSTNAME\""
ARGS+=" +set maxclients $Q2_MAXCLIENTS"
ARGS+=" +set timelimit $Q2_TIMELIMIT"
ARGS+=" +set fraglimit $Q2_FRAGLIMIT"
ARGS+=" +set public $Q2_PUBLIC"
ARGS+=" +set password \"$Q2_PASSWORD\""
ARGS+=" +set game $Q2_GAME"

# Game mode
case "$Q2_GAME_MODE" in
  deathmatch)        ARGS+=" +set deathmatch 1 +set coop 0 +set teamplay 0" ;;
  deathmatch-teamplay) ARGS+=" +set deathmatch 1 +set coop 0 +set teamplay 1" ;;
  coop)              ARGS+=" +set deathmatch 0 +set coop 1 +set teamplay 0" ;;
  coop-teamplay)     ARGS+=" +set deathmatch 0 +set coop 1 +set teamplay 1" ;;
  *) echo "Unknown Q2_GAME_MODE: $Q2_GAME_MODE"; exit 1 ;;
esac

# Map rotation
ARGS+=" +exec config/maprotation.cfg"
ARGS+=" +map $Q2_MAP"

# Bots
if [ "$Q2_BOTS" = "1" ]; then
  echo "Enabling bots (skill $Q2_BOT_SKILL)"
  ARGS+=" +set skill $Q2_BOT_SKILL +set bot_num $Q2_BOTS"
fi

echo "⋰ Final: ./q2ded $ARGS"
exec ./q2ded $ARGS
