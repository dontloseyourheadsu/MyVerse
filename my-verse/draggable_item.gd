extends RigidBody3D

var is_dragging = false
var drag_plane = Plane(Vector3.UP, 0)
var drag_offset = Vector3.ZERO

func _ready():
	input_ray_pickable = true
	add_to_group("draggable")

func _input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				freeze = true
				# Store offset from object center to click position
				var camera = get_viewport().get_camera_3d()
				var ray_origin = camera.project_ray_origin(event.position)
				var ray_direction = camera.project_ray_normal(event.position)
				drag_plane = Plane(Vector3.UP, global_position.y)
				var intersection = drag_plane.intersects_ray(ray_origin, ray_direction)
				if intersection:
					drag_offset = global_position - intersection
			else:
				is_dragging = false
				freeze = false

func _physics_process(_delta):
	if is_dragging:
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_direction = camera.project_ray_normal(mouse_pos)
		
		var intersection = drag_plane.intersects_ray(ray_origin, ray_direction)
		if intersection:
			# Move to intersection point + offset, keeping it controlled
			global_position = intersection + drag_offset
			# Reset velocities to prevent "flying away" on release
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
