extends Node2D

# Helper method - pair segments together.
func pair(seg1,seg2) -> void:
	seg1.set_front_segment(seg2)
	seg2.set_back_segment(seg1)

var segments: Array[RigidBody2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	segments.append_array([$WormTail, $WormSegment1, $WormSegment2, $WormSegment3, $WormFront])
	for i in range(len(segments)-1):
		pair (segments[i],segments[i+1])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Adjust z-order of worm segments if they all exceed a certain value
	var minz: int = segments[0].z_index
	if minz > 0:
		for segment in segments:
			segment.z_index -= minz
	
