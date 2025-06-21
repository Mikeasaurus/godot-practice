extends Area2D

var target: Node2D = null
var velocity: Vector2 = Vector2.ZERO
@export var acceleration: float = 1000.0
@export var dampen: float = 200.0
@export var max_speed: float = 2000.0
var active: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func set_target (car: Node2D) -> void:
	target = car
	$BuzzSound.play(1.0)
	# Wait a bit before becoming active
	# (so we don't hit the car that just launched us).
	await get_tree().create_timer(0.5).timeout
	active = true
	$AnimatedSprite2D.play()

# When no target available, just fly away.
func buzz_off () -> void:
	global_rotation = velocity.angle() - PI/2
	set_target($FlyAway)
	# Remove from scene after some fixed amount of time.
	await get_tree().create_timer(10.0).timeout
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target == null: return
	var direction: Vector2 = target.global_position - global_position
	global_rotation = direction.angle() - PI/2
	var new_velocity: Vector2 = velocity + delta*acceleration*direction.normalized() - delta*dampen*velocity.normalized()
	new_velocity = new_velocity.limit_length(max_speed)
	#TODO
	velocity = new_velocity
	global_position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if not active: return
	if "_crash_effect" in body:
		if "apply_impulse" in body:
			body.apply_impulse(0.5*velocity)
		if "apply_torque_impulse" in body:
			body.apply_torque_impulse(20000)
		body._crash_effect()
		active = false
		target = $FlyAway
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate", Color.hex(0xffffff00), 1.0)
		tween.parallel().tween_property($BuzzSound, "volume_db", -10, 1.0)
		await tween.finished
		queue_free()
