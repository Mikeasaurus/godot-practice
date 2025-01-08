extends Node2D

signal ate_bug

# Array to hold individual worm segments.
var segments: Array[WormSegment] = []

@export var worm_segment_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Organize the segments into an ordered array.
	# Note: When I tried to set this from within the declaration of "segments", the
	# elements were all null.  Have to wait until runtime for these references to exist?
	segments.append_array([$WormTail, $WormSegment1, $WormSegment2, $WormSegment3, $WormFront])

func _input(_event: InputEvent) -> void:
	# Check if we need to shoot some slime.
	if Input.is_action_just_pressed("shoot_slime"):
		# Tell head segment to shoot some slime.
		segments[-1].shoot_slime()
	# Debug action... grow the worm on command.
	if Input.is_action_just_pressed("grow"):
		# Add a new segment, just behind the front segment.
		var segment: WormSegment = worm_segment_scene.instantiate()
		add_child(segment)
		segment.global_position = (segments[-2].global_position + segments[-1].global_position) / 2
		segments.insert(-2,segment)

# Called every frame. 'delta' is the elapsed time since the previous frame.
# NOTE: Disabled - z-order seems to be stable now, no need for adjustment.
func __process(_delta: float) -> void:
	# Adjust z-order of worm segments if they all exceed a certain value
	var minz: int = segments[0].z_index
	if minz > 0:
		for segment in segments:
			segment.z_index -= minz
	
# Pass along signal when a bug is eaten.
func _on_worm_front_ate_bug() -> void:
	ate_bug.emit()
