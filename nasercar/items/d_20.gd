extends Area2D

# Item blocks.

# Note: Using RPC calls instead of a MultiplayerSynchronizer for the item state, because
# the synchronizer doesn't seem to work properly from the TileMapLayer where these
# items are stored.
# Keep a list of peers to send the RPC calls to.
var peers: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	collision_mask = 0
	collision_layer = 0
	$ParticleTimer.start()
	$RespawnTimer.start()
	$ReactivateTimer.start()
	if "itemblock" in body:
		body.itemblock.emit()
	for peer in peers:
		_item_taken_visual.rpc_id(peer)
@rpc("authority","reliable","call_local")
func _item_taken_visual() -> void:
	$AnimatedSprite2D.modulate = Color.hex(0xffffff00)
	$CPUParticles2D.emitting = true
	$AudioStreamPlayer2D.play()

func _on_particle_timer_timeout() -> void:
	for peer in peers:
		_item_particle_stop.rpc_id(peer)
@rpc("authority","reliable","call_local")
func _item_particle_stop() -> void:
	$CPUParticles2D.emitting = false

func _on_respawn_timer_timeout() -> void:
	for peer in peers:
		_item_reappear.rpc_id(peer)
@rpc("authority","reliable","call_local")
func _item_reappear() -> void:
	var tween: Tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 1.0)
	await tween.finished

func _on_reactivate_timer_timeout() -> void:
	collision_layer = 1
	collision_mask = 1
