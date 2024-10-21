extends Node

@export var note_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		#print ($Note.position, event.position)
		# Spawn a new note.
		var note = note_scene.instantiate()
		# Start at the reference location.
		note.position = $NoteLaunch.position
		# Note will aim in the direction where the mouse was clicked.
		var velocity = event.position - $NoteLaunch.position
		if velocity.x != 0 or velocity.y != 0:
			velocity = velocity.normalized()
			velocity *= 1000
		note.linear_velocity = velocity
		add_child(note)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
