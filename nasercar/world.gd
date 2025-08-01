extends Node2D
class_name World

# Player car
var player_car: Car = null

# Signal that gets emitted when the game is finished and the player wishes to exit.
signal quit (place: int)

## Number of laps for the track.
var laps: int = 1

# Current game state (for applied effects, etc.)

# Time of start of race.
var _start_time: float

# Indicates that people are already slimed right now, or at least that someone
# has possession of the slime item.
var _sliming: bool = false
# Indicates that someone already has possession of the meteor.
var _meteor: bool = false

# Keep track of player's place in the race.
var _place: int = 0
# This is set right at the end of the race (in case a kart passes another kart while
# the results are displayed).
# Otherwise, for instance, the Naomi kart unlock won't trigger if player gets subsequently passed
# by a CPU before the "Done" button is pressed.
var _final_place: int = -1
# This flag is set when the displayed place is being updated.
var _updating_place: bool = false
# Shortcut for updating results for the stats page.
var _places: Array[ResultLine] = []
var _finished_cars: Array[Car] = []

# Keep track of which cars are carrying which items.
var _current_items: Dictionary = {}

# Helper method - get all cars in this track.
# Omits other non-car entities that the cars may spawn as siblings.
func _cars () -> Array[Car]:
	var cars: Array[Car] = []
	for car in $Cars.get_children():
		if "CarType" in car:
			cars.append(car)
	return cars
# Helper method - get all cars in front of the specified car.
func _cars_in_front_of (car: Car) -> Array[Car]:
	var cars: Array[Car] = []
	for other_car in _cars():
		if other_car.progress() > car.progress():
			cars.append(other_car)
	return cars
# Helper method - get place of the specified car.
func _car_place (car: Car) -> int:
	return len(_cars_in_front_of(car)) + 1
# Helper method - get the car immediately in front of the specified car.
# Returns null if there are no cars in front.
func _car_in_front_of (car: Car) -> Car:
	var front: Car = null
	var front_progress: float = -1
	for other_car in _cars_in_front_of(car):
		if other_car.progress() < front_progress or front_progress < 0:
			front = other_car
			front_progress = other_car.progress()
	return front
# Helper method - get the car in first place.
func _first_place_car () -> Car:
	var progress: float = 0.0
	var car: Car
	for c in _cars():
		if c.progress() > progress:
			car = c
			progress = c.progress()
	return car
# Helper method - get number of cars behind the specified car.
func _num_cars_behind (car: Car) -> int:
	var num: int = 0
	for other_car in _cars():
		if other_car.progress() < car.progress():
			num += 1
	return num


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Prepare final stats screen with placeholder values.
	var result_scene: PackedScene = load("res://menus/result_line.tscn")
	var places_vbox: VBoxContainer = $CanvasLayer/Stats/CenterContainer/Places
	for car in _cars():
		var result_line: ResultLine = result_scene.instantiate()
		result_line.set_results(-1, null, "", -1, Color.hex(0x555555ff))
		places_vbox.add_child(result_line)
		_places.append(result_line)
		var hsep: HSeparator = HSeparator.new()
		hsep.add_theme_constant_override("separation",5)
		var stylebox: StyleBoxLine = StyleBoxLine.new()
		stylebox.color = Color.hex(0x777777ff)
		stylebox.thickness = 3
		hsep.add_theme_stylebox_override("separator", stylebox)
		places_vbox.add_child(hsep)
	# Set up a pause screen for single player games.
	if multiplayer.get_unique_id() == 1:
		MenuHandler.pause.connect(_pause_screen)
		MenuHandler.done_submenus.connect(_unpause_screen)
		$ScreenEffects/PauseMenu/MarginContainer/CenterContainer/VBoxContainer/QuitButton.pressed.connect(_leave_race)

	# Move the playable car to the front
	var c: Car = _cars()[0]
	if c != player_car and player_car != null:
		var gp: Vector2 = c.global_position
		c.global_position = player_car.global_position
		player_car.global_position = gp

	# Add the cars to the track.
	# (Let the cars know what path to follow, and whether they are CPU or player controlled).
	for car in _cars():
		car.add_to_track($TrackPath, [$Ground, $Road])
		car.itemblock.connect(func():
			_itemblock(car)
		)
		car.meteor_impact.connect(func():
			_big_badaboom(car)
		)
		car.lap_completed.connect(func(lap:int):
			_lap_completed(car,lap)
		)

	# Set up a car under player's control.
	if player_car == null:
		player_car = $Cars/NaserCar
	player_car.make_playable()

	for car in _cars():
		if car != player_car:
			car.make_cpu()

	# Start of race.
	$CanvasLayer/FadeIn.show()
	$CanvasLayer/Place.modulate = Color.hex(0xffffff00)
	var fadein: Tween = create_tween()
	fadein.tween_property($CanvasLayer/FadeIn, "modulate", Color.TRANSPARENT, 1.0)
	await fadein.finished
	$CanvasLayer/GoLabel.show()
	$CanvasLayer/GoLabel.text = "3"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "2"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "1"
	$Beep1.play()
	await get_tree().create_timer(1.0).timeout
	$CanvasLayer/GoLabel.text = "GO!!!"
	$Beep2.play()
	for car in _cars():
		car.go()
	_start_time = Time.get_ticks_msec() / 1000.
	var go: Tween = create_tween()
	go.tween_property($CanvasLayer/GoLabel,"modulate",Color.TRANSPARENT,1.0)
	go.parallel().tween_property($CanvasLayer/GoLabel,"scale",Vector2(2,2),1.0)
	go.parallel().tween_property($CanvasLayer/GoLabel,"position", Vector2($CanvasLayer/GoLabel.position.x*0.5,1),1.0)
	# Show place after the cars have starting racing a bit.
	await get_tree().create_timer(3.0).timeout
	var place_tween: Tween = create_tween()
	place_tween.set_ease(Tween.EASE_IN)
	place_tween.tween_property($CanvasLayer/Place, "modulate", Color.WHITE, 1.0)
	await place_tween.finished
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check place of the car, and update as necessary.
	_check_place (player_car)

func _check_place (car: Car) -> void:
	if _updating_place: return
	var current_place: int = _car_place(car)
	if current_place == _place: return
	_updating_place = true
	var dt: float = abs(current_place - _place) * 0.5
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($CanvasLayer/Place, "scroll_vertical", (current_place-1)*175, dt)
	await tween.finished
	_place = current_place
	_updating_place = false

# All available item types.
enum ItemType {NONE,NAILPOLISH,COFFEE,METEOR,SLIME,BEETLE}
# Map the item types to the visual representations.
@onready var item_pics: Dictionary = {
	ItemType.NAILPOLISH: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/NailPolish,
	ItemType.COFFEE: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Coffee,
	ItemType.METEOR: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Meteor,
	ItemType.SLIME: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/MangoSlime,
	ItemType.BEETLE: $ItemSelect/CenterContainer/ScrollContainer/VBoxContainer/Beetle,
}

func _itemblock (car: Car) -> void:
	if car not in _current_items:
		_get_item(car)
	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item"):
		_use_item(player_car)

func _pause_screen() -> void:
	if _leaving_race: return  # Don't pause if race is being terminated.
	get_tree().paused = true
	MenuHandler.activate_menu($ScreenEffects/PauseMenu)
func _unpause_screen() -> void:
	get_tree().paused = false

func _get_item(car: Car) -> void:
	# First, select an item.
	# Put stub entry for this car, to prevent getting another item while this
	# item is arriving.
	_current_items[car] = ItemType.NONE
	var cars_in_front: Array[Car] = _cars_in_front_of(car)
	# Determine which items are viable selections, and relative probability
	# of occurrence.
	var likelihood: Dictionary = {}
	# Probability of slime increases with number of cars in front.
	# But not available if someone else already has it / is using it.
	if not _sliming:
		if len(cars_in_front) > 0:
			likelihood[ItemType.SLIME] = len(cars_in_front)*5
	# Coffee also becomes more likely the further behind.
	if len(cars_in_front) >= 0:  # This condition can be used to turn off coffee if already in front.
		likelihood[ItemType.COFFEE] = 10 + len(cars_in_front)*15
	# Similarly, probability of meteor increases with number of cars in front.
	# But relatively less likely overall.
	if not _meteor:
		if len(cars_in_front) > 0:
			likelihood[ItemType.METEOR] = len(cars_in_front)
	# Probability of nail polish increases with number of cars behind.
	var num_cars_behind: int = _num_cars_behind(car)
	if num_cars_behind > 0:
		likelihood[ItemType.NAILPOLISH] = num_cars_behind*10
	# Beetle has equal probability, except for leading car.
	if len(cars_in_front) > 0:
		likelihood[ItemType.BEETLE] = 40
	# Pick an item from these possibilities.
	var sample_size: int = 0
	for n in likelihood.values():
		sample_size += n
	var choice: int = randi() % sample_size
	#print ('?? ', car, ' ', likelihood, ' ', sample_size)
	var item: ItemType
	for item_type in likelihood.keys():
		if choice < likelihood[item_type]:
			item = item_type
			break
		choice -= likelihood[item_type]
	# An item should now be selected.
	#print (car, ' got ', item_pics[item])

	# Some item types are exclusive (only one available at a time).
	if item == ItemType.METEOR:
		_meteor = true
	if item == ItemType.SLIME:
		_sliming = true

	# If this is player, then spin to this item.
	if car.type == car.CarType.PLAYER:
		# Move item picture to the last entry.
		$ItemSelect/CenterContainer/ScrollContainer/VBoxContainer.move_child(item_pics[item],-1)
		$ItemSelect.show()
		$ItemSelect/CenterContainer/ScrollContainer.scroll_vertical = 0
		$ItemSelect/D20Sound.play()
		var tween: Tween = create_tween()
		tween.tween_interval(0.4)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property($ItemSelect/CenterContainer/ScrollContainer,"scroll_vertical",5*256+20,0.75)
		await tween.finished
	else:
		await get_tree().create_timer(2.0).timeout
	_current_items[car] = item
	# CPUs use items automatically after some random amount of time.
	if car.type == car.CarType.CPU:
		await get_tree().create_timer(randf()*5).timeout
		_use_item(car)
	# Players with touchscreen automatically use items after a short amount of time.
	if car.type == car.CarType.PLAYER and DisplayServer.is_touchscreen_available():
		await get_tree().create_timer(1.0).timeout
		_use_item(car)

func _use_item(car: Car) -> void:
	if car not in _current_items: return
	#print (car, ' used ', item_pics[_current_items[car]])
	var item: ItemType = _current_items.get(car)
	if item == ItemType.NONE: return  # Item not available yet.
	_current_items.erase(car)
	if car.type == car.CarType.PLAYER:
		# Play item activation sound.
		# Skipped for certain items which have their own distinct sound.
		if item not in [ItemType.NAILPOLISH, ItemType.COFFEE]:
			$ItemSelect/WhooshSound.play()
		var tween: Tween = create_tween()
		tween.tween_property($ItemSelect/CenterContainer,"scale",Vector2(1.0,1.0),0.2)
		tween.parallel().tween_property($ItemSelect/CenterContainer,"modulate",Color.hex(0xffffff00),0.2)
		await tween.finished
		$ItemSelect.hide()
		$ItemSelect/CenterContainer.scale = Vector2(0.5,0.5)
		$ItemSelect/CenterContainer.modulate = Color.WHITE
	if item == ItemType.SLIME:
		for c in _cars_in_front_of(car):
			c.get_slimed(0.7+0.4, 4.0, 2.0)
			if c.type == c.CarType.PLAYER:
				_slime_screen()
		# Allow slime item to be obtained again after slime has faded.
		await get_tree().create_timer(7.1).timeout
		_sliming = false
	if item == ItemType.BEETLE:
		# Target the car in front.
		var target: Car = _car_in_front_of(car)
		_launch_beetle(car, target)
	if item == ItemType.NAILPOLISH:
		_release_nailpolish(car)
	if item == ItemType.COFFEE:
		car.sip_coffee()
	if item == ItemType.METEOR:
		_launch_meteor(car)

func _slime_screen() -> void:
	$ScreenEffects/MangoSlime.show()
	var mango: AnimatedSprite2D = $ScreenEffects/MangoSlime/Mango
	mango.offset.y = 0
	mango.scale.y = 9
	var mangotween: Tween = create_tween()
	mangotween.set_ease(Tween.EASE_IN)
	mangotween.tween_property(mango, "offset", Vector2(0,-108), 0.5)
	mangotween.tween_interval(0.2)
	#tween.tween_property(mango, "scale", Vector2(9,10), 0.0)
	mangotween.tween_interval(0.4)
	#tween.tween_property(mango, "scale", Vector2(9,9), 0.0)
	mangotween.tween_interval(0.2)
	mangotween.set_ease(Tween.EASE_OUT)
	mangotween.tween_property(mango, "offset", Vector2(0,0), 0.3)
	await get_tree().create_timer(0.7).timeout
	mango.animation = "mouth_open"
	$ScreenEffects/MangoSlime/CPUParticles2D.emitting = true
	$ScreenEffects/MangoSlime/HorkSound.play()
	await get_tree().create_timer(0.4).timeout
	$ScreenEffects/MangoSlime/SplatSound.play()
	var slime: AnimatedSprite2D = $ScreenEffects/MangoSlime/Slime
	slime.show()
	slime.play()
	mango.animation = "default"
	#await mangotween.finished
	#slime.hide()
	var slimedrip: Tween = create_tween()
	slimedrip.set_ease(Tween.EASE_OUT)
	var slimefade: Tween = create_tween()
	slimefade.set_ease(Tween.EASE_OUT)
	slimedrip.tween_property(slime, "scale", Vector2(10,50), 6.0)
	slimefade.tween_interval(4.0)
	slimefade.tween_property(slime, "modulate", Color.hex(0xffffff00), 2.0)
	await slimefade.finished
	if slimedrip.is_running():
		await slimedrip.finished
	slime.hide()
	slime.scale.y = 10
	slime.modulate = Color.WHITE
	$ScreenEffects/MangoSlime.hide()

func _launch_beetle (from: Car, to: Car) -> void:
	var beetle = load("res://items/beetle.tscn").instantiate()
	add_child(beetle)
	beetle.z_index = 10
	beetle.global_position = from.global_position
	beetle.velocity = from.linear_velocity
	if to != null:	
		beetle.set_target(to)
	else:
		beetle.buzz_off()

func _launch_meteor (from: Car) -> void:
	var target: Car = _first_place_car()
	# If player managed to get into first place, then don't launch the meteor at
	# themselves!
	if target == from: return
	target.space_rock()

func _release_nailpolish (from: Car) -> void:
	var nailpolish = load("res://items/nail_polish.tscn").instantiate()
	add_child(nailpolish)
	nailpolish.global_position = from.global_position
	nailpolish.z_index = 0  # Under item blocks and things.

func _big_badaboom (car: Car) -> void:
	# Flash of light
	var boom: Node2D = load("res://effects/impact.tscn").instantiate()
	add_child(boom)
	boom.global_position = car.global_position
	boom.z_index = 3
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(boom,"scale",Vector2(3,3),0.5)
	tween.tween_interval(1.0)
	tween.tween_property(boom,"modulate",Color.hex(0xffffff00),5.0)
	tween.parallel().tween_property(boom,"scale",Vector2(9,9),5.0)
	# Smoulder effect (and impedence) on all cars within the blast radius.
	for c in $Cars.get_children():
		if "smoulder" in c and (c.global_position-boom.global_position).length() <= 500:
			c.smoulder()
	# Smoking crater.
	var crater: Node2D = load("res://effects/crater.tscn").instantiate()
	add_child(crater)
	crater.global_position = car.global_position
	crater.z_index = 2
	crater.get_node("CPUParticles2D").emitting = true
	await tween.finished
	_meteor = false
	boom.queue_free()
	await get_tree().create_timer(10.0).timeout
	crater.queue_free()

# Called when a car has just completed a lap.
func _lap_completed (car: Car, lap: int) -> void:
	if lap < laps:
		if car.type == car.CarType.PLAYER:
			_lap_announce(lap+1)
	elif lap == laps:
		_finished(car)
# Announce the player's new lap on the screen.
func _lap_announce (lap: int):
	var t: Label = $CanvasLayer/LapFinished
	t.text = "Lap %d"%lap
	t.global_position = Vector2(-t.size.x*t.scale.x,0)
	t.show()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(t,"global_position", Vector2(960-t.size.x*t.scale.x/2,0),0.5)
	tween.tween_interval(0.5)
	tween.tween_property(t,"global_position", Vector2(1920,0),0.5)
	await tween.finished
	t.hide()
# End of the race (player crossed finish line).
func _finished (car: Car) -> void:
	# Add this car to the displayed stats.
	var time: float = Time.get_ticks_msec()/1000. - _start_time
	# First append this car to an array, then apply all the array elements to
	# the stats page.
	# This avoids a race condition when two cars finish at the same time and are both trying to
	# update their stats.
	_finished_cars.append(car)
	for i in range(len(_finished_cars)):
		if _finished_cars[i] == car:
			var place: int = i+1
			if car == player_car:
				_places[i].set_results(place, car, "Player", time, Color.GREEN)
				_final_place = place
			else:
				_places[i].set_results(place, car, car.display_name+" (CPU)", time, Color.WHITE)
				return
	# Rest of this is for the player's screen.
	# CPU takes control of car after race, so cars are still moving in the background
	# while the player reads the final results.
	car.autopilot()
	$CanvasLayer/Place.hide()
	var t: Label = $CanvasLayer/LapFinished
	t.text = "FINISHED"
	t.global_position = Vector2(-t.size.x*t.scale.x,0)
	t.show()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(t,"global_position", Vector2(960-t.size.x*t.scale.x/2,0),0.5)
	tween.tween_interval(0.5)
	$CanvasLayer/Stats.modulate = Color.hex(0xffffff00)
	$CanvasLayer/Stats.show()
	tween.tween_property($CanvasLayer/Stats,"modulate",Color.WHITE,0.5)
	$CanvasLayer/DoneButton.modulate = Color.hex(0xffffff00)
	$CanvasLayer/DoneButton.show()
	$CanvasLayer/DoneButton.disabled = true
	tween.parallel().tween_property($CanvasLayer/DoneButton,"modulate",Color.WHITE,0.5)
	await tween.finished
	$CanvasLayer/DoneButton.disabled = false

func _on_done_button_pressed() -> void:
	$CanvasLayer/DoneButton.disabled = true
	_leave_race(true)
var _leaving_race: bool = false
func _leave_race(completed: bool = false) -> void:
	# Check if already leaving race.
	if _leaving_race: return
	_leaving_race = true
	# Make sure we're unpaused.
	MenuHandler.deactivate_menu()
	var tween: Tween = create_tween()
	tween.tween_property(self,"modulate",Color.BLACK,1.0)
	# Why do I need to modulate stats if I'm already modulating the whole scene???
	tween.parallel().tween_property($CanvasLayer/Stats,"modulate",Color.BLACK,1.0)
	tween.parallel().tween_property($CanvasLayer/LapFinished,"modulate",Color.BLACK,1.0)
	await tween.finished
	_leaving_race = false
	if completed:
		quit.emit(_final_place)
	else:
		quit.emit(-1)
