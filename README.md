# Magicraft Clone (Godot 4)

A fan-made, mechanics-faithful reimplementation of the roguelike wand-builder
**Magicraft**, covering the game up to (and including) the first boss — the
**Giant Spider** at the end of the Chapter 1 dark-forest floor.

All code and art are original: every sprite and sound is generated
procedurally at runtime, so the repository contains no binary assets. This
project is not affiliated with or endorsed by the developers of Magicraft;
it replicates game *mechanics* for study purposes.

## Play

Open the project in **Godot 4.3+** and run (`F5`), or from a terminal:

```sh
godot --path .
```

### Controls

| Input | Action |
|---|---|
| WASD / arrows | Move |
| Mouse | Aim |
| Left mouse (hold) | Cast the active wand |
| Space | Dash (i-frames) |
| E | Interact (pedestals, shops, chests, doors) |
| Tab | Spell inventory (rearrange wand slots) |
| Q | Swap wands (when you own two) |
| R | Restart after death/victory |

## What's replicated

### Wand & spell system
- Wands are slot racks cast **in sequence, left to right**; holding fire walks
  a cast cursor through the slots.
- **Per-wand mana pools** with per-wand regen; casting stalls until mana
  recovers, and the sequence pays a recharge pause when it loops.
- **Enhancement (modifier) spells affect every spell to their right** for the
  rest of the sequence — placement matters, exactly like Magicraft.
- **Duplicate modifiers of the same type do not stack** — diversify instead.
- **Spell fusion**: Workshop rooms hold a synthesis bench where two spells
  merge into one hybrid slot (irreversible). Projectile+projectile fires both
  payloads, projectile+enhancement bakes the modifier in permanently, and
  fusing two copies of the same spell **levels it up** (star levels ×1.5
  damage).
- Starter loadout: a weak Apprentice Wand and **6× Magic Bullet** (the cheap
  bolt that marks enemies to take amplified damage, stacking).
- Spells: Magic Bullet, Bing's Arrow, Arcane Nova, Condensed Water Bubble,
  Butterfly; enhancements: Volley, Track, Venom Crystal (stacking poison DoT),
  Rebound, Split, Energy Saving Mode, Empower.

### Run structure
- **Forward-only progression, no backtracking**: clearing a room opens 2–3
  exit doors, each **previewing the reward type** of the room behind it
  (Battle / Spell / Gold / Relic / Shop / Workshop / Fountain).
- The floor funnels into the **boss door at depth 8**.
- Combat rooms lock until every enemy dies, then drop a coin reward.
- Shops (spells, relics, healing), relic-choice rooms, gold rooms with
  chests, healing fountains.
- Relics: Replica Glove, Prospector's Pickaxe, Endless Chest, and more —
  run-long passives.

### Chapter 1 bestiary
- **Small Spider** — skitters at you in bursts.
- **Brood Spider** — tanky; releases hatchlings on death.
- **Corrupted Eye** — bounces around the room spitting tracking bolts.
- **Wandering Worm** — telegraphed straight-line burrow-lunges.

### First boss: the Giant Spider (~650 HP)
- **Linear Charge** — telegraphed rush along a marked line.
- **Web Shot** — spread clusters of webs that entangle and slow you.
- **Minion Spawn** — periodically summons small spiders.
- No hard phases: attack cadence and add pressure **escalate as its HP
  drops**, and a no-nonsense boss health bar tracks the fight.
- Victory opens a portal that ends this build.

## Development / testing

The game is fully testable headless (no GPU needed):

```sh
godot --headless --path . --import          # first time: build the cache
godot --headless --path . res://tests/TestRunner.tscn
```

The suite covers the wand cast-sequence rules, modifier scoping and
non-stacking, fusion (all three combinations plus leveling), relic
aggregation, projectile/status combat, boss behavior, and a scripted
full-floor run that walks door-to-door from the start room to the boss kill.
It exits non-zero on any failure.

## Layout

```
project.godot            Godot 4.3 project (GL Compatibility renderer)
scenes/                  Main.tscn, Player.tscn
scripts/autoload/        Art (procedural sprites), Sfx (synth audio),
                         SpellDB, RelicDB, Game (run state)
scripts/player/          player controller, wand cast engine
scripts/spells/          projectile behavior
scripts/enemies/         enemy base + bestiary + Giant Spider boss
scripts/rooms/           room builder, dungeon flow, pickups, interactables
scripts/ui/              HUD, inventory / fusion UI
tests/                   headless test suite
```
