#!/bin/bash
# ============================================================
#  The Ruins of Tuxville — One-command launcher
# ============================================================
#  Usage (from this directory):
#
#    ./play.sh              # continue if possible, else new game
#    ./play.sh --new        # wipe and start fresh
#    ./play.sh --continue   # resume only (error if no world)
#
#  Starts an interactive shell with game helpers already loaded.
#  Type 'exit' to leave — progress stays on disk.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

MODE="auto"
case "${1:-}" in
    --new|-n)       MODE="new" ;;
    --continue|-c)  MODE="continue" ;;
    --help|-h)
        cat <<'HELP'
The Ruins of Tuxville — launcher

  ./play.sh              Continue existing game, or create one
  ./play.sh --new        Wipe progress and start a new game
  ./play.sh --continue   Resume only (fails if no world exists)
  ./play.sh --help       Show this help

After launch you are in a game shell with helpers loaded.
Type look, hint, status, save — or real Linux commands.
Type exit when you are done (progress stays on disk).
HELP
        exit 0
        ;;
    "")
        MODE="auto"
        ;;
    *)
        echo "Unknown option: $1  (try ./play.sh --help)"
        exit 1
        ;;
esac

# ── Ensure the world exists ──────────────────────────────────
if [[ "$MODE" == "new" ]]; then
    bash "$SCRIPT_DIR/zork.sh" --new
elif [[ "$MODE" == "continue" ]]; then
    bash "$SCRIPT_DIR/zork.sh" --continue
else
    if [[ -d "$SCRIPT_DIR/tuxville/clearing" && -f "$SCRIPT_DIR/tuxville/.game_functions.sh" ]]; then
        bash "$SCRIPT_DIR/zork.sh" --continue
    else
        bash "$SCRIPT_DIR/zork.sh" --new
    fi
fi

if [[ ! -f "$SCRIPT_DIR/tuxville/.game_functions.sh" ]]; then
    echo "  Game world is missing. Try: ./play.sh --new"
    exit 1
fi

# ── Resolve start room (last save, else clearing) ────────────
START_ROOM="clearing"
if [[ -f "$SCRIPT_DIR/tuxville/.save_state" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/tuxville/.save_state"
    if [[ -n "${SAVE_ROOM:-}" && -d "$SCRIPT_DIR/tuxville/$SAVE_ROOM" ]]; then
        START_ROOM="$SAVE_ROOM"
    fi
fi

START_PATH="$SCRIPT_DIR/tuxville/$START_ROOM"

# Stable rcfile inside the world (must survive until the new bash reads it;
# do not use EXIT trap + mktemp + exec — the trap would delete it first).
RCFILE="$SCRIPT_DIR/tuxville/.play_rc"
cat > "$RCFILE" <<EOF
# Tuxville game shell — written by play.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/tuxville/.game_functions.sh"
cd "$START_PATH" || cd "$SCRIPT_DIR/tuxville/clearing" || exit 1

export PS1='\[\e[1;33m\]tuxville\[\e[0m\]:\W\$ '

echo ""
echo "  ────────────────────────────────────────────────"
echo "  Game shell ready. Helpers are loaded."
echo "  Room: $START_ROOM"
echo ""
echo "  try:  look   |  hint   |  status   |  save"
echo "        ls -a  |  inventory"
echo "  exit: type  exit  (progress is kept on disk)"
echo "  ────────────────────────────────────────────────"
echo ""
look
EOF

echo ""
echo "  Starting game shell… (type 'exit' to leave)"
echo ""
exec bash --rcfile "$RCFILE" -i
