extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var rotation_speed = 10.0
@export var mouse_sensitivity = 0.005

@export var min_pitch = -0.5
@export var max_pitch = 0.8

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var picked_item: Node3D = null

var is_rotating_camera = false
var camera_pitch = 0.0

var mobile_input_dir = Vector2.ZERO

@onready var visuals = $Visuals
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
@onready var interaction_ray = $Visuals/InteractionRay
@onready var camera_pivot = $CameraPivot
@onready var anim_player = $Visuals/Barbarian/AnimationPlayer

func _ready():
	add_to_group("player")
	# Detach camera pivot from rigid movement
	camera_pivot.top_level = true
	# Ensure the walking animation loops
	if anim_player.has_animation("Walking_A"):
		anim_player.get_animation("Walking_A").loop_mode = Animation.LOOP_LINEAR

func _input(event):
	# Mouse-only camera rotation (Right Click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_rotating_camera = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				is_rotating_camera = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and is_rotating_camera:
		rotate_camera(event.relative)

func rotate_camera(relative: Vector2):
	camera_pivot.rotate_y(-relative.x * mouse_sensitivity)
	camera_pitch -= relative.y * mouse_sensitivity
	camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
	camera_pivot.rotation.x = camera_pitch

func _physics_process(delta):
	# Smoothly follow player with camera pivot
	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position + Vector3.UP * 1.5, 10.0 * delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		state_machine.travel("Jump_Full_Short")

	# Interact
	if Input.is_action_just_pressed("interact"):
		if picked_item:
			drop_item()
		else:
			try_pick_item()

	# Movement
	var input_dir = mobile_input_dir
	if input_dir == Vector2.ZERO:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
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
