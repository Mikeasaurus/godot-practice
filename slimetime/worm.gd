extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$WormTail.set_front_segment($WormSegment1)
	$WormSegment1.set_front_segment($WormSegment2)
	$WormSegment2.set_front_segment($WormSegment3)
	$WormSegment3.set_front_segment($WormFront)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
