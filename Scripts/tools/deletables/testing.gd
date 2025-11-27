extends Node2D

const PLANET_MEDIUM = preload("uid://vuorl2ga7vdk")
const PLANET_LARGE = preload("uid://h0vfnklanw5d")
@onready var destroy_vines: Chain = $Destroy_Vines

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var med = PLANET_MEDIUM.instantiate()
	med.global_position = Vector2((randf() - randf())  * 15000, (randf() - randf())  * 15000)
	add_child(med)
	
	var large = PLANET_LARGE.instantiate()
	large.global_position = Vector2((randf() - randf())  * 15000, (randf() - randf())  * 15000)
	add_child(large)
	
	destroy_vines.setup(med.global_position, large.global_position)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
