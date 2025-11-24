extends RigidBody2D
class_name Player
@onready var audioHandler: PlayerAudioHandler = $AudioHandler
# The trail effects
@onready var point_numbers_spawnpoint: Marker2D = $PointNumbersOrigin

#region Ship Stats
# This tracks the maximum number of skips the player can have.
var max_skips_per_orbit: int = 1
# This tracks the current number of available skips.
var current_skips_available: int = 0
var dead : bool = false
# A cooldown for launching. TTDG: I use it to make sure releasing fast doesn't use a boost.
const LAUNCH_COOLDOWN_TIME : float = 0.3

var canBoost : bool = false
var canSkip : bool = true
# Flag to double launch if on planet
var onPlanet : bool = false

#endregion

# Trail effect properties
@onready var trail_manager: ShipTrailManager = $TrailManager

var hud : GameHUD #= get_tree().root.get_node("Game/HUDLayer/GameHUD")

# This defines a set of named states for the player's state machine.
enum State {
	READY_TO_AIM,
	AIMING,
	LAUNCHED
}

# Aim Manager for showing the lines and stuff while aiming.
@onready var aim_manager: VisTrajectoryManager = $AimManager

@onready var Shape: CollisionShape2D = $CollisionShape2D
@export var softlock_sensitivity = 50


@export_category("Orbit Settings")
@export_range(0.0, 1.0) var orbit_completion_percentage: float = 0.95 # 95%

@export var SoftlockTime : float = 2
@export var DEBUG_DoLoseCondition : bool = true
# The particles
@onready var _LaunchParticles: ParticleEffect = $LaunchParticles
@onready var _BoostParticles: ParticleEffect = $BoostParticles
# The sprite
@onready var Sprite: Sprite2D = $Sprite2D
# The Camera
@onready var camera_2d: ScreenShake = $Camera2D

# This exports a variable for launch power, tunable in the Inspector.
@export var launch_power: float = 10.0
# This exports a variable for the maximum drag distance (100% power).
@export var max_pull_distance: float = 200.0
# This exports a variable for the boost impulse strength.
@export var boost_strength: float = 1000.0

#defines how fast a click should be. I use 0.2 in another game just fine.
#const CLICK_TIME : float = 0.2

# The variable that counts your loop streak
var loopCounter : int = 0
var highScore : int = 0

# Track planets that have been orbited for first-time bonus
var orbited_planets: Array[BasePlanet] = []

# This array will keep track of all planets whose gravity fields the player is currently inside.
var overlapping_planets: Array[BasePlanet] = []

## Used for the background paralax
static var Position : Vector2

# This variable will hold the player's current state from the enum above.
var current_state: State = State.READY_TO_AIM
# This boolean tracks if the one-time boost is still available.
var BoostCount: int = 3:
	get: return BoostCount
	set(value):
		var old_value = BoostCount
		BoostCount = value
		if(BoostCount == 0):
			Sprite.frame_coords.y = 1
			$"BoostParticles-Explosion".Emit(true)
			# This shows out of boosts tutorial (only when transitioning from >0 to 0)
			#if old_value > 0:
				#if hud:
					#TutorialManager.show_out_of_boosts_tutorial(hud)
		else:
			# Sets the sprite frame to indicate boosts are available.
			Sprite.frame_coords.y = 0

# This new variable will store the calculated pull vector while aiming.
var _current_aim_pull_vector: Vector2 = Vector2.ZERO

# Stores whether a single touch is happening on mobile.
var any_fingies_down : bool = false

# Lose condition variables
static var max_distance_from_origin: float = 35000.0  # Maximum distance before losing
var origin_position: Vector2 = Vector2.ZERO # No longer static, can be changed.
var has_lost: bool = false

# This function allows the GameController to tell the player where its "home" is.
func set_origin_point(new_origin: Vector2):
	# This sets the center point for the lose condition distance check.
	origin_position = new_origin



# This section is for the new orbit tracking logic.
var current_orbiting_planet: BasePlanet = null
var last_angle_to_planet: float = 0.0
var accumulated_orbit_angle: float = 0.0
var orbit_start_angle: float = 0.0  # Angle where orbit started

var mobilePosition : Vector2
# This function is called by Godot when an input event occurs on this object.
#func _input(ev: InputEvent) -> void:
	#if ev is InputEventMouseButton:
		#var event = ev as InputEventMouseButton
		#if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			#clickTimer = get_tree().create_timer(CLICK_TIME)
			#get_viewport().set_input_as_handled()

# A timer to check if the mouse button was down/up quick
#var clickTimer : SceneTreeTimer

var singleTouchProcessed : bool = false
var mouseReleased = true
var initialClickPos : Vector2
var aim_canceled : bool = false
var mobileBrake : bool = false
var mobileBoost : bool = false
var has_boosted_this_touch : bool = false


static var softlockTimer : SceneTreeTimer
static var isBeingSaved : bool = false
@export var softlockTime : float = 3.0
static var doNotSave : bool = false

#region Engine funcs
func _ready() -> void:
	hud = get_tree().root.get_node("Game/HUDLayer/GameHUD")
	#TutorialManager.show_how_to_play(hud)
	
	#setup mobile boost/brake buttons
	hud.mobile_controls.primary.pressed.connect(func(): 
		if(current_state == State.LAUNCHED):
			mobileBoost = true)
	hud.mobile_controls.secondary.pressed.connect(func(): 
		if(current_state == State.LAUNCHED):
			mobileBrake = true)
	
	# setup damp mode
	linear_damp_mode = RigidBody2D.DAMP_MODE_COMBINE
	# Stores starting position as origin
	origin_position = global_position
	# Applies ship color from GameManager
	apply_ship_color()
	# Connects to color change signal
	GameManager.ship_color_changed.connect(_on_ship_color_changed)
	GameManager.reset_score()
	PointsManager.setup(point_numbers_spawnpoint)

# This function is called every frame.
func _process(_delta: float) -> void:
	_handle_mobile_input()

	# Does not process input if game is paused (e.g., shop is open).
	if get_tree().paused:
		return

	# Updates player's global position for background parallax.
	Position = global_position
	
	_handle_launch_canceled()
	_handle_aiming()
	_handle_launching()

# This function runs every physics frame, ideal for physics-related code.
func _physics_process(_delta: float) -> void:
	
	# This section continuously determines the strongest gravitational influence.
	var max_force = -1.0

	_notify_strongest_planet_that_we_are_now_orbiting_it(_determine_strongest_planet_pull(max_force))

	# This logic detects if the player is stuck at a very low velocity and summons a "saving" asteroid.
	_handle_softlock()
		
	# Checks if the player has drifted too far from the starting origin.
	_check_lose_condition()
	
	if is_inside_tree():
		# Moves the player and checks for collisions.
		var collision : KinematicCollision2D = move_and_collide(linear_velocity.normalized(), true)
		_handle_collision(collision)
			
	_handle_launched_state()
#endregion

#region Customization
## Applies the current ship color from GameManager (not active right now)
func apply_ship_color() -> void:
	# This line is commented out as it seems ship color modulation is not currently active.
	# var ship_color = GameManager.get_ship_color()
	# Sprite.modulate = ship_color
	pass
	
## Called when ship color changes in GameManager
func _on_ship_color_changed(_new_color: Color) -> void:
	apply_ship_color()
#endregion

#region Game Logic
func _handle_softlock():
	if(not onPlanet and BoostCount == 0 and current_state == State.LAUNCHED and (linear_velocity.length() < softlock_sensitivity) and not isBeingSaved):
		if(not doNotSave):
			isBeingSaved = true
			if(not softlockTimer):
				softlockTimer = get_tree().create_timer(SoftlockTime)
				softlockTimer.timeout.connect(func(): 
					SoftlockFixer.FixSoftlock(self)
				)
		else:
			doNotSave = false
	elif not onPlanet and BoostCount > 0 and current_state == State.LAUNCHED and (linear_velocity.length() < 5) and not isBeingSaved:
		get_tree().create_timer(5).timeout.connect(func(): TutorialManager.show_stuck_with_boosts(hud))

func _handle_launched_state():
	# This block runs only when the player has been launched and is in motion.
	if current_state == State.LAUNCHED:
		# Makes the rocket point in the direction it's moving.
		if linear_velocity.length() > 0.01:
			rotation = linear_velocity.angle()
		# Checks if the boost is available and the user pressed the boost action (for keyboard).
		if BoostCount > 0 and Input.is_action_just_pressed("boost"):
			apply_boost()
		# Checks for the brake action (keyboard, right mouse, or mobile).
		if(Input.is_action_pressed("brake") or mobileBrake):
			linear_damp = 5
			trail_manager.apply_braking_trail_effect()
		else:
			linear_damp = 0
			trail_manager.apply_reset_trail()

		# Calls the function to handle orbit progress tracking.
		_handle_orbit_tracking()
		
## Checks if player has gone too far and should lose
func _check_lose_condition() -> void:
	# This stops the function if the player has already lost or if the debug flag is off.
	if has_lost or not DEBUG_DoLoseCondition:
		return

	# This calculates the distance from the center of the map (0,0) instead of the starting origin.
	var distance_from_center = global_position.distance_to(Vector2.ZERO)
	# This checks if the player's distance from the center exceeds the maximum allowed distance.
	if distance_from_center > max_distance_from_origin:
		# This sets a flag to ensure the lose sequence only runs once.
		has_lost = true
		# This prints a debug message to the console.
		print("Player went too far! Distance from center: ", distance_from_center)

		# This calculates and adds the final score before showing the lose screen.
		PointsManager.calculate_final_score()
		# This tells the GameManager to switch to the lose screen.
		GameManager.show_lose_screen()
#endregion

#region Orbits
# This function tracks the player's progress around a planet.
func _handle_orbit_tracking():
	# Stops the function if the player is not currently orbiting a planet.
	if not is_instance_valid(current_orbiting_planet):
		return
	
	#Don't do anything if the orbited object doesn't allow points.
	if(not current_orbiting_planet.has_points):
		return
	# Calculates the player's current angle relative to the planet's center.
	var current_angle = (global_position - current_orbiting_planet.global_position).angle()
	# Calculates how much the angle has changed since the last physics frame.
	var delta_angle = angle_difference(last_angle_to_planet, current_angle)
	
	# Accumulates total angular movement regardless of orbit direction (clockwise or counter-clockwise).
	accumulated_orbit_angle += abs(delta_angle)
	
	# Stores the current angle to compare against in the next frame.
	last_angle_to_planet = current_angle
	
	# Tells the planet to update its visual progress line, passing the direction of rotation.
	current_orbiting_planet.update_orbit_progress(accumulated_orbit_angle, orbit_completion_percentage, orbit_start_angle, sign(delta_angle))
	
	# Checks if the accumulated angle has reached a full loop.
	if accumulated_orbit_angle >= (2 * PI) * orbit_completion_percentage:

		# Checks if this is the first time orbiting this specific planet for a score bonus.
		var is_first_orbit = current_orbiting_planet not in orbited_planets
		# If it is the first time, adds it to the list of visited planets.
		if current_orbiting_planet is Planet_Sol:
			PointsManager.multiply_mult(5)
			PointsManager.add_points(50)
			
		if is_first_orbit:
			orbited_planets.append(current_orbiting_planet)
			if(current_orbiting_planet.AtmoSprite.material):
				current_orbiting_planet.SetShowOrbited(true)
			
			if current_orbiting_planet is not Planet_Sol:
				# This adds a +5 score bonus for the first orbit.
				#GameManager.add_score(5)
				print("First orbit bonus! +5 score")
				PointsManager.add_points(5)
		else: 
			if current_orbiting_planet is not Planet_Sol:
				PointsManager.add_points(1)
		# Tells the planet to run its completion flash animation.
		current_orbiting_planet.flash_orbit_completion()
		orbit_start_angle = last_angle_to_planet
		#current_orbiting_planet.start_orbit_progress_display(self)
		# Gives the player one boost charge.
		BoostCount += 1
		# Plays the collectable sound effect.
		audioHandler.PlaySoundAtGlobalPosition(Sounds.CollectableGet, global_position)
		# Tells the planet to release its collectable to the player.
		current_orbiting_planet.collect_item(self)
		# Adds the collectable's point value to the score.
		#GameManager.add_score(50)

		# Resets the accumulated angle back to zero to start tracking the next loop.
		accumulated_orbit_angle = 0.0

# This function is called by a planet when the player enters its gravity well.
func start_orbiting(planet: BasePlanet):

	if not planet in overlapping_planets:
		overlapping_planets.append(planet)
	
	# The rest of the logic is now handled by the _physics_process loop,
	PointsManager.add_mult(1)
	audioHandler.PlaySoundAtGlobalPosition(Sounds.PingLow, global_position)
	
	# Shows the first-time orbit tutorial if it hasn't been shown yet.
	#if hud:
		#TutorialManager.show_first_orbit_tutorial(hud)
		#TutorialManager.show_orbit_for_extra_boost_tutorial(hud)

# This function is called by a planet when the player leaves its gravity well.
func stop_orbiting(planet: BasePlanet):
	if planet in overlapping_planets:
		overlapping_planets.erase(planet)
		
			
func _notify_strongest_planet_that_we_are_now_orbiting_it(strongest_planet : BasePlanet):
	# Check if the dominant planet has changed.
	if strongest_planet != current_orbiting_planet:
		# If we were orbiting a planet before, stop its indicator.
		if is_instance_valid(current_orbiting_planet):
			current_orbiting_planet.stop_orbit_progress_display()
			
		# Switch focus to the new strongest planet.
		current_orbiting_planet = strongest_planet
		
		# If there is a new planet to orbit, reset the tracking for it.
		if is_instance_valid(current_orbiting_planet):
			# Place to reset all orbit-related state.
			accumulated_orbit_angle = 0.0
			last_angle_to_planet = (global_position - current_orbiting_planet.global_position).angle()
			orbit_start_angle = last_angle_to_planet
			current_skips_available = max_skips_per_orbit
			canSkip = true
			current_orbiting_planet.start_orbit_progress_display(self)
	
	
func _determine_strongest_planet_pull(max_force : float) -> BasePlanet:
		# Iterate through all planets the player is currently inside.
	for planet in overlapping_planets:
		if not is_instance_valid(planet):
			continue
		
		# Calculate the force magnitude for this planet.
		var distance = global_position.distance_to(planet.global_position)
		var radius = planet.collision_shape_2d.shape.radius
		var strength = planet.gravity_strength
		var force = strength * (radius / max(distance, 1.0))

		# If this planet's force is the strongest so far, it becomes the new candidate.
		if force > max_force:
			max_force = force
			return planet
		else:
			return current_orbiting_planet
		
	return null
#endregion

#region Ship actions
		
## Handles the logic for launching the player.
func launch() -> void:
	canSkip = true
	get_tree().create_timer(LAUNCH_COOLDOWN_TIME).timeout.connect(func(): canBoost=true)
	canBoost = false
	# Uses the pre-calculated and stored aim vector.
	var final_pull_vector = _current_aim_pull_vector
	
	# Sets the player's initial velocity based on the stored pull vector and launch power.  THIS IS THE FREAKING LAUNCH CODE
	linear_velocity = final_pull_vector * launch_power * (4.0 if onPlanet else 2.5)
	
	# Changes the state to LAUNCHED.
	current_state = State.LAUNCHED
	# Makes the RigidBody no longer clickable after launch.
	set_pickable(false)
	# Clears the aiming line from the screen.
	aim_manager.reset()
	
	_LaunchParticles.Emit()
	
	# If on the planet and boosting, handles getting off the planet after physics calculations.
	if(onPlanet):
		onPlanet = false
			
	audioHandler.PlaySoundAtGlobalPosition(Sounds.Launch, global_position)

## Applies a one-time boost.
func apply_boost() -> void:
	#Don't boost if you don't have any boosts
	if(BoostCount <= 0):
		return
	# Gets the forward direction of the rocket.
	var boost_direction = Vector2.RIGHT.rotated(rotation)
	# Applies an instant force (impulse) in the forward direction.
	apply_central_impulse(boost_direction * boost_strength)
	# Consumes the boost so it cannot be used again.
	BoostCount -= 1

	# Provides visual feedback that the boost was used.
	_BoostParticles.Emit(true)
	trail_manager.apply_boost_trail_effect()

	camera_2d.Shake()
	audioHandler.PlaySoundAtGlobalPosition(Sounds.Boost, global_position)
	
func land():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	audioHandler.PlaySoundAtGlobalPosition(Sounds.ShipCollide, global_position)
	Reset()
	onPlanet = true

## Resets player state for a new launch or game attempt.
func Reset():
	#Set sprite to blue
	Sprite.frame_coords.y = 0
	#get ready to launch
	current_state = State.READY_TO_AIM
	hud.mobile_controls.set_ready_to_launch(true)
	
	#reset orbit amount
	accumulated_orbit_angle = 0.0
	
	#reset orbits
	current_skips_available = max_skips_per_orbit

	# Resets scoring variables for new attempt.
	PointsManager.reset()

	# Resets boost count to starting amount (including shop upgrades).
	if has_meta("starting_boosts"):
		BoostCount = get_meta("starting_boosts")
	else:
		BoostCount = 3
	
	#resets the known orbited planets
	for planet : BasePlanet in orbited_planets:
		planet.SetShowOrbited(false)
	orbited_planets.clear()
	
	# reset trail effects
	trail_manager.reset_trail_effects()


func Explode(_position : Vector2):
	dead = true
	Sprite.hide()
	$CollisionShape2D.hide()
	linear_damp = 10
	audioHandler.PlaySoundAtGlobalPosition(Sounds.DownUIBeep, global_position)
	get_tree().create_timer(1).timeout.connect(GameManager.show_lose_screen)
	pass
#endregion
	
#region Input handling
func _handle_launch_canceled():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and onPlanet:
		aim_canceled = true
		current_state = State.READY_TO_AIM
		hud.mobile_controls.set_ready_to_launch(false)
		update_aim_line()
		pass

func _handle_launching():
	# Launches on mouse release while AIMING.
	if current_state == State.AIMING and not ((Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or any_fingies_down)):
		# Calls the function to launch the player using the stored aim vector.
		launch()
		hud.mobile_controls.set_ready_to_launch(false)

func _handle_mobile_input():
	if(GameManager.IsMobile):
		if TouchHelper.state.size() == 0 and (mobileBrake):
			mobileBrake = false
	
		if(current_state == State.READY_TO_AIM or current_state == State.AIMING):
			any_fingies_down = TouchHelper.state.size() > 0
		else:
			any_fingies_down = false

		#if TouchHelper.state.size() == 0:
			#singleTouchProcessed = false
			## No touches
				##mobileBrake = false
				##any_fingies_down = false
			#modulate = Color.RED
			
		if (any_fingies_down):
			#if(not singleTouchProcessed):
			# One touch (for aiming/launching)
			var screen_position = TouchHelper.state.values()[0]
			var canvas_transform = get_viewport().get_canvas_transform()
			var world_position = canvas_transform.affine_inverse() * screen_position
			mobilePosition = world_position
	return

func _handle_aiming():
	# Handles left mouse button or single touch for aiming.
	if(not GameManager.IsMobile):
		_handle_mouse_aiming()
	else:
		_handle_figie_aiming()
	_handle_aim_visuals()

func _handle_mouse_aiming():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not aim_canceled:
			if mouseReleased:
				if (current_state == State.LAUNCHED):
					apply_boost()
				else:
					initialClickPos = GetGlobalClickPosition()
				mouseReleased = false
			# Starts aiming only when pressed and from the READY_TO_AIM state.
			if current_state == State.READY_TO_AIM:
				current_state = State.AIMING
				# Immediately updates aim line for visual feedback.
				update_aim_line()
	else:
		if(aim_canceled):
			aim_canceled= false
		mouseReleased = true
		initialClickPos = Vector2.ZERO
	
func _handle_figie_aiming():
	if any_fingies_down:
		if current_state == State.READY_TO_AIM:
			initialClickPos = GetGlobalClickPosition()
			current_state = State.AIMING
			# Immediately updates aim line for visual feedback.
			update_aim_line()
		pass
	if(current_state == State.LAUNCHED and mobileBoost and canBoost):
		apply_boost()
		has_boosted_this_touch = true
		mobileBoost = false

func _handle_aim_visuals():
	
	# Updates the aim line only while AIMING and the mouse button/touch is held.
	if current_state == State.AIMING and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or any_fingies_down):
		# Updates the aim line visuals and _current_aim_pull_vector.
		update_aim_line()
		aim_manager.do_aim_arrow(initialClickPos, GetGlobalClickPosition())
		# Makes the ship face the mouse cursor while aiming.
		var mouse_position = to_local(initialClickPos) - to_local(GetGlobalClickPosition())
		look_at(to_global(mouse_position))
	else:
		aim_manager.reset_aim_arrow()
## This function draws and updates the aiming line.
func update_aim_line() -> void:
	# Calculates the global vector from the player's current position to the current mouse position.
	var pull_vector_from_player_to_mouse = initialClickPos - GetGlobalClickPosition()
	# Clamps the vector's length to the max_pull_distance.
	_current_aim_pull_vector = pull_vector_from_player_to_mouse.limit_length(max_pull_distance)
	aim_manager.draw_aim_line(_current_aim_pull_vector, max_pull_distance)
#endregion

#region Collision (Planets/Asteroids)
func _handle_collision(collision):
	if(collision):
		var collider = collision.get_collider()
		# Checks if the collided object's owner is a planet.
		if collider.owner is BasePlanet:
			if(!onPlanet):
				if collider.owner is HomePlanet:
					_handle_landing_on_shop()
				else:
					_handle_landing_on_planet(collider)
		# Checks if the collided object is an asteroid.
		elif collider is Asteroid:
			_handle_colliding_with_asteroid()

## Handles collision with a home planet (shop).
func _handle_landing_on_shop():
	# Resets the loop counter and clears the trails.
	loopCounter = 0
	trail_manager.reset()
	
	# Calculates the final score upon returning home.
	PointsManager.calculate_final_score()	
	
	land()
	
	# Shows a tutorial about landing to regain boosts.
	#if hud:
		#TutorialManager.show_land_for_boost_tutorial(hud)

## Logic for colliding with a regular planet.
func _handle_landing_on_planet(collider):
	if(current_skips_available > 0) and collider.owner is not Asteroid:
		print("Skip")	
		current_skips_available -= 1
		if(canSkip):
			BoostCount += 1
	
		canSkip = false
		
		PointsManager.multiply_mult(2)
		
		audioHandler.PlaySoundAtGlobalPosition(Sounds.ShipCollide, global_position)
		audioHandler.PlaySoundAtGlobalPosition(Sounds.PingHigh, global_position)
		
	else:
		# This handles crashing into a regular planet.
		loopCounter = 0
		
		trail_manager.reset()
		
		PointsManager.calculate_final_score()
		
		land()

func _handle_colliding_with_asteroid():
	audioHandler.PlaySoundAtGlobalPosition(Sounds.ShipCollide, global_position)
	softlockTimer = null
	isBeingSaved = false
	doNotSave = true

#endregion

#region Helpers

# This is a helper function to correctly calculate the difference between two angles.
func angle_difference(from, to):
	var diff = fmod(to - from + PI, 2 * PI) - PI
	return diff if diff < -PI else fmod(to - from - PI, 2 * PI) + PI
# Gets the global click or touch position.
func GetGlobalClickPosition() -> Vector2:
	if GameManager.IsMobile and TouchHelper.state.values()[0] :
		return mobilePosition
	else:
		return get_global_mouse_position()
#endregion
