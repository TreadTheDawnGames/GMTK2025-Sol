extends Node2D

# --- Procedural Generation Settings ---
@export_category("Level Generation")
# The scenes for planets that can be randomly spawned.
@export var planet_scenes: Array[PackedScene] = [
]
# The scene for the nebula visual effect.
@export var nebula_scene: PackedScene = preload("uid://c6nutn3avrvok")
# The maximum radius from the center (0,0) where planets can spawn.
@export var spawn_radius: float = 30000.0
# The number of nebulas to spawn.
@export var num_nebulas: int = 8
# The number of planets to spawn.
@export var num_planets: int = 50
# The minimum empty space to leave between the edges of two regular planets.
@export var min_distance_between_planets: float = 1500.0
# How many planets should be clustered inside nebulas.
@export var planets_in_nebulas: int = 8
@export var num_nebula_clusters: int = 8

# --- Special Celestial Body Settings ---
@export_category("Special Objects")
@export var do_sun : bool = true
# The scene for the Sun, which will be placed at the center.
@export var sun_scene: PackedScene = preload("uid://w1hy76n1gkow")
# The scene for the Black Hole, placed randomly.
#@export var black_hole_scene: PackedScene = preload("res://Scenes/planet_black_hole.tscn")
# The scene for additional Home Stations/Shops.
@export var station_scene: PackedScene = preload("uid://14epulnfjodl")
# The number of ADDITIONAL random stations to spawn (on top of the main HomeBase).
@export var num_additional_stations: int = 2
# The extra empty space required around stations to prevent them from feeling crowded.
@export var station_separation_buffer: float = 4000.0

# This constant defines a safe radius around the sun for the Nebulas
const SUN_EXCLUSION_RADIUS = 3000.0
@export_range(3, 10) var nebulas_per_cluster_min: int = 10
@export_range(3, 10) var nebulas_per_cluster_max: int = 20
@export var cluster_radius: float = 2500.0 # How far nebulas can spawn from cluster center

var all_planets: Array[Area2D] = []
var sun = null

func generate_level():
	# This array will keep track of all placed objects to check for overlaps.
	var placed_celestial_bodies = []
	
	# This helper function will handle the placement logic for any given object.
	var place_object = func(scene: PackedScene, tracking_array: Array, pos: Vector2):
		if not is_instance_valid(scene):
			push_warning("Cannot place object: PackedScene is not valid.")
			return null

		var instance = scene.instantiate()
		var new_radius = instance.get_gravity_radius() if instance is BasePlanet else 200
		
		var overlaps = false
		for existing_body in tracking_array:
			if not is_instance_valid(existing_body): continue
			
			var existing_radius = existing_body.get_gravity_radius() if existing_body is BasePlanet else 200
			var distance = pos.distance_to(existing_body.global_position)
			
			var required_buffer = min_distance_between_planets
			var is_new_obj_station = instance is HomePlanet
			var is_existing_obj_station = existing_body is HomePlanet
			if is_new_obj_station or is_existing_obj_station:
				required_buffer = station_separation_buffer

			if distance < new_radius + existing_radius + required_buffer:
				overlaps = true
				break
		
		if not overlaps:
			instance.global_position = pos
			instance.rotation = randf_range(-180, 180)
			add_child(instance)
			tracking_array.append(instance)
			return instance
		else:
			instance.queue_free()
			return null

	# --- Step 1: Place Stations Evenly Across the Map ---
	var total_stations = 1 + num_additional_stations
	var angle_per_sector = TAU / total_stations
	
	for i in range(total_stations):
		var station_placed = false
		for attempt in range(20):
			var sector_start_angle = i * angle_per_sector
			var sector_end_angle = (i + 1) * angle_per_sector
			var random_angle = randf_range(sector_start_angle, sector_end_angle)
			var random_radius = randf_range(spawn_radius * 0.5, spawn_radius * 0.9)
			var station_pos = Vector2.from_angle(random_angle) * random_radius

			var station_instance = place_object.call(station_scene, placed_celestial_bodies, station_pos)

			if is_instance_valid(station_instance):
				#if not is_instance_valid(self.home_planet):
					#self.home_planet = station_instance
					## Move the player to start next to this newly placed station.
					#player.global_position = home_planet.global_position + Vector2(400, -50)
					## This tells the player that this station is its new "home" for the lose condition.
					#player.set_origin_point(home_planet.global_position)
					#print("setting home planet")
				station_placed = true
				break
		
		if not station_placed:
			print("Could not place a station in sector %d after 20 attempts." % i)

	if(do_sun):
		 #--- Step 2: Place the Sun at the Center ---
		if is_instance_valid(sun_scene):
			sun = sun_scene.instantiate()
			sun.global_position = Vector2.ZERO
			add_child(sun)
			placed_celestial_bodies.append(sun)

	# --- Step 4: Spawn Nebula CLUSTERS ---
	var spawned_nebulas = []
	if is_instance_valid(nebula_scene): # and is_instance_valid(generated_nebulas_node)
		# This is the outer loop for creating clusters.
		for i in range(num_nebula_clusters):
			var cluster_center = Vector2.from_angle(randf() * TAU) * randf_range(SUN_EXCLUSION_RADIUS, spawn_radius * 0.85)
			
			# This picks a random color group index for the entire cluster (0=Red, 1=Green, 2=Purple, 3=Blue).
			var cluster_color_index = randi() % 4
			
			var num_in_cluster = randi_range(nebulas_per_cluster_min, nebulas_per_cluster_max)
			
			# This is the inner loop to spawn nebulas *within* the cluster.
			for j in range(num_in_cluster):
				var nebula = nebula_scene.instantiate()
				var nebula_pos = cluster_center + Vector2.from_angle(randf() * TAU) * randf_range(0, cluster_radius)
				nebula.global_position = nebula_pos
				
				#generated_nebulas_node.
				add_child(nebula)
				# This tells the new nebula which color group it belongs to.
				nebula.setup_nebula(cluster_color_index)
				
				spawned_nebulas.append(nebula)
	
	# --- Step 5: Fill the rest of the space with Regular Planets ---
	if not planet_scenes.is_empty():
		var planets_to_spawn = num_planets
		for i in range(planets_to_spawn):
			for attempt in range(20):
				var planet_scene = planet_scenes.pick_random()
				var spawn_center = Vector2.ZERO
				var placement_radius = spawn_radius

				#if i < planets_in_nebulas and not spawned_nebulas.is_empty():
					#var target_nebula = spawned_nebulas.pick_random()
					#spawn_center = target_nebula.global_position
					#placement_radius = target_nebula.get_radius() * 0.8
				
				var pos = spawn_center + Vector2.from_angle(randf() * TAU) * randf_range(0, placement_radius)
				if is_instance_valid(place_object.call(planet_scene, placed_celestial_bodies, pos)):
					break
					
	all_planets.clear()
	find_planets_recursive(self)
	HudLayer.game_hud.compass.setup_compass(all_planets, sun)

func find_planets_recursive(node: Node):
	# This searches recursively through all child nodes to find planets.
	for child in node.get_children():
		# This checks if the node is a standard planet or a home planet.
		if child is BasePlanet:
			all_planets.append(child)

		# This continues the search into the children of the current node.
		if child.get_child_count() > 0:
			find_planets_recursive(child)
