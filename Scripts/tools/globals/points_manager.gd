extends Node
class_name Manager_Points

# Scoring system variables
var points : int = 0  # Points earned from orbiting planets
var mult : int = 0    # Multiplier from entering gravity fields and skips
var final_score : int = 0  # Calculated when crashing
var spawnpoint : Marker2D
@onready var audio_handler: PlayerAudioHandler = $PlayerAudioHandler

func setup(points_spawnpoint : Marker2D):
	spawnpoint = points_spawnpoint

# Calculates final score when crashing
func calculate_final_score() -> void:
	final_score = points * mult
	print("Final Score Calculation: ", points, " points * ", mult, " mult = ", final_score)
	# Use the animated score addition instead of regular add_score
	GameManager.process_final_score(final_score, spawnpoint.global_position)
	
	#also display the green number
	PointNumbers.display_number(final_score, spawnpoint.global_position, 2, -1)
	
	
	if(final_score == 0):
		audio_handler.PlaySoundAtGlobalPosition(Sounds.ShipCrash, spawnpoint.global_position)
	else:
		audio_handler.PlaySoundAtGlobalPosition(Sounds.GetPOints, spawnpoint.global_position)
		

func add_points(_points : int):
	PointNumbers.display_number(points, spawnpoint.global_position, 1)
	points += _points

func mult_points(_points : int):
	PointNumbers.display_number(points, spawnpoint.global_position, 1)
	points *= _points

func add_mult(_mult : int):
	PointNumbers.display_number(mult, spawnpoint.global_position, 1)
	mult += _mult

func multiply_mult(_mult : int):
	PointNumbers.display_number(mult, spawnpoint.global_position, 1)
	mult *= _mult

func reset():
	points = 0
	mult = 1
	final_score = 0
