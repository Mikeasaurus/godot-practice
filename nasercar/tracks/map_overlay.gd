extends Node2D

@export var track: Track

func _ready() -> void:
	#TODO
	if track == null:
		track = load("res://tracks/snowy.tscn").instantiate()
	# Overhead map test
	var points: Array[Vector2] = []
	var xmin : float
	var xmax : float
	var ymin : float
	var ymax : float
	var curve: Curve2D = track.get_node("TrackPath").curve
	for i in range(curve.point_count):
		var point: Vector2 = curve.get_point_position(i)
		points.append(point)
		xmin = min(xmin,point.x)
		xmax = max(xmax,point.x)
		ymin = min(ymin,point.y)
		ymax = max(ymax,point.y)
	points.append(points[0])
	#var offset: Vector2 = Vector2(xmin,ymin)
	var scale: float = min(1920/(xmax-xmin),1080/(ymax-ymin)) * 0.25
	var offset: Vector2 = Vector2(xmax - 1890/scale, ymin - 30/scale)
	# Define 2 lines - inner and outer with different widths and colours - for doing an outline effect.
	var line1: Line2D = Line2D.new()
	var line2: Line2D = Line2D.new()
	for point in points:
		# want (xmax+offset.x)*scale = 1920
		# -> xmax+offset.x = 1920/scale
		# -> offset.x = 1920/scale - xmax
		line1.add_point((point-offset)*scale)
		line2.add_point((point-offset)*scale)
	#line1.antialiased = true
	line1.width = 25.0
	line1.default_color = Color.BLACK
	line1.joint_mode = Line2D.LINE_JOINT_ROUND
	#line2.antialiased = true
	line2.width = 10.0
	line2.default_color = Color.WHITE
	line2.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line1)
	add_child(line2)
	line2.antialiased = true
