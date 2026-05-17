extends Control

var player: CharacterBody3D

# Left side: Movement Joystick
var move_touch_index = -1
var move_start_pos = Vector2.ZERO
var move_current_pos = Vector2.ZERO

# Right side: Camera / Actions
var look_touch_index = -1
var look_start_pos = Vector2.ZERO
var look_last_pos = Vector2.ZERO
var look_start_time = 0.0
var look_is_dragging = false

@export var joystick_deadzone = 10.0
@export var joystick_max_distance = 100.0
@export var tap_threshold_time = 0.2
@export var tap_threshold_dist = 10.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	# Lazy fetch player to ensure it's ready
	if not player:
		player = get_tree().get_first_node_in_group("player")

func _unhandled_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_down(event.index, event.position)
		else:
			_handle_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event.index, event.position, event.relative)

func _handle_touch_down(index: int, pos: Vector2):
	var screen_width = get_viewport_rect().size.x
	
	if pos.x < screen_width / 2.0:
		# Left side: Movement
		if move_touch_index == -1:
			move_touch_index = index
			move_start_pos = pos
			move_current_pos = pos
	else:
		# Right side: Camera / Actions
		if look_touch_index == -1:
			look_touch_index = index
			look_start_pos = pos
			look_last_pos = pos
			look_start_time = Time.get_ticks_msec() / 1000.0
			look_is_dragging = false

func _handle_touch_up(index: int, pos: Vector2):
	if index == move_touch_index:
		move_touch_index = -1
		if player:
			player.mobile_input_dir = Vector2.ZERO
			
	elif index == look_touch_index:
		var end_time = Time.get_ticks_msec() / 1000.0
		var dist = pos.distance_to(look_start_pos)
		
		# If it was a quick tap without much movement, perform action
		if not look_is_dragging and (end_time - look_start_time < tap_threshold_time) and (dist < tap_threshold_dist):
			_perform_right_side_action(pos)
			
		look_touch_index = -1
		look_is_dragging = false

func _handle_touch_drag(index: int, pos: Vector2, relative: Vector2):
	if index == move_touch_index:
		move_current_pos = pos
		_update_movement()
	elif index == look_touch_index:
		look_last_pos = pos
		if pos.distance_to(look_start_pos) > tap_threshold_dist:
			look_is_dragging = true
			if player:
				# Use relative movement for camera rotation
				player.rotate_camera(relative)

func _update_movement():
	var diff = move_current_pos - move_start_pos
	if diff.length() > joystick_deadzone:
		var input_vec = diff.normalized() * min(diff.length() / joystick_max_distance, 1.0)
		if player:
			# Y is inverted in screen space vs movement space
			player.mobile_input_dir = Vector2(input_vec.x, input_vec.y)
	else:
		if player:
			player.mobile_input_dir = Vector2.ZERO

func _perform_right_side_action(pos: Vector2):
	var screen_height = get_viewport_rect().size.y
	if pos.y < screen_height / 2.0:
		# Top Right: Interact
		Input.action_press("interact")
		get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release("interact"))
	else:
		# Bottom Right: Jump
		Input.action_press("jump")
		get_tree().create_timer(0.1).timeout.connect(func(): Input.action_release("jump"))
