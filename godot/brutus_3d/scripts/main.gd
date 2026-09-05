extends Node3D

@onready var brutus: BrutusController = $Brutus
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var joystick: FreneticJoystick = $HUD/VirtualJoystick
@onready var speed_label: Label = $HUD/Speed
@onready var attack_button: Button = $HUD/AttackButton
@onready var q_button: Button = $HUD/QButton
@onready var r_button: Button = $HUD/RButton
@onready var title_label: Label = $HUD/Title
@onready var hint_label: Label = $HUD/Hint

var camera_rest_position := Vector3.ZERO
var camera_shake_left := 0.0
var camera_shake_strength := 0.0
var health_bar: ProgressBar
var health_text: Label
var match_label: Label
var status_label: Label
var end_overlay: ColorRect
var end_title: Label
var end_summary: Label
var match_time := 0.0
var wave_timer := 0.0
var match_over := false
var team_bases: Dictionary = {}
var hero_bots: Array[HeroBot] = []
var arena_map: TravessiaMap
var dragon_egg: ArenaActor
var dragon_hatched := false
var match_rules := TravessiaDefinition.match_rules()
var team_kills := [0, 0]
var team_towers_destroyed := [0, 0]
var team_damage_multiplier := {0: 1.0, 1: 1.0}
var dragon_slain_by := -1
@export var follow_player_camera := false

func _ready() -> void:
	Engine.time_scale = float(match_rules.get("game_speed", 1.0))
	arena_map = TravessiaMap.new()
	add_child(arena_map)
	arena_map.build()
	_build_match_hud()
	_build_match()
	brutus.global_position = TravessiaDefinition.PLAYER_SPAWN
	brutus.last_direction = Vector3(0, 0, -1)
	camera_rest_position = camera.position
	joystick.vector_changed.connect(brutus.set_virtual_input)
	attack_button.pressed.connect(brutus.request_attack)
	q_button.pressed.connect(brutus.request_q)
	r_button.pressed.connect(brutus.request_r)
	brutus.ability_impact.connect(_on_ability_impact)
	brutus.health_changed.connect(_on_brutus_health_changed)
	brutus.defeated.connect(_on_brutus_defeated)
	_on_brutus_health_changed(brutus.health, brutus.max_health)

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if follow_player_camera:
		var target := Vector3(brutus.global_position.x, 0.0, brutus.global_position.z)
		camera_rig.global_position = camera_rig.global_position.lerp(
			target, 1.0 - exp(-5.0 * delta)
		)
	else:
		camera_rig.global_position = Vector3.ZERO
	speed_label.text = "Movimento: %d%%  |  Ritmo: %d%%" % [
		roundi(brutus.speed_ratio * 100.0),
		roundi(float(match_rules.get("game_speed", 1.0)) * 100.0),
	]
	_update_ability_button(q_button, "Q", brutus.q_cooldown_left)
	_update_ability_button(r_button, "R", brutus.r_cooldown_left)
	_update_camera_shake(delta)
	if not match_over:
		match_time += real_delta
		var hatch_at := float(match_rules.match_duration) \
			- float(match_rules.dragon_hatch_remaining)
		if not dragon_hatched and match_time >= hatch_at:
			_hatch_dragon()
		if match_time >= float(match_rules.match_duration):
			_finish_by_time()
		wave_timer -= real_delta
		if wave_timer <= 0.0:
			wave_timer = float(match_rules.wave_interval)
			_spawn_wave()
	_update_match_label()


func _exit_tree() -> void:
	# Avoid leaking the match pace into editor previews or another scene.
	if is_equal_approx(Engine.time_scale, float(match_rules.get("game_speed", 1.0))):
		Engine.time_scale = 1.0

func _update_ability_button(button: Button, ready_text: String, cooldown: float) -> void:
	if match_over:
		button.disabled = true
		return
	button.disabled = cooldown > 0.0
	button.text = "%s\n%.1f s" % [ready_text.left(1), cooldown] if cooldown > 0.0 else ready_text

func _on_ability_impact(kind: StringName, world_position: Vector3) -> void:
	var radius := 1.35
	var damage := 95.0
	if kind == &"q":
		radius = 1.85
		damage = 150.0
		camera_shake_left = 0.16
		camera_shake_strength = 0.10
	elif kind == &"ultimate":
		radius = 2.15
		damage = 190.0
		camera_shake_left = 0.38
		camera_shake_strength = 0.24
	else:
		camera_shake_left = 0.10
		camera_shake_strength = 0.07
	_damage_enemies(world_position, radius, damage)

func _update_camera_shake(delta: float) -> void:
	if camera_shake_left > 0.0:
		camera_shake_left -= delta
		var fade := clampf(camera_shake_left / 0.38, 0.0, 1.0)
		camera.position = camera_rest_position + Vector3(
			randf_range(-1.0, 1.0) * camera_shake_strength * fade,
			randf_range(-1.0, 1.0) * camera_shake_strength * fade,
			0.0
		)
	else:
		camera.position = camera.position.lerp(camera_rest_position, 1.0 - exp(-18.0 * delta))

func _build_match() -> void:
	for structure in TravessiaDefinition.structures():
		_spawn_structure(structure)
	for objective in TravessiaDefinition.neutral_objectives():
		var neutral := _spawn_actor(objective, objective.position)
		if objective.kind == &"dragon_egg":
			dragon_egg = neutral
	_spawn_hero_bots()
	_refresh_base_protection()
	wave_timer = 0.0


func _spawn_hero_bots() -> void:
	for data in TravessiaDefinition.hero_bots():
		var bot := HeroBot.new()
		bot.position = data.position
		add_child(bot)
		bot.configure(data)
		bot.defeated.connect(_on_hero_bot_defeated)
		hero_bots.append(bot)


func _spawn_structure(data: Dictionary) -> ArenaActor:
	var kind: StringName = data.kind
	var team: int = data.team
	var damage := 125.0 if kind == &"tower" else 0.0
	var attack_range := 4.5 if kind == &"tower" else 0.0
	var actor := _spawn_actor({
		"kind": kind,
		"team": team,
		"health": data.health,
		"attack_damage": damage,
		"attack_range": attack_range,
		"attack_interval": 1.0,
		"color": data.color,
	}, data.position)
	actor.name = String(data.id).to_pascal_case()
	actor.set_meta("structure_id", data.id)
	if kind == &"base":
		team_bases[team] = actor
	return actor


func move_lane_tower(structure_id: StringName, at_position: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor == null or actor.actor_kind != &"tower":
			continue
		if actor.get_meta("structure_id", &"") != structure_id:
			continue
		actor.global_position = Vector3(at_position.x, 0.0, at_position.z)
		return arena_map.move_tower_platform(structure_id, at_position)
	return false


func _spawn_actor(data: Dictionary, at_position: Vector3) -> ArenaActor:
	var actor := ArenaActor.new()
	actor.position = at_position
	add_child(actor)
	actor.configure(data)
	actor.defeated.connect(_on_actor_defeated)
	return actor


func _spawn_wave() -> void:
	if match_over or get_tree().get_nodes_in_group("arena_actors").size() > int(match_rules.max_actors):
		return
	for lane_x in TravessiaDefinition.LANE_X:
		for team in [0, 1]:
			if _lane_minion_count(team, lane_x) \
					< int(match_rules.max_minions_per_lane):
				_spawn_minion(team, lane_x)


func _spawn_minion(team: int, lane_x: float) -> void:
	var data := TravessiaDefinition.minion(team, lane_x)
	var actor := _spawn_actor(data, data.position)
	actor.attack_damage *= float(team_damage_multiplier.get(team, 1.0))


func _lane_minion_count(team: int, lane_x: float) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.actor_kind == &"minion" and actor.team == team \
				and absf(actor.lane_x - lane_x) < 0.1 and not actor.is_defeated:
			count += 1
	return count


func _hatch_dragon() -> void:
	if dragon_hatched or match_over:
		return
	dragon_hatched = true
	arena_map.open_dragon_access(1.35)
	status_label.text = "O OVO ESTÁ CHOCANDO!"
	status_label.modulate = Color("dca3ff")
	if is_instance_valid(dragon_egg):
		dragon_egg.play_hatch()
		await get_tree().create_timer(0.86, true, false, true).timeout
	if is_instance_valid(dragon_egg):
		dragon_egg.queue_free()
	if match_over:
		return
	var dragon_data := TravessiaDefinition.dragon_definition()
	var dragon := _spawn_actor(dragon_data, dragon_data.position)
	dragon.play_spawn()
	status_label.text = "O OVO CHOCOU — DRAGÃO NO CENTRO!"
	status_label.modulate = Color("dca3ff")
	_get_tree_timer_clear_status()


func _finish_by_time() -> void:
	if match_over:
		return
	var allied_score := _team_score(0)
	var enemy_score := _team_score(1)
	var winner := -1
	if allied_score > enemy_score + 0.1:
		winner = 0
	elif enemy_score > allied_score + 0.1:
		winner = 1
	_finish_match(winner, "tempo")


func _base_health(team: int) -> float:
	var reference = team_bases.get(team)
	if is_instance_valid(reference):
		return (reference as ArenaActor).health
	return 0.0


func _team_score(team: int) -> float:
	var score := _base_health(team)
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.team == team and actor.actor_kind == &"tower" \
				and not actor.is_defeated:
			score += actor.health * 0.35
	score += float(team_kills[team]) * 45.0
	if dragon_slain_by == team:
		score += 180.0
	return score


func _damage_enemies(center: Vector3, radius: float, damage: float) -> void:
	if match_over:
		return
	for node in get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == brutus or not target.has_method("get_team"):
			continue
		if int(target.call("get_team")) == brutus.get_team():
			continue
		if target.has_method("is_targetable") and not bool(target.call("is_targetable")):
			continue
		var distance := Vector2(center.x, center.z).distance_to(
			Vector2(target.global_position.x, target.global_position.z)
		)
		if distance <= radius:
			target.call("take_damage",
				damage * float(team_damage_multiplier.get(0, 1.0)), 0)


func _on_actor_defeated(actor: ArenaActor) -> void:
	if actor.actor_kind == &"tower":
		team_towers_destroyed[1 - actor.team] += 1
		_refresh_base_protection()
		status_label.text = "TORRE INIMIGA DESTRUÍDA!" if actor.team == 1 \
			else "TORRE ALIADA DESTRUÍDA!"
		_get_tree_timer_clear_status()
	elif actor.actor_kind == &"dragon":
		_apply_dragon_reward(actor.last_damage_team)
	elif actor.actor_kind == &"base":
		_finish_match(1 - actor.team, "torre principal destruída")


func _apply_dragon_reward(team: int) -> void:
	if team < 0 or team > 1:
		status_label.text = "DRAGÃO DERROTADO"
		_get_tree_timer_clear_status()
		return
	dragon_slain_by = team
	var bonus := float(match_rules.dragon_team_damage_bonus)
	team_damage_multiplier[team] = bonus
	if team == 0 and not brutus.is_defeated:
		brutus.health = minf(brutus.max_health, brutus.health + 420.0)
		brutus.health_changed.emit(brutus.health, brutus.max_health)
	for hero in hero_bots:
		if hero.team != team:
			continue
		hero.damage_multiplier = bonus
		if not hero.is_defeated:
			hero.health = minf(hero.max_health, hero.health + hero.max_health * 0.25)
			hero.call("_update_health_bar")
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.actor_kind == &"minion" and actor.team == team:
			actor.attack_damage *= bonus
	var team_name := "AZUL" if team == 0 else "VERMELHA"
	status_label.text = "DRAGÃO DERROTADO — EQUIPE %s FORTALECIDA" % team_name
	_get_tree_timer_clear_status()


func _on_hero_bot_defeated(_hero: HeroBot, killer_team: int) -> void:
	if killer_team >= 0 and killer_team <= 1:
		team_kills[killer_team] += 1


func _refresh_base_protection() -> void:
	for team in [0, 1]:
		var standing_towers := 0
		for node in get_tree().get_nodes_in_group("arena_actors"):
			var actor := node as ArenaActor
			if actor != null and actor.team == team and actor.actor_kind == &"tower" \
					and not actor.is_defeated:
				standing_towers += 1
		var base_reference = team_bases.get(team)
		if is_instance_valid(base_reference):
			var team_base := base_reference as ArenaActor
			# Both lanes matter: the main tower opens only when every defensive
			# tower from that team has fallen.
			team_base.set_protected(standing_towers > 0)


func _on_brutus_health_changed(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum
	health_bar.value = current
	health_bar.tooltip_text = "Brutus: %d / %d" % [roundi(current), roundi(maximum)]
	if health_text != null:
		health_text.text = "BRUTUS  %d / %d" % [roundi(current), roundi(maximum)]


func _on_brutus_defeated() -> void:
	if brutus.last_damage_team >= 0 and brutus.last_damage_team <= 1:
		team_kills[brutus.last_damage_team] += 1
	status_label.text = "BRUTUS CAIU — RETORNO EM 3 s"
	attack_button.disabled = true
	q_button.disabled = true
	r_button.disabled = true
	await get_tree().create_timer(float(match_rules.respawn_time), true, false, true).timeout
	if match_over:
		return
	brutus.revive(TravessiaDefinition.PLAYER_SPAWN)
	attack_button.disabled = false
	status_label.text = "BRUTUS RETORNOU"
	_get_tree_timer_clear_status()


func _get_tree_timer_clear_status() -> void:
	_clear_status_later()


func _clear_status_later() -> void:
	await get_tree().create_timer(2.2, true, false, true).timeout
	if not match_over:
		status_label.text = ""


func _finish_match(winner_team: int, reason: String) -> void:
	if match_over:
		return
	match_over = true
	brutus.set_virtual_input(Vector2.ZERO)
	attack_button.disabled = true
	q_button.disabled = true
	r_button.disabled = true
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as Node
		if is_instance_valid(actor):
			actor.process_mode = Node.PROCESS_MODE_DISABLED
	brutus.process_mode = Node.PROCESS_MODE_DISABLED
	var title := "EMPATE"
	var color := Color.WHITE
	if winner_team == 0:
		title = "VITÓRIA!"
		color = Color("ffd45a")
	elif winner_team == 1:
		title = "DERROTA"
		color = Color("ff6477")
	status_label.text = title
	status_label.modulate = color
	_show_end_overlay(title, reason, color)


func _show_end_overlay(title: String, reason: String, color: Color) -> void:
	if end_overlay == null:
		return
	end_title.text = title
	end_title.add_theme_color_override("font_color", color)
	end_summary.text = "%s\nTorres: %d × %d   Abates: %d × %d%s" % [
		reason.capitalize(), team_towers_destroyed[0], team_towers_destroyed[1],
		team_kills[0], team_kills[1],
		"   Dragão: Azul" if dragon_slain_by == 0 else (
			"   Dragão: Vermelho" if dragon_slain_by == 1 else "")]
	end_overlay.visible = true


func _restart_match() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _build_match_hud() -> void:
	title_label.visible = false
	hint_label.visible = false
	speed_label.visible = false
	attack_button.text = "ATQ"
	q_button.text = "Q"
	r_button.text = "R"
	var prototype_label := $HUD.get_node_or_null("Prototype") as Label
	if prototype_label != null:
		prototype_label.visible = false
	title_label.text = "ARENA FRENETICA — TRAVESSIA"
	hint_label.text = "Destrua as torres e a torre principal inimiga"

	match_label = Label.new()
	match_label.name = "MatchStatus"
	match_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	match_label.offset_top = 46.0
	match_label.offset_bottom = 72.0
	match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_label.add_theme_font_size_override("font_size", 16)
	match_label.add_theme_color_override("font_color", Color("eef6e9"))
	$HUD.add_child(match_label)

	status_label = Label.new()
	status_label.name = "Announcement"
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_left = -260.0
	status_label.offset_top = 76.0
	status_label.offset_right = 260.0
	status_label.offset_bottom = 118.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("ffd45a"))
	$HUD.add_child(status_label)

	health_bar = ProgressBar.new()
	health_bar.name = "BrutusHealth"
	health_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	health_bar.offset_left = 220.0
	health_bar.offset_top = 12.0
	health_bar.offset_right = -220.0
	health_bar.offset_bottom = 38.0
	health_bar.show_percentage = false
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color(0.025, 0.045, 0.035, 0.92)
	health_background.corner_radius_top_left = 10
	health_background.corner_radius_top_right = 10
	health_background.corner_radius_bottom_left = 10
	health_background.corner_radius_bottom_right = 10
	var health_fill_style := StyleBoxFlat.new()
	health_fill_style.bg_color = Color("38cfff")
	health_fill_style.corner_radius_top_left = 10
	health_fill_style.corner_radius_top_right = 10
	health_fill_style.corner_radius_bottom_left = 10
	health_fill_style.corner_radius_bottom_right = 10
	health_bar.add_theme_stylebox_override("background", health_background)
	health_bar.add_theme_stylebox_override("fill", health_fill_style)
	$HUD.add_child(health_bar)

	health_text = Label.new()
	health_text.name = "BrutusHealthText"
	health_text.set_anchors_preset(Control.PRESET_TOP_WIDE)
	health_text.offset_left = 220.0
	health_text.offset_top = 13.0
	health_text.offset_right = -220.0
	health_text.offset_bottom = 37.0
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_text.add_theme_font_size_override("font_size", 13)
	health_text.add_theme_color_override("font_color", Color.WHITE)
	$HUD.add_child(health_text)

	_build_end_overlay()


func _build_end_overlay() -> void:
	end_overlay = ColorRect.new()
	end_overlay.name = "EndOverlay"
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.color = Color(0.015, 0.035, 0.025, 0.78)
	end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.visible = false
	$HUD.add_child(end_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -245.0
	panel.offset_top = -150.0
	panel.offset_right = 245.0
	panel.offset_bottom = 150.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.12, 0.08, 0.97)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.82, 0.64, 0.24, 0.85)
	panel_style.corner_radius_top_left = 24
	panel_style.corner_radius_top_right = 24
	panel_style.corner_radius_bottom_left = 24
	panel_style.corner_radius_bottom_right = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	end_overlay.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	panel.add_child(content)
	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 42)
	content.add_child(end_title)
	end_summary = Label.new()
	end_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_summary.add_theme_font_size_override("font_size", 18)
	end_summary.add_theme_color_override("font_color", Color("eaf4e7"))
	content.add_child(end_summary)
	var restart_button := Button.new()
	restart_button.text = "JOGAR NOVAMENTE"
	restart_button.custom_minimum_size = Vector2(0, 62)
	restart_button.add_theme_font_size_override("font_size", 20)
	restart_button.pressed.connect(_restart_match)
	content.add_child(restart_button)



func _update_match_label() -> void:
	if match_label == null:
		return
	var remaining := maxf(0.0, float(match_rules.match_duration) - match_time)
	var total_seconds := ceili(remaining)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	var enemy_health := 0
	var enemy_base_reference = team_bases.get(1)
	if is_instance_valid(enemy_base_reference):
		var enemy_base := enemy_base_reference as ArenaActor
		enemy_health = roundi(enemy_base.health)
	var blue_towers := _standing_towers(0)
	var red_towers := _standing_towers(1)
	match_label.text = "AZUL %dT  |  %02d:%02d  |  %dT VERMELHO  •  CORE %d  •  %s" % [
		blue_towers, minutes, seconds, red_towers, enemy_health,
		"DRAGÃO" if dragon_hatched else "OVO"]


func _standing_towers(team: int) -> int:
	var standing := 0
	for node in get_tree().get_nodes_in_group("arena_actors"):
		var actor := node as ArenaActor
		if actor != null and actor.team == team and actor.actor_kind == &"tower" \
				and not actor.is_defeated:
			standing += 1
	return standing
