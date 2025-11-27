extends RigidBody2D
class_name ChainLink

@export var pin_joint: PinJoint2D 
@onready var sprite: Sprite2D = $Sprite2D
@onready var vines_cut_particles: ParticleEffect = $VinesCutParticles

@export var next_segment : PhysicsBody2D
@export var destroy_threshold : float = 4000
@export var impenetrable : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pin_joint.node_a = self.get_path()
	if(next_segment):
		pin_joint.node_b = next_segment.get_path()
	
	sprite.flip_h = randi() % 2
	sprite.flip_v = randi() % 2
	
	body_entered.connect(try_destroy)
	pass # Replace with function body.

func try_destroy(body : Node):
	if(body is not Player):
		return
	
	#don't even try if there's no shot
	if(impenetrable):
		return
	
	var player = body as Player
	var vel = player.linear_velocity
	if(vel.length() > destroy_threshold):
		queue_free()
		vines_cut_particles.Emit()
		vines_cut_particles.reparent(get_parent())
		#player.linear_velocity = vel
	
func setup_pin(body : PhysicsBody2D):
	next_segment = body
	pin_joint.node_a = self.get_path()
	pin_joint.node_b = body.get_path()
