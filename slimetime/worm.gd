extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	$WormSegment1.set_front_segment($WormSegment2)
	#$WormSegment2.set_back_segment($WormSegment1)
	$WormSegment2.set_front_segment($WormSegment3)
	#$WormSegment3.set_back_segment($WormSegment2)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
