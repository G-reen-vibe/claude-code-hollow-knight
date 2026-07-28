extends Node
## Spell definitions, modeled on Magicraft's casting rules:
##  - "projectile" spells fire when the wand's cast cursor reaches them.
##  - "modifier" (enhancement) spells affect ALL projectile spells placed to
##    their RIGHT in the wand, for the rest of the cast sequence.
##  - Duplicate modifiers of the same id do NOT stack — diversify instead.
##  - Two spells can be fused at a Workshop bench into one hybrid occupying a
##    single slot (irreversible, like Magicraft's synthesis).

const SPELLS := {
	"magic_bullet": {
		"name": "Magic Bullet",
		"type": "projectile",
		"icon": "icon_bullet",
		"proj": "proj_bullet",
		"mana": 3.0,
		"damage": 6.0,
		"speed": 520.0,
		"cast_delay": 0.16,
		"lifetime": 1.2,
		"count": 1,
		"amp": 0.08,
		"amp_time": 3.0,
		"desc": "Cheap arcane bolt. Marks foes to take 8% more damage (stacks).",
		"price": 15,
	},
	"bings_arrow": {
		"name": "Bing's Arrow",
		"type": "projectile",
		"icon": "icon_arrow",
		"proj": "proj_arrow",
		"mana": 5.0,
		"damage": 11.0,
		"speed": 680.0,
		"cast_delay": 0.22,
		"lifetime": 1.0,
		"count": 1,
		"pierce": 1,
		"desc": "A hunter's arrow of green light that punches through one foe.",
		"price": 30,
	},
	"arcane_nova": {
		"name": "Arcane Nova",
		"type": "projectile",
		"icon": "icon_nova",
		"proj": "proj_nova",
		"mana": 11.0,
		"damage": 13.0,
		"speed": 340.0,
		"cast_delay": 0.38,
		"lifetime": 1.4,
		"count": 1,
		"explode_radius": 52.0,
		"desc": "Detonates on impact, scorching everything nearby.",
		"price": 45,
	},
	"water_bubble": {
		"name": "Condensed Water Bubble",
		"type": "projectile",
		"icon": "icon_bubble",
		"proj": "proj_bubble",
		"mana": 8.0,
		"damage": 9.0,
		"speed": 240.0,
		"cast_delay": 0.3,
		"lifetime": 2.4,
		"count": 1,
		"growth": 6.0,
		"slow": 0.35,
		"slow_time": 1.5,
		"desc": "A drifting bubble that grows stronger the longer it flies.",
		"price": 35,
	},
	"butterfly": {
		"name": "Butterfly",
		"type": "projectile",
		"icon": "icon_butterfly",
		"proj": "proj_butterfly",
		"mana": 6.0,
		"damage": 7.0,
		"speed": 300.0,
		"cast_delay": 0.24,
		"lifetime": 2.2,
		"count": 1,
		"homing_strength": 5.0,
		"desc": "A living spell that flutters toward the nearest enemy.",
		"price": 40,
	},
	# ------- enhancement (modifier) spells -------
	"volley": {
		"name": "Volley",
		"type": "modifier",
		"icon": "icon_volley",
		"mana": 2.0,
		"add_count": 2,
		"spread_deg": 16.0,
		"mana_mult": 0.8,
		"desc": "Spells to the right fire 2 extra shots in a scattered fan.",
		"price": 45,
	},
	"track": {
		"name": "Track",
		"type": "modifier",
		"icon": "icon_track",
		"mana": 3.0,
		"homing": 6.0,
		"desc": "Spells to the right curve toward enemies.",
		"price": 40,
	},
	"venom_crystal": {
		"name": "Venom Crystal",
		"type": "modifier",
		"icon": "icon_venom",
		"mana": 3.0,
		"poison": 3.0,
		"poison_time": 3.0,
		"desc": "Spells to the right envenom foes with stacking poison.",
		"price": 40,
	},
	"rebound": {
		"name": "Rebound",
		"type": "modifier",
		"icon": "icon_rebound",
		"mana": 2.0,
		"add_bounce": 2,
		"desc": "Spells to the right ricochet off walls twice.",
		"price": 30,
	},
	"split": {
		"name": "Split",
		"type": "modifier",
		"icon": "icon_split",
		"mana": 3.0,
		"split_children": 2,
		"desc": "Spells to the right split into 2 shards on impact.",
		"price": 40,
	},
	"energy_saving": {
		"name": "Energy Saving Mode",
		"type": "modifier",
		"icon": "icon_saving",
		"mana": 0.0,
		"mana_mult": 0.6,
		"desc": "Spells to the right cost 40% less mana.",
		"price": 35,
	},
	"empower": {
		"name": "Empower",
		"type": "modifier",
		"icon": "icon_power",
		"mana": 4.0,
		"damage_mult": 1.5,
		"desc": "Spells to the right deal 50% more damage.",
		"price": 45,
	},
}

func get_spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})

func is_projectile(id_or_def) -> bool:
	var def: Dictionary = id_or_def if id_or_def is Dictionary else get_spell(id_or_def)
	return def.get("type", "") == "projectile"

func all_ids() -> Array:
	return SPELLS.keys()

func random_spell_id(rng: RandomNumberGenerator, projectile_bias := 0.5) -> String:
	var projs: Array = []
	var mods: Array = []
	for id in SPELLS:
		if SPELLS[id]["type"] == "projectile":
			projs.append(id)
		else:
			mods.append(id)
	if rng.randf() < projectile_bias:
		return projs[rng.randi_range(0, projs.size() - 1)]
	return mods[rng.randi_range(0, mods.size() - 1)]

## Create a mutable spell instance from a database id.
func make_instance(id: String) -> Dictionary:
	var def := get_spell(id)
	assert(not def.is_empty(), "Unknown spell id: " + id)
	var inst := def.duplicate(true)
	inst["id"] = id
	inst["level"] = 1
	return inst

## Collecting a duplicate levels a spell up (Magicraft star levels, max 3):
## each level multiplies damage.
func level_up(inst: Dictionary) -> void:
	if inst.get("level", 1) >= 3:
		return
	inst["level"] = inst.get("level", 1) + 1
	if inst.has("damage"):
		inst["damage"] *= 1.5
	if inst.has("damage_mult"):
		inst["damage_mult"] *= 1.25
	inst["name"] = "%s %s" % [inst["name"].rstrip("★").strip_edges(), "★".repeat(inst["level"] - 1)]

## Fuse two spell instances into one hybrid occupying a single slot.
## Irreversible, like the Workshop synthesis bench.
func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	# Fusing two copies of the same spell levels it up (star levels) instead
	# of hybridizing.
	if a.get("id", "a") == b.get("id", "b") and a.get("merge_depth", 0) == 0 and b.get("merge_depth", 0) == 0 and a.get("level", 1) < 3:
		var leveled := a.duplicate(true)
		leveled["level"] = maxi(a.get("level", 1), b.get("level", 1))
		level_up(leveled)
		return leveled
	var out := a.duplicate(true)
	out["merged_from"] = [a.get("name", "?"), b.get("name", "?")]
	out["name"] = "%s + %s" % [a["name"], b["name"]]
	out["mana"] = a["mana"] + b["mana"] * 0.6
	out["merge_depth"] = a.get("merge_depth", 0) + b.get("merge_depth", 0) + 1
	if is_projectile(a) and is_projectile(b):
		# Two projectiles: one slot now fires both payloads.
		out["extra_payloads"] = a.get("extra_payloads", []).duplicate()
		out["extra_payloads"].append(b)
		out["cast_delay"] = maxf(a.get("cast_delay", 0.2), b.get("cast_delay", 0.2))
	elif is_projectile(a) != is_projectile(b):
		# Projectile + enhancement: the enhancement is baked in permanently.
		var proj := a if is_projectile(a) else b
		var mod := b if is_projectile(a) else a
		out = proj.duplicate(true)
		out["merged_from"] = [a.get("name", "?"), b.get("name", "?")]
		out["name"] = "%s (%s)" % [proj["name"], mod["name"]]
		out["mana"] = proj["mana"] + mod["mana"] * 0.6
		out["merge_depth"] = a.get("merge_depth", 0) + b.get("merge_depth", 0) + 1
		out["baked_mods"] = proj.get("baked_mods", []).duplicate()
		out["baked_mods"].append(mod)
	else:
		# Two enhancements: one slot applies both effects.
		out["stacked_mods"] = a.get("stacked_mods", []).duplicate()
		out["stacked_mods"].append(b)
	return out
