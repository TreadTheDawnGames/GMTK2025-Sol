extends Node2D
class_name ShipTrailManager

@onready var trail_2d_1: Line2D = $"../CollisionShape2D/Node2D/Trail2D"
@onready var trail_2d_2: Line2D = $"../CollisionShape2D/Node2D2/Trail2D"

@export var original_trail_length: int = 10
@export var original_trail_color: Color = Color.WHITE
@export var braking_trail_color: Color = Color(0.8, 0.2, 0.2, 0.8) # Dull red
@export var boost_trail_color: Color = Color(0, 1, 1, 1) # Bright cyan
var trail_effect_tween: Tween


# This initializes trail properties.
func _ready_trail_setup():
	if trail_2d_1 and trail_2d_2:
		# Stores original trail properties.
		original_trail_length = trail_2d_1.length if trail_2d_1.has_method("length") else 10
		original_trail_color = trail_2d_1.default_color
# This resets trails to normal appearance.
func reset_trail_effects():
	if not trail_2d_1 or not trail_2d_2:
		return

	# Stops any ongoing trail animation.
	if trail_effect_tween:
		trail_effect_tween.kill()

	# Resets trail properties to normal.
	if trail_2d_1.has_method("set_length"):
		trail_2d_1.length = original_trail_length
	if trail_2d_2.has_method("set_length"):
		trail_2d_2.length = original_trail_length

	trail_2d_1.default_color = original_trail_color
	trail_2d_2.default_color = original_trail_color

# This applies braking trail effect.
func apply_braking_trail_effect():
	if not trail_2d_1 or not trail_2d_2:
		return

	# Stops any ongoing animation.
	if trail_effect_tween:
		trail_effect_tween.kill()

	# Creates braking effect - shorter, red trails.
	trail_effect_tween = create_tween()
	trail_effect_tween.parallel().tween_property(trail_2d_1, "default_color", braking_trail_color, 0.2)
	trail_effect_tween.parallel().tween_property(trail_2d_2, "default_color", braking_trail_color, 0.2)

	# Shortens trails if possible.
	if trail_2d_1.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_1.length = length, original_trail_length, original_trail_length * 0.5, 0.2)
	if trail_2d_2.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_2.length = length, original_trail_length, original_trail_length * 0.5, 0.2)

# This applies boost trail effect.
func apply_boost_trail_effect():
	if not trail_2d_1 or not trail_2d_2:
		return

	# Stops any ongoing animation.
	if trail_effect_tween:
		trail_effect_tween.kill()

	# Creates boost effect - longer, bright cyan trails.
	trail_effect_tween = create_tween()
	trail_effect_tween.parallel().tween_property(trail_2d_1, "default_color", boost_trail_color, 0.1)
	trail_effect_tween.parallel().tween_property(trail_2d_2, "default_color", boost_trail_color, 0.1)

	# Lengthens trails if possible.
	if trail_2d_1.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_1.length = length, original_trail_length, original_trail_length * 2.0, 0.1)
	if trail_2d_2.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_2.length = length, original_trail_length, original_trail_length * 2.0, 0.1)

	# Fades back to normal after 1 second.
	trail_effect_tween.tween_interval(1.0)
	trail_effect_tween.parallel().tween_property(trail_2d_1, "default_color", original_trail_color, 0.5)
	trail_effect_tween.parallel().tween_property(trail_2d_2, "default_color", original_trail_color, 0.5)

	if trail_2d_1.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_1.length = length, original_trail_length * 2.0, original_trail_length, 0.5)
	if trail_2d_2.has_method("set_length"):
		trail_effect_tween.parallel().tween_method(func(length): trail_2d_2.length = length, original_trail_length * 2.0, original_trail_length, 0.5)

func apply_reset_trail():
	if trail_effect_tween and trail_2d_1.default_color == braking_trail_color:
		reset_trail_effects()

func reset():
	trail_2d_1.clear_points()
	trail_2d_2.clear_points()
