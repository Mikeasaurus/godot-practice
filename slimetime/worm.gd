extends Node2D

# Helper method - pair segments together.
func pair(seg1,seg2) -> void:
	seg1.set_front_segment(seg2)
	seg2.set_back_segment(seg1)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pair ($WormTail,$WormSegment1)
	pair ($WormSegment1,$WormSegment2)
	pair ($WormSegment2,$WormSegment3)
	pair ($WormSegment3,$WormFront)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
