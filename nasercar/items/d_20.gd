extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	collision_mask = 0
	collision_layer = 0
	$AnimatedSprite2D.modulate = Color.hex(0xffffff00)
	$CPUParticles2D.emitting = true
	$ParticleTimer.start()
	$RespawnTimer.start()
	$AudioStreamPlayer2D.play()
	if "itemblock" in body:
		body.itemblock.emit()

func _on_particle_timer_timeout() -> void:
	$CPUParticles2D.emitting = false


func _on_respawn_timer_timeout() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 1.0)
	await tween.finished
	collision_layer = 1
	collision_mask = 1
