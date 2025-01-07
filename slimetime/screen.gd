extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_worm_ate_bug() -> void:
	Globals.score += 100
	$Overlay/Score.text = "Score:\n %d"%Globals.score
