extends Node3D

@export_range(0.01, 1.0, 0.01) var pointing_tween_duration: float = 0.2

var pointing_tween: Tween

@onready var body: CharacterBody3D = $BodyTemplate3D
@onready var pointing: Node3D = $BodyTemplate3D/Pointing
@onready var pointing_hand: Sprite3D = $BodyTemplate3D/Pointing/LeftHand
@onready var animation_player: AnimationPlayer = $BodyTemplate3D/AnimationPlayer


func _ready() -> void:
	# The sprite parts occupy the body's local XY plane (100 pixels per unit).
	pointing.position = Vector3.ZERO
	pointing_hand.position = Vector3(0.76, 0.0, 0.02)
	pointing_hand.rotation = Vector3(0.0, 0.0, -PI / 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# Project the click onto the character's plane, including a rotated body.
	var plane := Plane(body.global_basis.z.normalized(), pointing.global_position)
	var hit: Variant = plane.intersects_ray(
		camera.project_ray_origin(event.position),
		camera.project_ray_normal(event.position)
	)
	if hit == null:
		return
	point_at(hit)
	get_viewport().set_input_as_handled()


func point_at(target: Vector3) -> void:
	var direction := body.to_local(target) - pointing.position
	if Vector2(direction.x, direction.y).length_squared() < 0.000001:
		return

	animation_player.play("pointing")
	animation_player.advance(0.0)
	if pointing_tween and pointing_tween.is_valid():
		pointing_tween.kill()

	var end_rotation := pointing.rotation
	var target_angle := atan2(direction.y, direction.x)
	end_rotation.z += wrapf(target_angle - end_rotation.z, -PI, PI)
	pointing_tween = create_tween()
	pointing_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointing_tween.tween_property(
		pointing, "rotation", end_rotation, pointing_tween_duration
	)
