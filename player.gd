extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -660.0
@export var gravity: float = 1600.0
@export var fall_gravity_multiplier: float = 1.55

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export var wall_slide_speed: float = 260.0
@export var wall_jump_horizontal: float = 380.0
@export var wall_jump_vertical: float = -540.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_wall_sliding: bool = false
var last_wall_dir: int = 0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_left_top: RayCast2D = $RayLeftTop
@onready var ray_left_mid: RayCast2D = $RayLeftMid
@onready var ray_left_bottom: RayCast2D = $RayLeftBottom
@onready var ray_right_top: RayCast2D = $RayRightTop
@onready var ray_right_mid: RayCast2D = $RayRightMid
@onready var ray_right_bottom: RayCast2D = $RayRightBottom

func _physics_process(delta):
	if not is_on_floor():
		var grav = gravity
		if velocity.y > 0:
			grav *= fall_gravity_multiplier
		velocity.y += grav * delta

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	jump_buffer_timer -= delta

	var direction = Input.get_axis("ui_left", "ui_right")

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		jump_buffer_timer = jump_buffer_time

	# Обычный прыжок
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	# Переменная высота
	if (Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")) and velocity.y < 0:
		velocity.y *= 0.4

	# Стены
	var on_wall_left = is_valid_wall_left()
	var on_wall_right = is_valid_wall_right()

	is_wall_sliding = false

	if not is_on_floor() and velocity.y > 0:
		if on_wall_left:
			is_wall_sliding = true
			last_wall_dir = -1
			velocity.y = min(velocity.y, wall_slide_speed)
		elif on_wall_right:
			is_wall_sliding = true
			last_wall_dir = 1
			velocity.y = min(velocity.y, wall_slide_speed)

	# Сильное отталкивание от стены
	if is_wall_sliding and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")):
		velocity.x = -last_wall_dir * wall_jump_horizontal
		velocity.y = wall_jump_vertical
		is_wall_sliding = false

	# Горизонтальное движение
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.75)

	# Поворот
	if is_wall_sliding:
		anim.flip_h = last_wall_dir > 0
	elif direction != 0:
		anim.flip_h = direction > 0

	move_and_slide()
	update_animations(direction)

func is_valid_wall_left() -> bool:
	return is_ray_valid(ray_left_top) or is_ray_valid(ray_left_mid) or is_ray_valid(ray_left_bottom)

func is_valid_wall_right() -> bool:
	return is_ray_valid(ray_right_top) or is_ray_valid(ray_right_mid) or is_ray_valid(ray_right_bottom)

func is_ray_valid(ray: RayCast2D) -> bool:
	if not ray.is_colliding():
		return false
	var collider = ray.get_collider()
	if collider and collider.is_in_group("no_climb"):
		return false
	return true

func update_animations(direction: float):
	if is_wall_sliding:
		if anim.animation != "wall_slide":
			anim.play("wall_slide")
		return

	if not is_on_floor():
		if anim.animation != "jump":
			anim.play("jump")
		return

	if direction != 0:
		if anim.animation != "run":
			anim.play("run")
	else:
		if anim.animation != "idle":
			anim.play("idle")
