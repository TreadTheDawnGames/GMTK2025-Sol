extends Node2D
class_name VisTrajectoryManager
@onready var aim_line: Line2D = $"../AimLine"
@onready var VT_line: Line2D = $"../VisualTrajectoryLine"

# Trajectory prediction settings
@export var trajectory_prediction_enabled: bool = false # DEBUG Turn on True if wanting to test
@export var trajectory_steps: int = 50 # Original 50
@export var trajectory_step_time: float = 0.1

func _ready():
	aim_line.visible = GameManager.use_aim_arrow
	GameManager.UseAimArrow.connect(func(use): aim_line.visible = use)

func reset():
	VT_line.clear_points()


# Creates a curved trajectory line accounting for gravity effects.
func create_curved_trajectory_line(power_percentage: float, initial_velocity : Vector2, max_pull_dist : float) -> void:
	# Calculates initial velocity for trajectory simulation
	#var initial_velocity = _current_aim_pull_vector * launch_power * (2.0 if onPlanet else 1.0)

	# Simulates trajectory with physics.
	var trajectory_points = simulate_trajectory(global_position, initial_velocity, max_pull_dist)

	# Adds trajectory points to the line.
	VT_line.add_point(Vector2.ZERO)  # Starts at player position.
	for point in trajectory_points:
		var local_point = global_transform.basis_xform_inv(point - global_position)
		VT_line.add_point(local_point)

	# Sets line appearance based on power.
	var line_color = Color.WHITE.lerp(Color.CYAN, power_percentage)  # Different color for curved line.
	VT_line.default_color = line_color
	VT_line.width = 4.0 + power_percentage * 6.0

# Simulates trajectory accounting for gravity only when intersecting planet gravity zones.
func simulate_trajectory(start_pos: Vector2, initial_velocity: Vector2, max_pull_distance) -> Array[Vector2]:
	var trajectory_points: Array[Vector2] = []
	var sim_position = start_pos
	var sim_velocity = initial_velocity

	# Gets all planets in the scene for gravity calculation.
	var planets = get_tree().get_nodes_in_group("planets")
	if planets.is_empty():
		# Fallback: finds planets by type if group is empty.
		planets = []
		var root = get_tree().current_scene
		if root:
			for child in root.get_children():
				if child is BasePlanet:
					planets.append(child)

	# Simulates trajectory step by step.
	for i in range(trajectory_steps):
		# Calculates gravity forces only from planets whose gravity zones intersect trajectory.
		var total_gravity_force = Vector2.ZERO

		for planet in planets:
			if not is_instance_valid(planet) or not planet is BasePlanet:
				continue

			var planet_pos = planet.global_position
			var distance = sim_position.distance_to(planet_pos)

			# Gets planet's gravity zone radius (Area2D collision shape).
			var gravity_zone_radius = 200.0
			if planet.collision_shape_2d and planet.collision_shape_2d.shape is CircleShape2D:
				gravity_zone_radius = planet.collision_shape_2d.shape.radius

			# Applies gravity only if trajectory point is within the gravity zone.
			if distance <= gravity_zone_radius and distance > 50.0:
				# Calculates gravity force similar to planet.gd.
				var direction_to_planet = (planet_pos - sim_position).normalized()
				var gravity_strength = planet.gravity_strength

				# Gets planet's physical radius for falloff calculation.
				var planet_physical_radius = 100.0
				if planet.sprite and planet.sprite.texture:
					# Estimates physical radius from sprite.
					var sprite_size = planet.sprite.texture.get_size() * planet.sprite.scale
					planet_physical_radius = max(sprite_size.x, sprite_size.y) * 0.5

				var gravity_falloff = planet_physical_radius / distance
				var gravity_force = direction_to_planet * gravity_strength * gravity_falloff

				# Applies gravity modifier if player has one.
				var gravity_component = get_node_or_null("GravityModifierComponent")
				if gravity_component:
					gravity_force = gravity_component.modify_gravity_force(gravity_force)

				total_gravity_force += gravity_force

		# Updates velocity with gravity (simplified physics).
		sim_velocity += total_gravity_force * trajectory_step_time / get_parent().mass

		# Updates position.
		sim_position += sim_velocity * trajectory_step_time

		# Adds point to trajectory.
		trajectory_points.append(sim_position)

		# Stops simulation if trajectory goes too far.
		if sim_position.distance_to(start_pos) > max_pull_distance * 3:
			break

	return trajectory_points

# Creates a straight aim line (original behavior).
func create_straight_aim_line(power_percentage: float, aim_pull_vector) -> void:
	# Adds a point at the player's center (0,0 in local coordinates for the Line2D).
	VT_line.add_point(Vector2.ZERO)

	# Adds the end point of the pull vector, transformed into Line2D's local space.
	# Ensures the line points correctly regardless of player's current rotation.
	VT_line.add_point(get_parent().global_transform.basis_xform_inv(aim_pull_vector))

	# Calculates the color interpolation from white to red based on power.
	var line_color = Color.WHITE.lerp(Color.RED, power_percentage)
	VT_line.default_color = line_color

	# Sets the line width based on power (thicker line = more power).
	VT_line.width = 3.0 + power_percentage * 7.0

## Draws and updates the aiming line.
func update_aim_line(pull_vector_from_player_to_mouse : Vector2, max_pull_distance : float, _current_aim_pull_vector, launch_power : float, onPlanet : bool) -> void:
	
	# Calculates the global vector from the player's current position to the current mouse position.
	#var pull_vector_from_player_to_mouse = initialClickPos - GetGlobalClickPosition()
	
	# Clamps the vector's length to the max_pull_distance.
	_current_aim_pull_vector = pull_vector_from_player_to_mouse.limit_length(max_pull_distance)

	# Calculates the power percentage (0.0 to 1.0) based on distance.
	var power_percentage = _current_aim_pull_vector.length() / max_pull_distance

	# Clears any previous points from the line.
	reset()

	if trajectory_prediction_enabled:
		# Creates curved trajectory line accounting for gravity.
		create_curved_trajectory_line(power_percentage, (_current_aim_pull_vector * launch_power * (2.0 if onPlanet else 1.0)), max_pull_distance)
	else:
		# Creates simple straight line.
		create_straight_aim_line(power_percentage, _current_aim_pull_vector)

func do_aim_arrow(origin : Vector2, mouse : Vector2):
	aim_line.clear_points()
	aim_line.add_point(origin)
	aim_line.add_point(mouse)

func reset_aim_arrow():
	aim_line.clear_points()

func draw_aim_line(_current_aim_pull_vector : Vector2, max_pull_distance : float):
	# Calculates the power percentage (0.0 to 1.0) based on distance.
	var power_percentage : float = _current_aim_pull_vector.length() / max_pull_distance
	# Clears any previous points from the line.
	reset()

	#if trajectory_prediction_enabled:
		# Creates curved trajectory line accounting for gravity.
		#create_curved_trajectory_line(power_percentage, (_current_aim_pull_vector * launch_power * (2.0 if onPlanet else 1.0)), max_pull_distance)
	#else:
		# Creates simple straight line.
	create_straight_aim_line(power_percentage, _current_aim_pull_vector)
