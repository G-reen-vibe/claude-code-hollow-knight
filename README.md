# Hollow Knight: Boss Rush

A fan tribute to Team Cherry's *Hollow Knight*, rebuilt as a **boss rush** in
**Godot 4.3**. All art is procedural vector shapes drawn in code and all sound
effects are synthesized at runtime — no external assets.

Fight the Pantheon: **Gruz Mother → False Knight → Hornet → Soul Master → The
Hollow Knight**, back to back, with a run timer and death counter. Individual
bosses can be practiced from the menu.

## Controls

| Action | Key |
|---|---|
| Move | ← / → |
| Jump (double jump) | Z or Space (hold for height) |
| Nail attack (aim with ↑ / ↓) | X |
| Dash | C |
| Vengeful Spirit (33 soul) | F |
| Focus / heal (hold, 33 soul) | A |
| Back to menu | Esc |

## The kit

The Knight has the full mid-game toolkit: variable-height jump with coyote
time and jump buffering, double jump, dash, a 4-directional nail (down-slash
**pogo** bounces refresh your dash and double jump), soul gained on nail hits,
hold-to-**Focus** healing, and the Vengeful Spirit projectile. Some boss
projectiles can be destroyed with the nail.

## The bosses

- **Gruz Mother** — charging bull rushes, ceiling slams with shockwaves, and a wild bouncing frenzy.
- **False Knight** — leaping armor, mace slams that send shockwaves, hop barrages; enrages at low health.
- **Hornet** — needle lunges, boomerang needle throws, diving strikes, gossamer thread bursts.
- **Soul Master** — teleports, homing soul orbs, floor-shaking dive slams; frantic below half health.
- **The Hollow Knight** — triple slash combos, lunging stabs, infected blob barf, and void eruptions in later phases.

## Running

Open the project in Godot 4.3+ and press play, or from a terminal:

```sh
godot --path .
```

## Tests (headless)

```sh
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn    # engine/combat integration tests
godot --headless --path . res://tests/test_attacks.tscn   # every boss attack move
```

Both exit non-zero on failure.

## Project layout

```
scenes/            main_menu, arena, results, hud, player, projectiles
scenes/bosses/     one scene per boss
scripts/           player, boss base class, HUD, game state autoload, sfx synth
scripts/bosses/    boss behaviors (async attack "brains")
tests/             headless test scenes
```
