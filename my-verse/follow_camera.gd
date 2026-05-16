extends Camera3D

@export var target_path: NodePath
@export var offset = Vector3(0, 10, 10)
@export var smooth_speed = 5.0

var target: Node3D

func _ready():
	if target_path:
		target = get_node(target_path)

func _physics_process(delta):
	if target:
		var target_pos = target.global_position + offset
		global_position = global_position.lerp(target_pos, smooth_speed * delta)
		look_at(target.global_position)
