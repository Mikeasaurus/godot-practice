extends Area2D

signal gameover
@export var big_boom_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	gameover.emit()
	var boom = big_boom_scene.instantiate()
	boom.position = body.position
	add_sibling(boom)
