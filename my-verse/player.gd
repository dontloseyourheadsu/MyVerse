extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var rotation_speed = 10.0
@export var mouse_sensitivity = 0.005

@export var min_pitch = -0.5
@export var max_pitch = 0.8

@export var drag_float_height = 1.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_dragging = false
var drag_plane = Plane(Vector3.UP, 0)
var picked_item: Node3D = null

var is_rotating_camera = false
var camera_pitch = 0.0

@onready var visuals = $Visuals
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var interaction_ray = $Visuals/InteractionRay
@onready var camera_pivot = $CameraPivot
@onready var anim_player = $Visuals/Barbarian/AnimationPlayer

func _ready():
	add_to_group("player")
	input_ray_pickable = true
	# Ensure the walking animation loops
	if anim_player.has_animation("Walking_A"):
		anim_player.get_animation("Walking_A").loop_mode = Animation.LOOP_LINEAR

func _input(event):
	if event is InputEventMouseButton:
		# Grabbing with either Left Click or Right Click (if clicking character)
		if event.pressed:
			var is_lmb = event.button_index == MOUSE_BUTTON_LEFT
			var is_rmb = event.button_index == MOUSE_BUTTON_RIGHT
			
			if is_lmb or is_rmb:
				var camera = get_viewport().get_camera_3d()
				if camera:
					var from = camera.project_ray_origin(event.position)
					var to = from + camera.project_ray_normal(event.position) * 1000
					var space_state = get_world_3d().direct_space_state
					var query = PhysicsRayQueryParameters3D.create(from, to)
					var result = space_state.intersect_ray(query)
					
					# Check if we clicked the player or furniture
					if result and (result.collider == self or result.collider.is_in_group("player")):
						is_dragging = true
						drag_plane = Plane(Vector3.UP, 0)
						return # Stop processing to avoid starting camera rotation if it was RMB
				
			# If we didn't grab the player and it's a right click, rotate camera
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_rotating_camera = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				
		else:
			# Release
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_dragging = false
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				is_dragging = false
				is_rotating_camera = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and is_rotating_camera:
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
		camera_pivot.rotation.x = camera_pitch

	if event.is_action_pressed("interact"):
		if picked_item:
			drop_item()
		else:
			try_pick_item()

func _physics_process(delta):
	if is_dragging:
		drag_logic()
		state_machine.travel("Idle")
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		state_machine.travel("Jump_Full_Short")

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam = get_viewport().get_camera_3d()
	
	if cam:
		var cam_basis = cam.global_transform.basis
		var forward = Vector3(-cam_basis.z.x, 0, -cam_basis.z.z).normalized()
		var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
		
		var direction = (forward * -input_dir.y + right * input_dir.x).normalized()
		
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			var target_rotation = atan2(direction.x, direction.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, rotation_speed * delta)
			
			if is_on_floor():
				state_machine.travel("Walking_A")
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			
			if is_on_floor() and state_machine.get_current_node() != "Jump_Full_Short":
				state_machine.travel("Idle")

	move_and_slide()
	
	if picked_item:
		picked_item.global_position = global_position + visuals.transform.basis.z * 1.5 + Vector3.UP * 0.5

func drag_logic():
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var intersection = drag_plane.intersects_ray(ray_origin, ray_direction)
	if intersection:
		global_position = intersection + Vector3.UP * drag_float_height
		velocity = Vector3.ZERO

func try_pick_item():
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider.is_in_group("draggable"):
			picked_item = collider
			if picked_item is RigidBody3D:
				picked_item.freeze = true

func drop_item():
	if picked_item:
		if picked_item is RigidBody3D:
			picked_item.freeze = false
		picked_item = null
