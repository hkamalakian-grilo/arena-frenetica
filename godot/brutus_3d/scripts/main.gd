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
var match_label: Label
var status_label: Label
var match_time := 0.0
var wave_timer := 0.0
var match_over := false
var team_bases: Dictionary = {}
var hero_bots: Array[HeroBot] = []
var arena_map: TravessiaMap
var match_rules := TravessiaDefinition.match_rules()
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
		match_time += delta
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = float(match_rules.wave_interval)
			_spawn_wave()
	_update_match_label()


func _exit_tree() -> void:
	# Avoid leaking the match pace into editor previews or another scene.
	if is_equal_approx(Engine.time_scale, float(match_rules.get("game_speed", 1.0))):
		Engine.time_scale = 1.0

func _update_ability_button(button: Button, ready_text: String, cooldown: float) -> void:
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
		_spawn_structure(structure.kind, structure.team, structure.position,
			structure.health, structure.color)
	for objective in TravessiaDefinition.neutral_objectives():
		_spawn_actor(objective, objective.position)
	_spawn_hero_bots()
	_refresh_base_protection()
	wave_timer = 0.0


func _spawn_hero_bots() -> void:
	for data in TravessiaDefinition.hero_bots():
		var bot := HeroBot.new()
		bot.position = data.position
		add_child(bot)
		bot.configure(data)
		hero_bots.append(bot)


func _spawn_structure(kind: StringName, team: int, at_position: Vector3,
		health: float, color: Color) -> ArenaActor:
	var damage := 92.0 if kind == &"tower" else 0.0
	var attack_range := 4.5 if kind == &"tower" else 0.0
	var actor := _spawn_actor({
		"kind": kind,
		"team": team,
		"health": health,
		"attack_damage": damage,
		"attack_range": attack_range,
		"attack_interval": 1.20,
		"color": color,
	}, at_position)
	if kind == &"base":
		team_bases[team] = actor
	return actor


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
		_spawn_minion(0, lane_x)
		_spawn_minion(1, lane_x)


func _spawn_minion(team: int, lane_x: float) -> void:
	var data := TravessiaDefinition.minion(team, lane_x)
	_spawn_actor(data, data.position)


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
			target.call("take_damage", damage)


func _on_actor_defeated(actor: ArenaActor) -> void:
	if actor.actor_kind == &"tower":
		_refresh_base_protection()
		status_label.text = "TORRE INIMIGA DESTRUIDA!" if actor.team == 1 else "TORRE ALIADA DESTRUIDA!"
		_get_tree_timer_clear_status()
	elif actor.actor_kind == &"dragon":
		status_label.text = "DRAGAO DERROTADO — EQUIPE FORTALECIDA"
		brutus.health = minf(brutus.max_health, brutus.health + 420.0)
		brutus.health_changed.emit(brutus.health, brutus.max_health)
		_get_tree_timer_clear_status()
	elif actor.actor_kind == &"base":
		match_over = true
		status_label.text = "VITORIA!" if actor.team == 1 else "DERROTA"
		status_label.modulate = Color("ffd45a") if actor.team == 1 else Color("ff6477")


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
			# Travessia uses any-tower gating: the base opens after the first
			# defensive tower falls, matching the established HTML rules.
			team_base.set_protected(standing_towers >= 2)


func _on_brutus_health_changed(current: float, maximum: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maximum
	health_bar.value = current
	health_bar.tooltip_text = "Brutus: %d / %d" % [roundi(current), roundi(maximum)]


func _on_brutus_defeated() -> void:
	status_label.text = "BRUTUS CAIU — RETORNO EM 3 s"
	attack_button.disabled = true
	q_button.disabled = true
	r_button.disabled = true
	await get_tree().create_timer(float(match_rules.respawn_time)).timeout
	if match_over:
		return
	brutus.revive(TravessiaDefinition.PLAYER_SPAWN)
	attack_button.disabled = false
	status_label.text = "BRUTUS RETORNOU"
	_get_tree_timer_clear_status()


func _get_tree_timer_clear_status() -> void:
	_clear_status_later()


func _clear_status_later() -> void:
	await get_tree().create_timer(2.2).timeout
	if not match_over:
		status_label.text = ""


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
	match_label.offset_top = 50.0
	match_label.offset_bottom = 78.0
	match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_label.add_theme_font_size_override("font_size", 16)
	match_label.add_theme_color_override("font_color", Color("eef6e9"))
	$HUD.add_child(match_label)

	status_label = Label.new()
	status_label.name = "Announcement"
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.offset_left = -260.0
	status_label.offset_top = 82.0
	status_label.offset_right = 260.0
	status_label.offset_bottom = 118.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("ffd45a"))
	$HUD.add_child(status_label)

	health_bar = ProgressBar.new()
	health_bar.name = "BrutusHealth"
	health_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	health_bar.offset_left = 250.0
	health_bar.offset_top = 18.0
	health_bar.offset_right = -250.0
	health_bar.offset_bottom = 38.0
	health_bar.show_percentage = false
	health_bar.add_theme_color_override("font_color", Color.WHITE)
	$HUD.add_child(health_bar)



func _update_match_label() -> void:
	if match_label == null:
		return
	var minutes := floori(match_time / 60.0)
	var seconds := floori(match_time) % 60
	var enemy_health := 0
	var enemy_base_reference = team_bases.get(1)
	if is_instance_valid(enemy_base_reference):
		var enemy_base := enemy_base_reference as ArenaActor
		enemy_health = roundi(enemy_base.health)
	match_label.text = "%02d:%02d   |   NUCLEO %d" % [minutes, seconds, enemy_health]
