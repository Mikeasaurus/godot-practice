extends Node2D

# Renders a slime splatter effect on the screen.
class_name Splatter

@export var particle_scene: PackedScene

var direction: Vector2
var sound: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(10):
		var p: Node2D = particle_scene.instantiate()
		var angle: float = (randf() - 0.5) * PI
		var speed: float = 100 + randf() * 200
		p.position = position
		p.linear_velocity = direction.rotated(angle) * speed
		p.z_index = z_index
		# Have to do a deferred call for adding the particles, otherwise get the error message:
		# ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.
		call_deferred("add_sibling",p)
	# Play a sound.
	if sound:
		$SplatSound.play()
static func create (pos: Vector2, dir: Vector2) -> Splatter:
	var splatter: Splatter = load("res://features/splatter.tscn").instantiate()
	splatter.global_position = pos
	splatter.direction = dir
	return splatter
	
func _on_splat_sound_finished() -> void:
	# Only clean up from server or single player.
	# Remote clients will have the scene managed by a MultiplayerSpawner.
	if multiplayer.get_unique_id() == 1:
		queue_free()
