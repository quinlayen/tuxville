#!/bin/bash
# ============================================================
#  The Ruins of Tuxville — A Linux Command Adventure
# ============================================================
#  Usage:
#    bash tuxville.sh            # continue if world exists, else new
#    bash tuxville.sh --new      # wipe and start a fresh game
#    bash tuxville.sh --continue # resume existing world (error if none)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# ──────────────────────────────────────────────────────────────
#  Source art and color definitions
# ──────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/tuxville_art.sh"

# ──────────────────────────────────────────────────────────────
#  Shorthand for the deep path (used throughout the script)
# ──────────────────────────────────────────────────────────────
ROOT="tuxville"
CLEARING="$ROOT/clearing"
ENTRANCE="$CLEARING/entrance"
TUNNEL="$ENTRANCE/tunnel"
ARCHIVES="$TUNNEL/archives"
CATACOMBS="$ARCHIVES/catacombs"
BRIDGE="$CATACOMBS/bridge"
DRAGON="$BRIDGE/dragon_lair"
ARMORY="$BRIDGE/armory"
GREAT_HALL="$ARMORY/great_hall"
LIBRARY="$GREAT_HALL/library"
TOWER_BASE="$GREAT_HALL/tower_base"
TOWER_TOP="$TOWER_BASE/tower_top"
RUNIC_CHAMBER="$CATACOMBS/runic_chamber"
WORKSHOP="$GREAT_HALL/workshop"

# ──────────────────────────────────────────────────────────────
#  Dragon spawn helper (persistable via .dragon_slain flag)
#  kill <pid> sends SIGTERM; trap marks the dragon slain forever.
# ──────────────────────────────────────────────────────────────
_dragon_pid_file() {
    echo "$(cd "$SCRIPT_DIR" && pwd)/$ROOT/.dragon_pid"
}

_dragon_running() {
    local pf pid
    pf="$(_dragon_pid_file)"
    [[ -f "$pf" ]] || return 1
    pid="$(cat "$pf" 2>/dev/null)"
    [[ -n "$pid" ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

_dragon_kill_all() {
    local pf pid
    pf="$(_dragon_pid_file)"
    if [[ -f "$pf" ]]; then
        pid="$(cat "$pf" 2>/dev/null)"
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            sleep 0.2
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$pf"
    fi
}

spawn_dragon() {
    # Already dead in this save? Do not respawn.
    if [[ -f "$ROOT/.dragon_slain" ]]; then
        return 0
    fi
    if _dragon_running; then
        return 0
    fi

    local root_abs flag bin pidfile
    root_abs="$(cd "$SCRIPT_DIR" && pwd)/$ROOT"
    flag="$root_abs/.dragon_slain"
    pidfile="$root_abs/.dragon_pid"
    bin="$root_abs/.bin"
    mkdir -p "$bin"

    # Real executable named smaug_the_dragon so `ps aux | grep smaug` works.
    # Traps live in this script (must not exec over the shell).
    cat > "$bin/smaug_the_dragon" <<'DRAGON_EOF'
#!/bin/bash
# Background "dragon" process for The Ruins of Tuxville
FLAG="${TUXVILLE_DRAGON_FLAG:-}"
PIDFILE="${TUXVILLE_DRAGON_PIDFILE:-}"
cleanup() {
    [[ -n "$FLAG" ]] && touch "$FLAG"
    [[ -n "$PIDFILE" ]] && rm -f "$PIDFILE"
    exit 0
}
trap cleanup TERM INT
trap '' HUP
echo $$ > "$PIDFILE"
# Sleep in the background and wait so SIGTERM reaches THIS shell
# (running the trap) rather than only interrupting sleep.
while true; do
    sleep 3600 &
    wait $! 2>/dev/null
done
DRAGON_EOF
    chmod +x "$bin/smaug_the_dragon"

    TUXVILLE_DRAGON_FLAG="$flag" \
    TUXVILLE_DRAGON_PIDFILE="$pidfile" \
        "$bin/smaug_the_dragon" </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
    # Brief pause so the pidfile is written
    sleep 0.15
}

# Welcome instruction boxes — fixed inner width 54 so borders stay aligned.
# Content is plain (no ANSI inside) so printf padding matches the visible width.
_banner_top()    { printf '    %s╔══════════════════════════════════════════════════════╗%s\n' "$BY" "$N"; }
_banner_mid()    { printf '    %s╠══════════════════════════════════════════════════════╣%s\n' "$BY" "$N"; }
_banner_bot()    { printf '    %s╚══════════════════════════════════════════════════════╝%s\n' "$BY" "$N"; }
_banner_row()    { printf '    %s║%s%-54s%s║%s\n' "$BY" "$N" "$1" "$BY" "$N"; }
_banner_blank()  { _banner_row ""; }

print_welcome_banner() {
    local mode="${1:-new}"
    echo "${ART_WELCOME}"
    if [[ "$mode" == "continue" ]]; then
        local saved_room=""
        if [[ -f "$ROOT/.save_state" ]]; then
            # shellcheck disable=SC1090
            source "$ROOT/.save_state"
            saved_room="${SAVE_ROOM:-}"
        fi
        echo ""
        _banner_top
        _banner_blank
        _banner_row "  WELCOME BACK, ADVENTURER"
        _banner_blank
        _banner_row "  Your world was preserved on disk. Progress lives"
        _banner_row "  in the filesystem itself (inventory, locks, files)."
        _banner_blank
        _banner_mid
        _banner_blank
        _banner_row "  TO RESUME:"
        _banner_blank
        _banner_row "    1. source tuxville/.game_functions.sh"
        if [[ -n "$saved_room" && -d "$ROOT/$saved_room" ]]; then
            _banner_row "    2. cd tuxville/${saved_room}"
        else
            _banner_row "    2. cd tuxville/clearing   (or last room)"
        fi
        _banner_row "    3. look"
        _banner_blank
        _banner_row "  SAVE / PROGRESS:"
        _banner_row "    save ......... Snapshot room + quest flags"
        _banner_row "    status ....... Quest checklist"
        _banner_row "    whereami ..... Show path inside the ruins"
        _banner_blank
        _banner_row "  Fresh start anytime:  bash tuxville.sh --new"
        _banner_blank
        _banner_row "  Tip: ./play.sh continues and loads helpers for you."
        _banner_blank
        _banner_bot
        echo ""
        return
    fi

    echo ""
    _banner_top
    _banner_blank
    _banner_row "  Deep beneath the forest lie the ruins of Tuxville,"
    _banner_row "  an underground city built by the ancient Order of"
    _banner_row "  the Open Source. Their greatest treasure - the"
    _banner_row "  Diamond Kernel - awaits the worthy."
    _banner_blank
    _banner_mid
    _banner_blank
    _banner_row "  TO BEGIN YOUR ADVENTURE:"
    _banner_blank
    _banner_row "    1. source tuxville/.game_functions.sh"
    _banner_row "    2. cd tuxville/clearing"
    _banner_row "    3. look"
    _banner_blank
    _banner_row "  Or simply run:  ./play.sh"
    _banner_blank
    _banner_row "  GAME COMMANDS (after sourcing / play.sh):"
    _banner_row "    look ......... Describe your surroundings"
    _banner_row "    inventory .... Check what you're carrying"
    _banner_row "    take <file> .. Pick up an item"
    _banner_row "    drop <file> .. Put down an item"
    _banner_row "    hint ......... Get a hint (hidden in some rooms)"
    _banner_row "    status ....... Check your quest progress"
    _banner_row "    save ......... Bookmark room + flags for resume"
    _banner_row "    whereami ..... Show path inside the ruins"
    _banner_blank
    _banner_row "  SAVING PROGRESS:"
    _banner_row "    The game world is your save file - inventory,"
    _banner_row "    permissions, and files persist on disk."
    _banner_row "    Quit anytime; run bash tuxville.sh to continue."
    _banner_row "    Use save before quitting to remember your room."
    _banner_blank
    _banner_row "  LINUX COMMANDS (the real tools):"
    _banner_row "    cd, ls, cat, grep, find, chmod, kill, and more"
    _banner_row "    Use these to solve puzzles and explore!"
    _banner_blank
    _banner_bot
    echo ""
}

# ──────────────────────────────────────────────────────────────
#  New game vs continue
# ──────────────────────────────────────────────────────────────
MODE="auto"
case "${1:-}" in
    --new|-n)       MODE="new" ;;
    --continue|-c)  MODE="continue" ;;
    --help|-h)
        echo "Usage: bash tuxville.sh [--new|--continue]"
        echo "  (default)  continue existing world, or create one if missing"
        echo "  --new      wipe tuxville/ and start a fresh adventure"
        echo "  --continue resume an existing world (fails if none)"
        exit 0
        ;;
    "")
        MODE="auto"
        ;;
    *)
        echo "Unknown option: $1  (try --help)"
        exit 1
        ;;
esac

if [[ "$MODE" == "auto" ]]; then
    if [[ -d "$ROOT/clearing" && -f "$ROOT/.game_functions.sh" ]]; then
        echo ""
        echo "  An existing Tuxville world was found."
        echo "    [C] Continue where you left off"
        echo "    [N] New game (wipes all progress)"
        echo ""
        read -r -p "  Choice [C/n]: " _choice
        case "${_choice:-C}" in
            n|N|new|NEW) MODE="new" ;;
            *)           MODE="continue" ;;
        esac
    else
        MODE="new"
    fi
fi

# Shared game-function body (written on new game AND refreshed on continue
# so players always get the latest helpers without wiping world state).
write_game_functions() {
cat <<'FUNC_EOF' > "$ROOT/.game_functions.sh"
# The Ruins of Tuxville — Game Helper Functions
# Source this file:  source tuxville/.game_functions.sh

_tuxville_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.inventory" && -f "$dir/.game_functions.sh" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo ""
}

look() {
    if [[ -f "./-" ]]; then
        echo ""
        cat "./-"
    else
        echo ""
        echo "  You see nothing special about this place."
        echo "  (You may not be inside the game world.)"
    fi

    echo ""

    local has_exits=0
    local exit_list=""
    for d in */; do
        if [[ -d "$d" ]]; then
            has_exits=1
            exit_list+="  ${d%/}"$'\n'
        fi
    done 2>/dev/null

    if [[ $has_exits -eq 1 ]]; then
        echo "  EXITS:"
        echo "$exit_list"
    else
        echo "  EXITS: none (dead end — use 'cd ..' to go back)"
        echo ""
    fi

    local has_items=0
    local item_list=""
    for f in *; do
        if [[ -f "$f" && "$f" != "-" ]]; then
            has_items=1
            item_list+="  $f"$'\n'
        fi
    done 2>/dev/null

    if [[ $has_items -eq 1 ]]; then
        echo "  ITEMS:"
        echo "$item_list"
    fi
}

inventory() {
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    echo ""
    echo "  ╔════════════════════════════════╗"
    echo "  ║       YOUR INVENTORY           ║"
    echo "  ╠════════════════════════════════╣"
    local items
    items=$(ls -A "$root/.inventory" 2>/dev/null)
    if [[ -z "$items" ]]; then
        echo "  ║  (empty)                       ║"
    else
        while IFS= read -r item; do
            # Inner width 32 (matches top border)
            printf "  ║  %-30s║\n" "$item"
        done <<< "$items"
    fi
    echo "  ╚════════════════════════════════╝"
    echo ""
}

take() {
    if [[ -z "$1" ]]; then
        echo "  Take what? Usage: take <filename>"
        return 1
    fi
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ -f "$1" ]]; then
        mv "$1" "$root/.inventory/"
        echo "  Taken: $1"
    else
        echo "  There is no '$1' here to take."
    fi
}

drop() {
    if [[ -z "$1" ]]; then
        echo "  Drop what? Usage: drop <filename>"
        return 1
    fi
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    if [[ -f "$root/.inventory/$1" ]]; then
        mv "$root/.inventory/$1" .
        echo "  Dropped: $1"
    else
        echo "  You don't have '$1' in your inventory."
    fi
}

hint() {
    if [[ -f ".hint" ]]; then
        echo ""
        cat ".hint"
        echo ""
    else
        echo ""
        echo "  No hints available here."
        echo "  Try: look, ls -a, or check 'status' for quest progress."
        echo ""
    fi
}

_dragon_is_slain() {
    local root
    root="$(_tuxville_root)"
    [[ -z "$root" ]] && return 1
    # Persistent flag written by the dragon process trap on `kill`
    if [[ -f "$root/.dragon_slain" ]]; then
        return 0
    fi
    return 1
}

status() {
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi

    local total=6
    local done=0

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║         QUEST PROGRESS               ║"
    echo "  ╠══════════════════════════════════════╣"

    if [[ -f "$root/.inventory/.rusty_lantern" ]]; then
        echo "  ║  [X] Lantern collected               ║"; ((done++))
    else
        echo "  ║  [ ] Lantern collected               ║"
    fi

    if [[ -f "$root/.inventory/.silver_key" ]]; then
        echo "  ║  [X] Silver Key found                ║"; ((done++))
    else
        echo "  ║  [ ] Silver Key found                ║"
    fi

    if _dragon_is_slain; then
        echo "  ║  [X] Dragon slain                    ║"; ((done++))
    else
        echo "  ║  [ ] Dragon slain                    ║"
    fi

    if [[ -f "$root/.inventory/diamond_kernel.txt" ]]; then
        echo "  ║  [X] Diamond Kernel recovered        ║"; ((done++))
    else
        echo "  ║  [ ] Diamond Kernel recovered        ║"
    fi

    local door_slot="$root/clearing/entrance/tunnel/archives/catacombs/bridge/armory/great_hall/tower_base/door_slot"
    if grep -q "KERNEL" "$door_slot" 2>/dev/null; then
        echo "  ║  [X] Tower door inscribed            ║"; ((done++))
    else
        echo "  ║  [ ] Tower door inscribed            ║"
    fi

    local tower_top="$root/clearing/entrance/tunnel/archives/catacombs/bridge/armory/great_hall/tower_base/tower_top"
    if [[ -r "$tower_top/victory_scroll.txt" ]]; then
        echo "  ║  [X] Tower conquered                 ║"; ((done++))
    else
        echo "  ║  [ ] Tower conquered                 ║"
    fi

    echo "  ╠══════════════════════════════════════╣"
    # Inner width 38 (matches top border)
    printf "  ║  %-36s║\n" "Progress: ${done} / ${total} quests complete"
    if [[ $done -eq $total ]]; then
        echo "  ║                                      ║"
        echo "  ║    *** VICTORY! YOU HAVE WON! ***    ║"
    fi
    echo "  ╚══════════════════════════════════════╝"
    echo ""
}

whereami() {
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi
    local rel="${PWD#"$root"/}"
    if [[ "$rel" == "$PWD" ]]; then
        rel="(game root)"
    fi
    echo ""
    echo "  You are in: $rel"
    echo "  Full path:  $PWD"
    echo ""
}

save() {
    local root
    root="$(_tuxville_root)"
    if [[ -z "$root" ]]; then
        echo "  You're not in the game world."
        return 1
    fi

    local rel="${PWD#"$root"/}"
    if [[ "$rel" == "$PWD" ]]; then
        rel=""
    fi

    local dragon_state="alive"
    if [[ -f "$root/.dragon_slain" ]]; then
        dragon_state="slain"
    elif [[ -f "$root/.dragon_pid" ]] && kill -0 "$(cat "$root/.dragon_pid" 2>/dev/null)" 2>/dev/null; then
        dragon_state="alive"
    else
        dragon_state="unknown"
    fi

    cat > "$root/.save_state" <<SAVE_EOF
# Tuxville save bookmark — written by the 'save' command
# The real save data is the tuxville/ directory itself.
SAVE_ROOM="$rel"
SAVE_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
SAVE_DRAGON="$dragon_state"
SAVE_EOF

    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║              GAME SAVED              ║"
    echo "  ╠══════════════════════════════════════╣"
    # Inner width 38 (matches top border)
    printf "  ║  %-36s║\n" "Room: ${rel:-.}"
    printf "  ║  %-36s║\n" "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  ╠══════════════════════════════════════╣"
    echo "  ║  Your inventory, locks, and files    ║"
    echo "  ║  are already on disk. To resume:     ║"
    echo "  ║                                      ║"
    echo "  ║    ./play.sh                         ║"
    echo "  ║    (or: bash tuxville.sh)            ║"
    if [[ -n "$rel" ]]; then
        printf "  ║  %-36s║\n" "Last room: tuxville/${rel}"
    else
        echo "  ║    start room: tuxville/clearing     ║"
    fi
    echo "  ║    look                              ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
}
FUNC_EOF
}

if [[ "$MODE" == "continue" ]]; then
    if [[ ! -d "$ROOT/clearing" || ! -f "$ROOT/.game_functions.sh" ]]; then
        echo "  No existing game found. Run: bash tuxville.sh --new"
        exit 1
    fi
    # Refresh helpers without wiping world state, then reattach dragon.
    write_game_functions
    spawn_dragon
    print_welcome_banner continue
    exit 0
fi

# ──────────────────────────────────────────────────────────────
#  Clean up any previous game session (new game only)
# ──────────────────────────────────────────────────────────────
_dragon_kill_all
# Also clear any leftover exec -a dragons from older game versions
pkill -9 -x smaug_the_dragon 2>/dev/null || true
chmod -R u+rwx tuxville 2>/dev/null || true
rm -rf tuxville 2>/dev/null

# ──────────────────────────────────────────────────────────────
#  Build the world
# ──────────────────────────────────────────────────────────────
mkdir -p "$ROOT/.inventory"
mkdir -p "$CLEARING"
mkdir -p "$ENTRANCE"
mkdir -p "$TUNNEL"
mkdir -p "$ARCHIVES"
mkdir -p "$CATACOMBS/alcove_north/niche_1"
mkdir -p "$CATACOMBS/alcove_north/niche_2"
mkdir -p "$CATACOMBS/alcove_east/crypt"
mkdir -p "$CATACOMBS/alcove_east/ossuary"
mkdir -p "$CATACOMBS/alcove_south/chamber/vault"
mkdir -p "$CATACOMBS/alcove_west"
mkdir -p "$BRIDGE"
mkdir -p "$DRAGON"
mkdir -p "$ARMORY"
mkdir -p "$GREAT_HALL"
mkdir -p "$LIBRARY"
mkdir -p "$TOWER_BASE"
mkdir -p "$TOWER_TOP"
mkdir -p "$RUNIC_CHAMBER"
mkdir -p "$WORKSHOP"

# ──────────────────────────────────────────────────────────────
#  Helper functions file (.game_functions.sh)
# ──────────────────────────────────────────────────────────────
write_game_functions


# ══════════════════════════════════════════════════════════════
#  ROOM CONTENT — descriptions use file named "-" with colors
#  (unquoted heredocs so color variables expand)
# ══════════════════════════════════════════════════════════════

# ──────────────────────────────────────────────────────────────
#  R0: THE CLEARING (start room)
#  Teaches: ls -a, cat, mv/take
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$CLEARING/-"
${ART_CLEARING}
  ${BG}═══════════════════════════════════════════════════${N}
    ${BG}THE CLEARING${N}
  ${BG}═══════════════════════════════════════════════════${N}

  You stand in a ${G}sun-dappled forest clearing${N}. Ancient stone
  steps descend into darkness ahead — the entrance to the
  long-abandoned underground city of ${BY}Tuxville${N}.

  A ${Y}weathered wooden sign${N} stands at the edge of the clearing.
  The grass is tall and wild. Things could easily be ${BW}hidden${N}
  among the overgrowth.

  A wise adventurer would search thoroughly and ${BY}take anything
  useful${N} before descending. Once underground, there is no
  coming back for forgotten supplies.

  ${G}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$CLEARING/weathered_sign.txt"
  ================================================================
    THE RUINS OF TUXVILLE
  ================================================================

  HEAR YE, BRAVE ADVENTURER!

  Beneath this clearing lie the ruins of Tuxville, the
  underground city built by the ancient Order of the Open
  Source. They sealed their greatest treasure — the DIAMOND
  KERNEL — deep within before vanishing.

  Many have entered. Few have returned.

  The path is long and fraught with locked doors, ancient
  riddles, and at least one very angry dragon.

  ADVICE: Take everything useful. Search carefully — not
  everything is visible at first glance. Items starting
  with a dot (.) are hidden from plain sight.

  ================================================================
EOF

cat <<'EOF' > "$CLEARING/old_map.txt"
  ================================================================
    ROUGH MAP — Scratched onto bark by a previous adventurer
  ================================================================

      [Clearing]  <-- You Are Here
           |
      [Entrance]
           |
       [Tunnel]
           |
      [Archives]
           |
     [Catacombs] --- [Runic Chamber] (side room)
           |
       [Bridge]  --- Here the path splits!
       /      \
  [Dragon]  [Armory]
              |
          [Great Hall] --- [Workshop] (side room)
           /       \
     [Library]  [Tower]  <-- Final destination

  NOTE: "Couldn't get into the armory. Some kind of
  permission lock. And there was a dragon..."

  NOTE 2: "Found two strange side rooms. One had
  weapons with cursed names I couldn't read. The
  other was full of enchanted orbs — only a few
  contained anything readable..."

  ================================================================
EOF

echo "A rusty but functional lantern. It still has oil." > "$CLEARING/.rusty_lantern"

cat <<'EOF' > "$CLEARING/.hint"
  HINT: Use 'ls -a' to reveal hidden files (names starting
  with a dot). There's something useful hidden in this
  clearing that you'll need for the dark tunnels ahead.

  Once you find it, use 'take <filename>' to add it to
  your inventory, or 'mv <filename> ../.inventory/' if
  you prefer raw commands.
EOF

# ──────────────────────────────────────────────────────────────
#  R1: THE ENTRANCE HALL
#  Teaches: cd, cat (reinforcement)
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$ENTRANCE/-"
${ART_ENTRANCE}
  ${DW}═══════════════════════════════════════════════════${N}
    ${BW}THE ENTRANCE HALL${N}
  ${DW}═══════════════════════════════════════════════════${N}

  You descend the stone steps into a ${DW}crumbling antechamber${N}.
  Carved warnings line the walls, barely legible in the
  ${DY}dim light${N}. A single tunnel leads deeper underground.

  The ${DW}bones of a previous adventurer${N} lie slumped against the
  wall, a tattered note still clutched in one skeletal hand.

  ${DW}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$ENTRANCE/carved_warning.txt"
  Those who enter the Ruins of Tuxville must master the
  ancient commands. Each chamber tests a different skill.

  The Order of the Open Source built this place as a trial.
  Only the worthy may claim the Diamond Kernel.

  Turn back now, or press forward and prove yourself.
EOF

cat <<'EOF' > "$ENTRANCE/adventurer_note.txt"
  "Day 3 in these ruins. I found a tunnel with strange
  carvings along the entire length of the wall — hundreds
  of lines of text. I tried reading it all but gave up.

  If only I'd known how to read just the LAST FEW LINES
  of a long text... the important part is always at the
  end. I can hear something moving deeper in. I'm going
  to try the archives next."

  — Final note of Adventurer Korbin, never seen again
EOF

cat <<'EOF' > "$ENTRANCE/.hint"
  HINT: Use 'cd tunnel' to proceed deeper. Read the
  adventurer's note — it contains a clue about what
  skill you'll need in the next room.
EOF

# ──────────────────────────────────────────────────────────────
#  R2: THE WINDING TUNNEL
#  Teaches: head, tail
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$TUNNEL/-"
${ART_TUNNEL}
  ${DY}═══════════════════════════════════════════════════${N}
    ${Y}THE WINDING TUNNEL${N}
  ${DY}═══════════════════════════════════════════════════${N}

  A long, dark tunnel stretches before you. Every surface is
  covered in ${Y}carved text${N} — the history of Tuxville, written
  in tiny letters from floor to ceiling.

  The text runs for what seems like miles. Reading it all
  would take days. But perhaps you don't need to read ${BY}ALL${N}
  of it — just the right parts.

  The ${Y}first few lines${N} seem to be a prologue. The ${BY}last few
  lines${N} might hold the most critical information...

  A single passage leads onward to the ${C}ARCHIVES${N}.

  ${DY}═══════════════════════════════════════════════════${N}
EOF

{
    echo "=== THE HISTORY OF TUXVILLE ==="
    echo ""
    echo "In the First Age, the Order of the Open Source founded Tuxville."
    echo "They built it deep underground to protect their knowledge."
    echo "The city thrived for a thousand years before the Great Silence."
    echo ""
    for i in $(seq 6 75); do
        echo "Line $i: The chronicles describe daily life in Tuxville — trade routes, festivals, governance, and the eternal pursuit of knowledge. The details blur together after centuries."
    done
    echo ""
    echo "=== CRITICAL PASSAGE — FINAL ENTRY ==="
    echo ""
    echo "The archives hold a thousand records of every artifact."
    echo "To find what you seek among so many entries, you must"
    echo "SEARCH the records for the word DIAMOND."
    echo "Only then will the passcode be revealed."
} > "$TUNNEL/wall_carvings.txt"

cat <<'EOF' > "$TUNNEL/.hint"
  HINT: The 'head' command shows the first N lines of a file.
  The 'tail' command shows the last N lines.

  Try:  head -5 wall_carvings.txt    (first 5 lines)
  Try:  tail -5 wall_carvings.txt    (last 5 lines)

  The critical clue is at the END of the carvings.
EOF

# ──────────────────────────────────────────────────────────────
#  R3: THE ARCHIVES
#  Teaches: grep
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$ARCHIVES/-"
${ART_ARCHIVES}
  ${BC}═══════════════════════════════════════════════════${N}
    ${BC}THE ARCHIVES${N}
  ${BC}═══════════════════════════════════════════════════${N}

  A vast chamber lined floor-to-ceiling with ${C}stone tablets${N}.
  Thousands of records — every artifact Tuxville ever held
  is catalogued here.

  An index tablet near the entrance reads:

    ${W}"This archive contains records of every artifact in
     Tuxville. The record you seek mentions ${BY}DIAMOND${W}. But
     who would read two hundred entries by hand when you
     could ${BY}SEARCH${W} for a pattern instead?"${N}

  The passage continues onward to the ${DR}CATACOMBS${N}.

  ${BC}═══════════════════════════════════════════════════${N}
EOF

{
    for i in $(seq 1 200); do
        if [[ $i -eq 137 ]]; then
            echo "Record #137: The DIAMOND is protected by passcode OBSIDIAN-7741. Guard this knowledge well."
        else
            case $((i % 7)) in
                0) echo "Record #$i: Bronze chalice, recovered from the eastern quarter. Unremarkable." ;;
                1) echo "Record #$i: Iron shield bearing the crest of House Torvalds. Damaged beyond repair." ;;
                2) echo "Record #$i: Quartz crystal, purpose unknown. Stored in alcove $((i * 3))." ;;
                3) echo "Record #$i: Leather-bound journal, pages blank. Possibly enchanted." ;;
                4) echo "Record #$i: Silver ring inscribed with runes. Translation pending." ;;
                5) echo "Record #$i: Wooden staff, cracked. Once belonged to a senior administrator." ;;
                6) echo "Record #$i: Ceramic tile depicting the founding of the city. Fragmentary." ;;
            esac
        fi
    done
} > "$ARCHIVES/records.txt"

cat <<'EOF' > "$ARCHIVES/index_tablet.txt"
  The archive contains exactly 200 records. Somewhere among
  them is information about the DIAMOND KERNEL — the most
  precious artifact in all of Tuxville.

  Reading every entry by hand would be maddening. Surely
  there is a way to search for a specific word across all
  the lines at once...
EOF

cat <<'EOF' > "$ARCHIVES/.hint"
  HINT: The 'grep' command searches for a pattern in a file.
  It prints every line that contains your search term.

  Try:  grep DIAMOND records.txt

  This will instantly find the record you're looking for
  among hundreds of entries.
EOF

# ──────────────────────────────────────────────────────────────
#  R4: THE CATACOMBS
#  Teaches: find
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$CATACOMBS/-"
${ART_CATACOMBS}
  ${DR}═══════════════════════════════════════════════════${N}
    ${BR}THE CATACOMBS${N}
  ${DR}═══════════════════════════════════════════════════${N}

  A sprawling maze of narrow corridors with alcoves branching
  in every direction — ${DW}north${N}, ${DW}east${N}, ${DW}south${N}, and ${DW}west${N}. ${DR}Bones
  line the walls${N}. Your lantern flickers in the stale air.

  Somewhere in this labyrinth is a ${BY}SILVER KEY${N} needed to
  proceed. But the catacombs are vast, with alcoves within
  alcoves, niches within niches.

  Searching by hand would take hours. You need a way to
  search for a file across ${BY}ALL directories${N} at once...

  A passage marked ${W}"BRIDGE"${N} leads onward from the far end.

  Off to one side, a narrow passage leads to what looks
  like a ${BM}RUNIC CHAMBER${N} — faint, twisted light glows
  from within.

  ${DR}═══════════════════════════════════════════════════${N}
EOF

echo "The remains of an ancient Tuxville citizen. May they rest in peace." > "$CATACOMBS/alcove_east/ossuary/old_bones.txt"

cat <<'EOF' > "$CATACOMBS/alcove_west/crumbled_note.txt"
  "I hid the silver key deep in the southern alcoves,
  inside a vault within a chamber. It's a hidden file —
  its name starts with a dot.

  Good luck finding it without the right command..."

  — The Keykeeper of Tuxville
EOF

echo "An ancient silver key, cold to the touch. It might unlock something important." > "$CATACOMBS/alcove_south/chamber/vault/.silver_key"

cat <<'EOF' > "$CATACOMBS/.hint"
  HINT: The 'find' command searches for files across all
  subdirectories, no matter how deeply nested.

  Try:  find . -name '*key*'

  The '.' means "start searching from here". The '*' is a
  wildcard that matches anything. So '*key*' finds any file
  with "key" in its name.

  Once you find it, use 'take' from that directory, or:
    mv <path_to_key> <path_to_inventory>
EOF

# ──────────────────────────────────────────────────────────────
#  BONUS: THE RUNIC CHAMBER (side room off catacombs)
#  Teaches: quoting filenames with spaces, -- for dash-prefixed names
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$RUNIC_CHAMBER/-"
${ART_RUNIC}
  ${BM}═══════════════════════════════════════════════════${N}
    ${BM}THE RUNIC CHAMBER${N}
  ${BM}═══════════════════════════════════════════════════${N}

  A small alcove glows with an eerie ${M}purple light${N}. Cursed
  weapons line the walls, each bearing a twisted, unnatural
  name. The curse affects the very ${BR}NAMES${N} of things here —
  spaces, dashes, and strange characters that confuse anyone
  who tries to read them the normal way.

  A scratched warning on the wall reads:

    ${W}"The weapons here bear ${BR}CURSED NAMES${W}. You cannot simply
     speak their names aloud — the spaces and dashes will
     confuse you. You must learn to ${BY}QUOTE${W} and ${BY}ESCAPE${W}.

     Read all four weapons to reveal a secret phrase."${N}

  ${BM}═══════════════════════════════════════════════════${N}
EOF

echo "THE" > "$RUNIC_CHAMBER/normal_blade.txt"
echo "DRAGON" > "$RUNIC_CHAMBER/ancient sword.txt"
echo "FEARS" > "$RUNIC_CHAMBER/-cursed-scroll.txt"
echo "SILENCE" > "$RUNIC_CHAMBER/--dark-rune.txt"

cat <<'EOF' > "$RUNIC_CHAMBER/naming_curse_note.txt"
  NOTES ON THE NAMING CURSE — by Scholar Bourne

  In the world of Linux, filenames can contain almost any
  character — including spaces and dashes. But the shell
  treats spaces and dashes specially:

  PROBLEM 1: SPACES IN FILENAMES
    If a file is called "ancient sword.txt", typing:
      cat ancient sword.txt
    will FAIL — the shell thinks you mean TWO files:
    "ancient" and "sword.txt".

    SOLUTION: Wrap the name in quotes:
      cat "ancient sword.txt"

  PROBLEM 2: FILENAMES STARTING WITH A DASH (-)
    If a file is called "-cursed-scroll.txt", typing:
      cat -cursed-scroll.txt
    will FAIL — the shell thinks "-cursed" is an option
    flag, not a filename.

    SOLUTION: Use '--' to tell the command "everything
    after this is a filename, not an option":
      cat -- -cursed-scroll.txt

    OR prefix with './' to make it clearly a path:
      cat ./-cursed-scroll.txt

  Both tricks work for ANY Linux command, not just cat.
  This is one of the most common real-world gotchas!
EOF

cat <<'EOF' > "$RUNIC_CHAMBER/.hint"
  HINT: Read each weapon to reveal one word of a secret phrase.

  1. cat normal_blade.txt
     (This one works normally)

  2. cat "ancient sword.txt"
     (Quotes handle the space in the filename)

  3. cat -- -cursed-scroll.txt
     (The '--' tells cat to stop looking for options)

  4. cat ./--dark-rune.txt
     (The './' prefix makes it clearly a file path)

  Put the four words together to learn a secret about
  one of the creatures in this dungeon.
EOF

# ──────────────────────────────────────────────────────────────
#  R5: THE TROLL BRIDGE
#  Teaches: chmod (branching point)
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$BRIDGE/-"
${ART_BRIDGE}
  ${W}═══════════════════════════════════════════════════${N}
    ${BW}THE TROLL BRIDGE${N}
  ${W}═══════════════════════════════════════════════════${N}

  A massive stone bridge spans a ${DW}bottomless chasm${N}. The echo
  of dripping water rises from the darkness below.

  Two passages lead from the far side of the bridge:

    ${BR}DRAGON_LAIR${N} — to the east (open, but ${R}dangerous${N})
    ${BY}ARMORY${N} — to the west (the door is ${BR}locked tight${N})

  An inscription is carved into the bridge railing:

    ${Y}"The troll demands the ${BY}NUMBER OF FREE PASSAGE${Y}.
     Grant ALL beings the RIGHT to CROSS and the
     armory shall open. The ancient number is ${BW}755${Y}."${N}

  ${W}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$BRIDGE/troll_inscription.txt"
  THE TROLL'S RIDDLE:

  "I guard not with teeth or claws, but with PERMISSIONS.
  The armory door is sealed — no one may read, write, or
  enter. To pass, you must CHANGE the MODE of access.

  The number 755 means: the owner gets full control,
  and everyone else may read and pass through.

  Speak the command to change permissions, followed by
  the sacred number, and name the door you wish to open."
EOF

cat <<'EOF' > "$BRIDGE/.hint"
  HINT: The 'chmod' command changes file/directory permissions.

  Try:  chmod 755 armory

  This grants read/write/execute to the owner and
  read/execute to everyone else — unlocking the door.

  You can verify with:  ls -l
  (Look for 'drwxr-xr-x' instead of 'd---------')

  NOTE: You can also enter 'dragon_lair' without unlocking
  anything — but beware what awaits inside.
EOF

# ──────────────────────────────────────────────────────────────
#  R6: THE DRAGON'S LAIR
#  Teaches: ps, kill
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$DRAGON/-"
${ART_DRAGON}
  ${BR}═══════════════════════════════════════════════════${N}
    ${BR}THE DRAGON'S LAIR${N}
  ${BR}═══════════════════════════════════════════════════${N}

  A vast cavern opens before you, lit by an ${R}eerie glow${N}.
  The ancient dragon ${BR}SMAUG${N} sleeps here — but this is no
  ordinary beast. It is a ${BY}PROCESS${N}, a living thing woven
  into the fabric of this world, running endlessly in the
  background.

  You cannot slay it with a sword. You must find its
  ${BY}PROCESS ID${N} and ${BR}terminate${N} it.

  Smoke fills the chamber, making it hard to see, but
  behind the dragon you notice what appears to be a
  ${C}SECRET PASSAGE${N} leading somewhere...

  ${BR}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$DRAGON/dragon_scales.txt"
  FIELD NOTES ON THE DRAGON:

  The dragon is not a file — it is a PROCESS. A running
  program, lurking in the background of the system.

  To see all running processes:     ps aux
  To filter for a specific name:    ps aux | grep <name>
  To slay (terminate) a process:    kill <PID>

  The dragon's true process name is:  smaug_the_dragon

  The PID is the number in the SECOND column of the
  ps output. Find it, then kill it.
EOF

cat <<'EOF' > "$DRAGON/.hint"
  HINT: Run these commands in order:

  1.  ps aux | grep smaug
      (Find the dragon's Process ID — second column)

  2.  kill <PID>
      (Replace <PID> with the actual number)

  3.  ps aux | grep smaug
      (Verify it's dead — you should only see the
       grep command itself, not the dragon)
EOF

# ──────────────────────────────────────────────────────────────
#  R7: THE ARMORY
#  Teaches: sort, uniq, pipes (|)
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$ARMORY/-"
${ART_ARMORY}
  ${DY}═══════════════════════════════════════════════════${N}
    ${BY}THE ARMORY${N}
  ${DY}═══════════════════════════════════════════════════${N}

  A dusty armory with empty weapon racks lining the walls.
  Whatever arms were stored here were taken long ago.

  On a stone workbench lies a shattered spell scroll — the
  ${BY}SPELL OF OPENING${N}, torn into fragments. The pieces are
  scattered and jumbled, with some fragments ${Y}duplicated${N}.

  A note on the workbench explains how to reassemble them.

  The passage continues to the ${BW}GREAT HALL${N} beyond.

  ${DY}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$ARMORY/scroll_fragments.txt"
3:speak the word OPEN
1:to unlock the final gate
5:and the tower shall yield
2:face the door of stone
4:with the diamond in hand
2:face the door of stone
3:speak the word OPEN
1:to unlock the final gate
4:with the diamond in hand
5:and the tower shall yield
3:speak the word OPEN
1:to unlock the final gate
2:face the door of stone
EOF

cat <<'EOF' > "$ARMORY/workbench_note.txt"
  HOW TO REASSEMBLE THE SPELL:

  The fragments are numbered but out of order, and many
  are duplicated. To read the true spell, you must:

    1. SORT the fragments by their line numbers
    2. Remove DUPLICATE lines
    3. Read the result

  A master craftsman chains tools together using the
  PIPE symbol ( | ) — sending the output of one command
  directly into the input of the next.

  Once reassembled, the spell reveals what you need to
  know for the tower at the end of your journey.
EOF

cat <<'EOF' > "$ARMORY/.hint"
  HINT: Chain 'sort' and 'uniq' with a pipe:

  Try:  sort scroll_fragments.txt | uniq

  The 'sort' command arranges lines in order.
  The 'uniq' command removes adjacent duplicate lines.
  The '|' (pipe) sends sort's output into uniq.

  The reassembled spell tells you what to do at the tower.
EOF

# ──────────────────────────────────────────────────────────────
#  R8: THE GREAT HALL
#  Teaches: tar
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$GREAT_HALL/-"
${ART_GREAT_HALL}
  ${BW}═══════════════════════════════════════════════════${N}
    ${BW}THE GREAT HALL${N}
  ${BW}═══════════════════════════════════════════════════${N}

  A massive hall with ${W}vaulted stone ceilings${N}, once the heart
  of Tuxville. Faded banners hang from the walls.

  In the center of the hall sits an ${BY}ancient chest${N} — but it
  is no ordinary chest. It has been ${Y}COMPRESSED${N} and ${Y}ARCHIVED${N}
  using old magic, sealed into a single dense package.

  Three passages lead from here:
    ${C}LIBRARY${N} — ancient books and knowledge
    ${Y}TOWER_BASE${N} — the beginning of the final ascent
    ${B}WORKSHOP${N} — a wizard's abandoned laboratory

  ${BW}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$GREAT_HALL/chest_inscription.txt"
  This chest is sealed with compression magic.

  It is a .tar.gz archive — a common way to bundle and
  compress files in the Linux world.

  To open (extract) it:

    tar xzf <filename>

  Where:
    x = extract (unpack)
    z = decompress (it's gzipped)
    f = the next argument is the filename

  Once opened, take what's inside to your inventory.
EOF

# Create the tar.gz puzzle
echo "================================================================
  THE DIAMOND KERNEL
  Heart of Tuxville — Relic of the Order of the Open Source
================================================================

Whoever holds this artifact has proven their mastery of the
ancient commands. Take this to your inventory and ascend
the tower to claim your ultimate victory.

================================================================" > "$GREAT_HALL/diamond_kernel.txt"
tar czf "$GREAT_HALL/ancient_chest.tar.gz" -C "$GREAT_HALL" diamond_kernel.txt
rm "$GREAT_HALL/diamond_kernel.txt"

cat <<'EOF' > "$GREAT_HALL/.hint"
  HINT: Extract the chest archive:

  Try:  tar xzf ancient_chest.tar.gz

  This will create 'diamond_kernel.txt' in the current
  directory. Then pick it up:

  Try:  take diamond_kernel.txt
EOF

# ──────────────────────────────────────────────────────────────
#  BONUS: THE WIZARD'S WORKSHOP (side room off great hall)
#  Teaches: file, strings, grep -rl
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$WORKSHOP/-"
${ART_WORKSHOP}
  ${BC}═══════════════════════════════════════════════════${N}
    ${BC}THE WIZARD'S WORKSHOP${N}
  ${BC}═══════════════════════════════════════════════════${N}

  A cluttered laboratory filled with shelves of ${M}enchanted
  orbs${N}. The wizard who worked here experimented with
  encoding secrets inside magical containers.

  Most of the orbs are corrupted — filled with raw magical
  energy (${DW}binary data${N}) that looks like gibberish if you try
  to read them directly. But the wizard hid ${BY}TWO${N} readable
  secrets among the orbs:

    ${M}◆${N} One orb is ${G}entirely readable${N} (plain text)
    ${M}◆${N} One orb has a secret ${BY}EMBEDDED${N} inside binary data

  The challenge: with a dozen orbs, how do you figure out
  which ones contain something you can actually read?

  The wizard's ${C}journal${N} on the workbench might help...

  ${BC}═══════════════════════════════════════════════════${N}
EOF

cat <<'EOF' > "$WORKSHOP/wizards_journal.txt"
  JOURNAL OF WIZARD HEXDUMP — Final Entry

  I have encoded my secrets into enchanted orbs. Most
  contain pure binary energy — unreadable to the eye.
  But two orbs hold my secrets:

  SECRET 1: Hidden in plain sight. One orb is entirely
  readable text. But which one? You could 'cat' each orb
  one by one... or you could ask the system to IDENTIFY
  the TYPE of each file. There is a command that examines
  files and tells you what kind of data they contain.

  SECRET 2: Buried deeper. One orb contains binary data
  with readable text EMBEDDED within it. Even the type-
  checking command won't help here — the orb still looks
  binary overall. You need a tool that extracts STRINGS
  of readable text from binary files.

  BONUS: If you're clever, you can search ALL files at
  once for a specific word — even binary ones. The grep
  command has a flag to search recursively and show only
  filenames that match.
EOF

for i in $(seq -w 1 10); do
    head -c 256 /dev/urandom > "$WORKSHOP/orb_${i}.orb"
done

cat <<'EOF' > "$WORKSHOP/orb_11.orb"
  THE WIZARD'S FIRST SECRET:

  "In the early days of Unix, everything was a file.
  Directories, devices, even processes — all files.
  The 'file' command reveals what a file truly contains,
  regardless of its name or extension.

  Remember: never trust a filename. A file called
  'image.jpg' might contain text. A file called
  'readme.txt' might contain binary. The 'file'
  command tells you the truth."

  — Wizard Hexdump
EOF

{
    head -c 128 /dev/urandom
    echo ""
    echo "THE WIZARD'S SECOND SECRET:"
    echo ""
    echo "The 'strings' command pulls readable text from"
    echo "any file — even compiled programs and binary data."
    echo "Sysadmins use it to inspect unknown files safely."
    echo "Try: strings <suspicious_file>"
    echo ""
    echo "BONUS LORE: The Diamond Kernel was forged by"
    echo "Wizard Hexdump himself, then sealed in the Great"
    echo "Hall for a worthy adventurer to claim."
    echo ""
    head -c 128 /dev/urandom
} > "$WORKSHOP/orb_12.orb"

cat <<'EOF' > "$WORKSHOP/.hint"
  HINT: Three techniques to find readable content:

  1. The 'file' command identifies what type of data
     a file contains:

     Try:  file *.orb

     Look for the one that says "ASCII text" instead
     of "data" — that's the readable orb!

  2. The 'strings' command extracts readable text from
     binary files:

     Try:  strings orb_12.orb

     This pulls out any sequences of readable characters
     from inside binary data.

  3. The 'grep -rl' command searches and shows which
     FILES contain a match:

     Try:  grep -rl SECRET *.orb

     The '-r' means recursive, '-l' means show only
     filenames. But NOTE: grep skips binary files by
     default! Add '-a' to force it to search everything:

     Try:  grep -ral SECRET *.orb

     This finds readable text even inside binary files.
EOF

# ──────────────────────────────────────────────────────────────
#  R9: THE LIBRARY
#  Teaches: diff
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$LIBRARY/-"
${ART_LIBRARY}
  ${BC}═══════════════════════════════════════════════════${N}
    ${BC}THE LIBRARY${N}
  ${BC}═══════════════════════════════════════════════════${N}

  A grand library, its shelves carved directly into the
  stone walls. Most books have crumbled to dust, but ${BW}two
  ancient spellbooks${N} remain, sitting on lecterns side by
  side.

  They look nearly identical — but one is the ${G}TRUE Codex
  of Tux${N}, and the other is a ${R}forgery${N} left by an imposter.

  A ghostly voice echoes through the chamber:

    ${C}"Compare them. Find the line that ${BC}DIFFERS${C}.
     The true book holds the ${BY}TRUE NAME OF POWER${C}.
     You will need it at the tower."${N}

  ${BC}═══════════════════════════════════════════════════${N}
EOF

{
    echo "=== CODEX OF TUX — LEFT LECTERN ==="
    echo ""
    echo "Chapter I: The Founding"
    echo "In the beginning, there was the terminal."
    echo "And the terminal was without form, and void."
    echo "And the cursor blinked upon the face of the screen."
    echo ""
    echo "Chapter II: The Commands"
    echo "And the Order spoke: Let there be light."
    echo "And they typed 'ls' and saw the contents."
    echo "And they typed 'cd' and walked the paths."
    echo ""
    echo "Chapter III: The Name of Power"
    echo "The true name of power is KERNEL"
    echo "Speak it to the tower door and ascend."
    echo ""
    echo "Chapter IV: The Prophecy"
    echo "One day an adventurer shall come."
    echo "They shall master every command."
    echo "They shall claim the Diamond Kernel."
    echo "And Tuxville shall be restored."
    echo ""
    echo "=== END OF CODEX ==="
} > "$LIBRARY/spellbook_left.txt"

{
    echo "=== CODEX OF TUX — RIGHT LECTERN ==="
    echo ""
    echo "Chapter I: The Founding"
    echo "In the beginning, there was the terminal."
    echo "And the terminal was without form, and void."
    echo "And the cursor blinked upon the face of the screen."
    echo ""
    echo "Chapter II: The Commands"
    echo "And the Order spoke: Let there be light."
    echo "And they typed 'ls' and saw the contents."
    echo "And they typed 'cd' and walked the paths."
    echo ""
    echo "Chapter III: The Name of Power"
    echo "The true name of power is COLONEL"
    echo "Speak it to the tower door and ascend."
    echo ""
    echo "Chapter IV: The Prophecy"
    echo "One day an adventurer shall come."
    echo "They shall master every command."
    echo "They shall claim the Diamond Kernel."
    echo "And Tuxville shall be restored."
    echo ""
    echo "=== END OF CODEX ==="
} > "$LIBRARY/spellbook_right.txt"

cat <<'EOF' > "$LIBRARY/librarian_ghost.txt"
  "I am the ghost of the Librarian of Tuxville.

  Two spellbooks sit before you. They appear identical,
  but ONE LINE differs between them. One book is true,
  the other false.

  Comparing them by hand, line by line, is possible but
  tedious. There is a command that COMPARES two files and
  shows only the DIFFERENCES.

  The true name of power is in the real codex. The false
  name is a trap. Choose wisely at the tower."
EOF

cat <<'EOF' > "$LIBRARY/.hint"
  HINT: The 'diff' command compares two files line by line
  and shows only the lines that differ.

  Try:  diff spellbook_left.txt spellbook_right.txt

  The output uses '<' for lines only in the first file
  and '>' for lines only in the second file.

  One says KERNEL, the other says COLONEL.
  The TRUE name is KERNEL.
EOF

# ──────────────────────────────────────────────────────────────
#  R10: THE TOWER BASE
#  Teaches: echo, redirection (>), chmod
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$TOWER_BASE/-"
${ART_TOWER_BASE}
  ${BY}═══════════════════════════════════════════════════${N}
    ${BY}THE TOWER BASE${N}
  ${BY}═══════════════════════════════════════════════════${N}

  The base of a great stone tower, spiraling upward toward
  distant ${BY}sunlight${N}. After so long underground, the faint
  glow above fills you with hope.

  A sealed stone door blocks the stairway. A narrow ${Y}slot${N}
  is carved into the door with an inscription above it:

    ${W}"${BY}WRITE${W} the true name of power into the slot
     to prove your worth. Then open the way."${N}

  An empty file called ${Y}'door_slot'${N} sits in the slot.
  The door to ${BY}'tower_top'${N} is sealed shut.

  ${BY}═══════════════════════════════════════════════════${N}
EOF

touch "$TOWER_BASE/door_slot"

cat <<'EOF' > "$TOWER_BASE/inscription.txt"
  HOW TO INSCRIBE THE DOOR:

  To write text into a file from the command line, use
  the 'echo' command with the '>' redirection operator:

    echo 'YOUR_TEXT' > filename

  The '>' operator writes text into a file, replacing
  whatever was there before.

  Write the TRUE NAME OF POWER (discovered in the library)
  into the 'door_slot' file. Then unlock the tower_top
  directory to ascend.

  Remember the Spell of Opening from the armory:

    1: to unlock the final gate
    2: face the door of stone
    3: speak the word OPEN
    4: with the diamond in hand
    5: and the tower shall yield
EOF

cat <<'EOF' > "$TOWER_BASE/.hint"
  HINT: The true name of power is KERNEL (from the library).

  Step 1 — Write it to the door:
    echo 'KERNEL' > door_slot

  Step 2 — Unlock the tower:
    chmod 755 tower_top

  Step 3 — Ascend:
    cd tower_top
EOF

# ──────────────────────────────────────────────────────────────
#  R11: THE TOWER TOP (Victory!)
# ──────────────────────────────────────────────────────────────
cat <<EOF > "$TOWER_TOP/-"
${ART_TOWER_TOP}

  ${BY}Sunlight floods the chamber.${N} You stand at the summit of
  the Tower of Tuxville, high above the world.

  A ${BY}golden scroll${N} sits on a pedestal, waiting for you.

    TRY:  ${BW}cat victory_scroll.txt${N}
EOF

cat <<EOF > "$TOWER_TOP/victory_scroll.txt"
${ART_TOWER_TOP}

    You navigated dark tunnels, solved ancient riddles,
    slayed a dragon, and claimed the Diamond Kernel.

    Along the way, you mastered these Linux commands:

    ${BG}NAVIGATION & EXPLORATION${N}
      ${G}cd${N} .............. Change directory (move between rooms)
      ${G}cd ..${N} ........... Go back (up one directory)
      ${G}ls${N} .............. List files and directories
      ${G}ls -a${N} ........... Show hidden files (dotfiles)
      ${G}ls -l${N} ........... Show detailed permissions
      ${G}cat${N} ............. Display file contents
      ${G}pwd${N} ............. Print current location

    ${BC}FILE INSPECTION${N}
      ${C}head${N} ............ Show first lines of a file
      ${C}tail${N} ............ Show last lines of a file
      ${C}grep${N} ............ Search for text in files
      ${C}diff${N} ............ Compare two files for differences

    ${BY}FILE MANAGEMENT${N}
      ${Y}mv${N} .............. Move or rename files
      ${Y}cp${N} .............. Copy files
      ${Y}find${N} ............ Search for files by name
      ${Y}file${N} ............ Identify file types (text vs binary)
      ${Y}strings${N} ......... Extract readable text from binary files
      ${Y}tar xzf${N} ......... Extract compressed archives
      ${Y}rm${N} .............. Delete files

    ${BR}PERMISSIONS & PROCESSES${N}
      ${R}chmod${N} ........... Change file/directory permissions
      ${R}ps aux${N} .......... List running processes
      ${R}kill${N} ............ Terminate a process
      ${R}|${N} ${W}(pipe)${N} ........ Chain commands together

    ${BW}TEXT & REDIRECTION${N}
      ${W}echo${N} ............ Print text
      ${W}>${N} ............... Write text to a file
      ${W}>>${N} .............. Append text to a file
      ${W}sort${N} ............ Sort lines of text
      ${W}uniq${N} ............ Remove duplicate lines

    ${BM}FILENAME TRICKS${N}
      ${M}"file name"${N} ..... Quote filenames with spaces
      ${M}--${N} .............. Stop option parsing (for -filenames)
      ${M}./${N} .............. Prefix trick (for --filenames)

    These are the building blocks of working with Linux.
    Every sysadmin, developer, and power user relies on
    these commands daily.

    ${BY}══════════════════════════════════════════════════════${N}

    Run ${BW}'status'${N} to see your full quest checklist.
    Want to play again?  Run:  ${BW}bash tuxville.sh --new${N}
    Resume later anytime:       ${BW}bash tuxville.sh${N}  then ${BW}source${N} + ${BW}cd${N}

    ${BY}══════════════════════════════════════════════════════${N}

EOF

# ──────────────────────────────────────────────────────────────
#  Create the secret passage symlink (dragon_lair -> library)
# ──────────────────────────────────────────────────────────────
ln -s ../armory/great_hall/library "$DRAGON/secret_passage"

# ──────────────────────────────────────────────────────────────
#  Apply locks AFTER all files are written
# ──────────────────────────────────────────────────────────────
chmod 000 "$TOWER_TOP"
chmod 000 "$ARMORY"

# ──────────────────────────────────────────────────────────────
#  Spawn the dragon background process (persistable)
# ──────────────────────────────────────────────────────────────
rm -f "$ROOT/.dragon_slain"
spawn_dragon

# ──────────────────────────────────────────────────────────────
#  Welcome banner
# ──────────────────────────────────────────────────────────────
print_welcome_banner new
