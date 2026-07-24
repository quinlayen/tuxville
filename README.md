# The Ruins of Tuxville

A Zork-inspired text adventure that teaches **real Linux commands**.  
You explore by changing directories, read lore with `cat`, search with `grep` and `find`, open locks with `chmod`, and slay a dragon with `kill`.

The game world is a folder tree. **Your progress is that folder** — inventory, permissions, and files stay on disk until you start a new game.

---

## Requirements

- **macOS or Linux**
- **bash** (macOS ships with bash 3.2; that’s enough)
- A normal terminal (Terminal.app, iTerm, VS Code terminal, etc.)

No install step. No root. No packages.

---

## Quick start

```bash
cd tuxville_game          # this project folder
chmod +x play.sh zork.sh  # once, if needed
./play.sh
```

That will:

1. Create the world (or resume an existing one)
2. Open a **game shell** with helpers loaded
3. Drop you in your last room (or the clearing) and run `look`

Type `exit` when you stop. Progress is kept.

| Command | What it does |
|---------|----------------|
| `./play.sh` | Continue if a world exists, otherwise new game |
| `./play.sh --new` | Wipe progress and start over |
| `./play.sh --continue` | Resume only (errors if no world) |
| `./play.sh --help` | Short help |

---

## Manual start (without play.sh)

```bash
bash zork.sh              # build or resume the world
source tuxville/.game_functions.sh
cd tuxville/clearing
look
```

---

## Saving progress

You usually **don’t need a special save format**.  
Moving items, changing permissions, extracting archives, and writing files are already permanent.

Use **`save`** before quitting so the launcher remembers your room:

```text
save
```

Then later:

```bash
./play.sh
```

You’ll land back in the room from `save` (if it still exists).

| Goal | How |
|------|-----|
| Pause and come back later | `save`, then `exit`; next time `./play.sh` |
| Start over | `./play.sh --new` |
| Check quest checklist | `status` |
| See current path in the ruins | `whereami` |

**Note:** Re-running `./play.sh --new` or `bash zork.sh --new` **deletes** the `tuxville/` world.

---

## Game commands (helpers)

These work after `play.sh` starts (or after `source tuxville/.game_functions.sh`):

| Command | Purpose |
|---------|---------|
| `look` | Describe the room, exits, and visible items |
| `hint` | Local hint (if this room has one) |
| `inventory` | What you’re carrying |
| `take <file>` | Pick up a file into inventory |
| `drop <file>` | Drop a file here from inventory |
| `status` | Quest checklist |
| `save` | Bookmark current room for resume |
| `whereami` | Print your path inside the ruins |

Everything else is a **real shell command** — that’s the point of the game.

---

## Skills you’ll practice (spoiler-free)

You will practice ideas like:

- Listing files and **hidden** files  
- Reading files and **long** files  
- Searching text and finding files by name  
- Filenames with spaces and leading dashes  
- Permissions (`chmod`)  
- Processes (`ps`, `kill`)  
- Pipes, sort/uniq  
- Archives (`tar`)  
- File types and text inside binary data  
- Comparing files (`diff`)  
- Writing to files with redirection (`>`)

Side rooms teach optional tricks; the main path teaches the core set.

---

## Tips if you’re stuck

1. Type **`hint`** in the current room.  
2. Type **`look`** again and read carefully — the room text points at the skill.  
3. Try **`ls -a`** — important things often start with a `.`  
4. Use **`status`** to see which major goals are done.  
5. Read notes and signs with **`cat <filename>`**.

Avoid spoilers online if you can; the game is built to teach by exploration.

---

## Project layout

```text
tuxville_game/
  play.sh          # one-command launcher (recommended)
  zork.sh          # builds / resumes the world
  zork_art.sh      # ASCII art + colors
  README.md        # this file
  tuxville/        # generated game world (your save)
```

`tuxville/` is created when you first play. You can back it up by copying that folder (or archiving it) if you want a manual snapshot.

---

## License / spirit

Built for learning. Share freely with students and friends.  
Inspired by classic text adventures and the everyday tools of the Unix shell.
