extends CharacterBody2D
# the player. runs, jumps, slides down walls it is allowed to grab, and
# bounces off them for height. a wall in the "no_climb" group is solid but
# cannot be slid on or bounced off.

# sized for the map's 48px cells: a jump rises ~230px (about 5 cells) and a
# running jump clears about 7 cells of gap
@export var speed: float = 320.0
@export var jump_velocity: float = -860.0
@export var gravity: float = 1600.0
# falling is faster than rising so the jump does not feel floaty
@export var fall_gravity_multiplier: float = 1.55

# how long after leaving the ground you can still jump
@export var coyote_time: float = 0.12
# how early you can press jump before landing and still get it
@export var jump_buffer_time: float = 0.12

# top falling speed while sliding down a wall
@export var wall_slide_speed: float = 260.0

# the bounce: jumping off a wall throws you away from it and upward, so
# height is gained by zigzagging between two faces rather than scaling one.
@export var wall_bounce_horizontal: float = 700.0
@export var wall_bounce_vertical: float = -780.0
# input is ignored for this long after a bounce so the push actually travels
@export var wall_bounce_lockout: float = 0.14
# how fast any speed above `speed` bleeds off once you are steering again
@export var air_drag: float = 1360.0

# set by the cutscene while a scripted beat is playing. gravity and collision
# keep running, we just stop reading the keyboard.
var input_locked: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var bounce_lockout_timer: float = 0.0
var is_wall_sliding: bool = false
# side of the wall we are sliding on, so the bounce knows where to push
var last_wall_dir: int = 0
# side of the wall we bounced off last. the same side twice in a row is
# refused, so one face cannot be pogoed up. cleared on landing.
var last_bounce_dir: int = 0
# bounces in a row without touching the ground. the second one onward plays
# the combo sound.
var bounce_chain: int = 0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# three rays per side, so a wall still counts when only part of the body
# touches it. the nodes are named for the side of the body they sit on, but
# each one shoots across to the other side — $RayLeftTop points right. bind
# them by the direction they actually scan so the names below can be trusted.
# renaming the nodes in the editor would let these lines match again.
@onready var ray_left_top: RayCast2D = $RayRightTop
@onready var ray_left_mid: RayCast2D = $RayRightMid
@onready var ray_left_bottom: RayCast2D = $RayRightBottom
@onready var ray_right_top: RayCast2D = $RayLeftTop
@onready var ray_right_mid: RayCast2D = $RayLeftMid
@onready var ray_right_bottom: RayCast2D = $RayLeftBottom
# the orange thoughts above the head. level triggers and cutscenes talk
# through this.
@onready var speech: Node2D = $Speech

# run frames where a foot lands
const STEP_FRAMES: Array[int] = [1, 3]

func _ready() -> void:
	anim.frame_changed.connect(_on_frame_changed)

func _on_frame_changed() -> void:
	if anim.animation == "run" and anim.frame in STEP_FRAMES and is_on_floor():
		Sfx.play("step")

func _physics_process(delta):
	if not is_on_floor():
		var grav = gravity
		if velocity.y > 0:
			grav *= fall_gravity_multiplier
		velocity.y += grav * delta

	if is_on_floor():
		coyote_timer = coyote_time
		# back on the ground, so either wall is fair game again
		last_bounce_dir = 0
		bounce_chain = 0
	else:
		coyote_timer -= delta

	jump_buffer_timer -= delta
	bounce_lockout_timer -= delta

	var direction := 0.0
	if not input_locked:
		direction = Input.get_axis("ui_left", "ui_right")
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
			jump_buffer_timer = jump_buffer_time

	# Стены
	# walls. -1 is a wall to our left, 1 a wall to our right
	var wall_dir := 0
	if is_valid_wall_left():
		wall_dir = -1
	elif is_valid_wall_right():
		wall_dir = 1

	# Скольжение по стене
	# sliding. falling against a wall pins you to it and caps the fall, which
	# is the moment to line a bounce up.
	is_wall_sliding = false
	if not is_on_floor() and velocity.y > 0 and wall_dir != 0:
		is_wall_sliding = true
		last_wall_dir = wall_dir
		velocity.y = min(velocity.y, wall_slide_speed)

	# Обычный прыжок
	# normal jump, only if the press and the ground are both recent
	var jumped := false
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jumped = true
		Sfx.play_move("jump")

	# Отскок от стены
	# jumping off a wall. the angle comes from the key you are holding, not from
	# the wall — press nothing and you go straight up, still against it. the
	# face we came off last is refused, so a single wall cannot be climbed on
	# its own; you have to alternate between two.
	if not jumped and jump_buffer_timer > 0 and not is_on_floor() \
			and wall_dir != 0 and wall_dir != last_bounce_dir:
		velocity.y = wall_bounce_vertical
		last_bounce_dir = wall_dir
		jump_buffer_timer = 0.0
		bounce_chain += 1
		Sfx.play_move("jump_combo" if bounce_chain > 1 else "walljump")
		is_wall_sliding = false
		# the push-off pose has its hands on the wall, so it faces the wall
		anim.flip_h = wall_dir < 0
		# a key held into the wall leads nowhere, so it counts as holding nothing
		if direction != 0.0 and int(signf(direction)) != wall_dir:
			velocity.x = direction * wall_bounce_horizontal
			# only a sideways push needs shielding from the next frame of input
			bounce_lockout_timer = wall_bounce_lockout
		else:
			velocity.x = 0.0

	# Переменная высота
	# let go of the button early and the jump gets cut short
	if not input_locked and velocity.y < 0 \
			and (Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")):
		velocity.y *= 0.4

	# Горизонтальное движение
	# horizontal movement, held off while a bounce is still carrying us
	if bounce_lockout_timer <= 0.0:
		if absf(velocity.x) > speed:
			# coming out of a bounce: bleed the extra off gradually, or the push
			# would be wiped on the very next frame
			velocity.x = move_toward(velocity.x, direction * speed, air_drag * delta)
		elif direction != 0:
			velocity.x = direction * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 0.75)

	# Поворот
	# which way the sprite faces. the wall_slide and wall_grab art is drawn
	# facing right, opposite to run and idle, so the wall poses invert the
	# flip. both of them face into the wall.
	if is_wall_sliding:
		anim.flip_h = last_wall_dir < 0
	elif direction != 0 and bounce_lockout_timer <= 0.0:
		anim.flip_h = direction > 0

	move_and_slide()
	update_animations(direction)

# a wall on this side counts if any of its three rays hits something climbable
func is_valid_wall_left() -> bool:
	return is_ray_valid(ray_left_top) or is_ray_valid(ray_left_mid) or is_ray_valid(ray_left_bottom)

func is_valid_wall_right() -> bool:
	return is_ray_valid(ray_right_top) or is_ray_valid(ray_right_mid) or is_ray_valid(ray_right_bottom)

# a ray only counts if it hit something that is not in the "no_climb" group
func is_ray_valid(ray: RayCast2D) -> bool:
	if not ray.is_colliding():
		return false
	var collider = ray.get_collider()
	if collider and collider.is_in_group("no_climb"):
		return false
	return true

# pick the animation for what the player is doing right now.
# the bounce pose wins over the slide, the slide over being in the air,
# air over running. the animation != check stops it restarting every frame
func update_animations(direction: float):
	if bounce_lockout_timer > 0.0:
		if anim.animation != "wall_grab":
			anim.play("wall_grab")
		return

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
