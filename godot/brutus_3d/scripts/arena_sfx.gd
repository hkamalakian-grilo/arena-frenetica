class_name ArenaSfx
extends Node

## Procedural sound effects. Every clip is synthesised once at startup into an
## AudioStreamWAV, so the game needs no audio files and stays offline-friendly.
## Play with `play(&"hit")`; other nodes can reach it through the "arena_sfx"
## group: get_tree().call_group("arena_sfx", "play", &"tower_shot").

const SAMPLE_RATE := 22050
const VOICES := 10

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var muted := false
var master_volume_db := -4.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "ArenaSfx"
	add_to_group("arena_sfx")
	rng.seed = 7
	_build_library()
	for _index in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		players.append(player)
	_ensure_mute_action()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		set_muted(not muted)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in players:
			player.stop()


func play(kind: StringName, volume_db := 0.0, pitch_variation := 0.06) -> void:
	if muted or not streams.has(kind):
		return
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stream = streams[kind]
	player.volume_db = master_volume_db + volume_db
	player.pitch_scale = 1.0 + rng.randf_range(-pitch_variation, pitch_variation)
	player.play()


func has_clip(kind: StringName) -> bool:
	return streams.has(kind)


func _build_library() -> void:
	streams[&"swing"] = _wav(_swing(0.14))
	streams[&"hit"] = _wav(_thump(0.16, 190.0, 55.0, 0.55))
	streams[&"q_charge"] = _wav(_rise(0.22, 120.0, 420.0))
	streams[&"q_impact"] = _wav(_thump(0.30, 140.0, 38.0, 0.85))
	streams[&"r_throw"] = _wav(_rise(0.32, 260.0, 900.0))
	streams[&"r_impact"] = _wav(_thump(0.26, 260.0, 60.0, 0.7))
	streams[&"r_catch"] = _wav(_clank(0.16))
	streams[&"hurt"] = _wav(_hurt(0.13))
	streams[&"kill"] = _wav(_arpeggio(0.42, [392.0, 523.25, 783.99]))
	streams[&"death"] = _wav(_arpeggio(0.6, [330.0, 262.0, 196.0]))
	streams[&"tower_shot"] = _wav(_blip(0.11, 760.0, 380.0))
	streams[&"tower_down"] = _wav(_thump(0.55, 110.0, 30.0, 1.0))
	streams[&"stun"] = _wav(_sparkle(0.24))
	streams[&"dragon"] = _wav(_roar(0.7))


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in range(samples.size()):
		var value := int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, value)
	stream.data = bytes
	return stream


func _length(seconds: float) -> int:
	return int(seconds * SAMPLE_RATE)


func _envelope(t: float, duration: float, attack := 0.004, curve := 2.2) -> float:
	if t < attack:
		return t / attack
	var release := clampf((t - attack) / maxf(duration - attack, 0.001), 0.0, 1.0)
	return pow(1.0 - release, curve)


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


## Basic attack whoosh: band-passed noise whose brightness falls with time.
func _swing(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var low := 0.0
	var band := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var cutoff := lerpf(0.55, 0.08, t / duration)
		var raw := _noise()
		low += (raw - low) * cutoff
		band += (low - band) * 0.35
		out[index] = (low - band) * 2.4 * _envelope(t, duration, 0.012, 1.6)
	return out


## Impact thump: pitch-dropping sine plus a short noise crack.
func _thump(duration: float, start_hz: float, end_hz: float, weight: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var phase := 0.0
	var low := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var progress := t / duration
		var hz := lerpf(start_hz, end_hz, pow(progress, 0.45))
		phase += TAU * hz / SAMPLE_RATE
		var body := sin(phase) * _envelope(t, duration, 0.003, 1.8)
		var raw := _noise()
		low += (raw - low) * 0.32
		var crack := low * _envelope(t, duration * 0.35, 0.002, 3.0) * 0.8
		out[index] = clampf((body * weight + crack) * 0.95, -1.0, 1.0)
	return out


## Rising sweep with tremolo: shield throw / charge wind-up.
func _rise(duration: float, start_hz: float, end_hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var phase := 0.0
	var low := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var progress := t / duration
		var hz := lerpf(start_hz, end_hz, progress * progress)
		phase += TAU * hz / SAMPLE_RATE
		var tremolo := 0.6 + 0.4 * sin(TAU * 28.0 * t)
		var raw := _noise()
		low += (raw - low) * lerpf(0.12, 0.5, progress)
		var tone := sin(phase) * 0.45 + low * 0.9
		out[index] = tone * tremolo * _envelope(t, duration, 0.02, 1.2)
	return out


## Metallic clank: two inharmonic partials with a fast decay.
func _clank(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var tone := sin(TAU * 920.0 * t) * 0.5 + sin(TAU * 1370.0 * t) * 0.35 \
			+ sin(TAU * 2210.0 * t) * 0.2
		out[index] = tone * _envelope(t, duration, 0.002, 3.2)
	return out


## Short buzzy drop when the player takes damage.
func _hurt(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var phase := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var hz := lerpf(240.0, 110.0, t / duration)
		phase += TAU * hz / SAMPLE_RATE
		var square := 1.0 if sin(phase) >= 0.0 else -1.0
		out[index] = (square * 0.35 + sin(phase) * 0.35) * _envelope(t, duration, 0.003, 1.5)
	return out


## Three-note stinger (kill or death) using soft triangle-ish tones.
func _arpeggio(duration: float, notes: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var per_note := duration / notes.size()
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var note_index := mini(int(t / per_note), notes.size() - 1)
		var local_t := t - note_index * per_note
		var hz: float = notes[note_index]
		var tone := sin(TAU * hz * t) * 0.6 + sin(TAU * hz * 2.0 * t) * 0.18
		var note_env := _envelope(local_t, per_note * 1.4, 0.006, 1.4)
		out[index] = tone * note_env * _envelope(t, duration, 0.004, 0.8)
	return out


## Tower projectile blip.
func _blip(duration: float, start_hz: float, end_hz: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var phase := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		phase += TAU * lerpf(start_hz, end_hz, t / duration) / SAMPLE_RATE
		out[index] = sin(phase) * 0.5 * _envelope(t, duration, 0.003, 2.0)
	return out


## Bright shimmer for stun application.
func _sparkle(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var tremolo := 0.5 + 0.5 * sin(TAU * 18.0 * t)
		var tone := sin(TAU * 1480.0 * t) * 0.32 + sin(TAU * 1975.0 * t) * 0.22
		out[index] = tone * tremolo * _envelope(t, duration, 0.004, 1.6)
	return out


## Dragon roar: low saw-like growl with vibrato and noise breath.
func _roar(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := _length(duration)
	out.resize(count)
	var phase := 0.0
	var low := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var hz := 72.0 + 18.0 * sin(TAU * 6.5 * t) + 30.0 * (t / duration)
		phase += TAU * hz / SAMPLE_RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var raw := _noise()
		low += (raw - low) * 0.18
		out[index] = (saw * 0.42 + low * 0.5) * _envelope(t, duration, 0.05, 1.1)
	return out


func _ensure_mute_action() -> void:
	if not InputMap.has_action("toggle_mute"):
		InputMap.add_action("toggle_mute", 0.15)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	if not InputMap.action_has_event("toggle_mute", event):
		InputMap.action_add_event("toggle_mute", event)
