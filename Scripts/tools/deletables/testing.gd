extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Biome.generate_level()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if(Input.is_action_just_pressed("DEBUG-RESET_LAUNCH")):
		for child in $Biome.get_children():
			child.queue_free()
		$Biome.generate_level()
	
	pass
