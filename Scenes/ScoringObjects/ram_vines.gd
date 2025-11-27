extends StaticBody2D
class_name Chain

@export var start_point : Vector2
@export var endpoint : Vector2
@onready var pin_joint: PinJoint2D = $PinJoint2D


@export_range(0, 1, 0.01) var additional_links_percent : float = 0.05

@export var chain_object : PackedScene


@onready var endpoint_body: StaticBody2D = $Endpoint


#
#func _ready():
	#setup(start_point, endpoint)

func setup(pos1 : Vector2, pos2 : Vector2):
	
	global_position = pos1
	endpoint_body.global_position = pos2
	
	var target_dist : float = pos1.distance_to(pos2)
	
	var target_rotation : float = (pos2 - pos1).angle()
	
	var accumulated_dist : float = 0
	
	var first_link : ChainLink = chain_object.instantiate()
	first_link.global_position = to_local(global_position)
	accumulated_dist += first_link.pin_joint.position.length()
	first_link.rotation = target_rotation - deg_to_rad(90)
	
	target_dist *= 1+additional_links_percent
	
	add_child(first_link)
	
	pin_joint.node_b = first_link.get_path()
	
	var previous_link : ChainLink = first_link
	
	var links : Array[ChainLink] = []
	
	while accumulated_dist < target_dist:
		var link : ChainLink = chain_object.instantiate()
		accumulated_dist += link.pin_joint.position.length()
		
		link.global_position = to_local(previous_link.pin_joint.global_position)
		link.rotation = target_rotation - deg_to_rad(90)
		
		
		#spawn_pos = (link.pin_joint.global_position)
		add_child(link)
		
		
		
		link.freeze = true
		previous_link.setup_pin(link)
		link.freeze = false
		previous_link = link
		links.append(link)
	
	#move to also move attached pin joint
	previous_link.global_position = endpoint_body.global_position
	
	#calculate based on pin joint
	var backpedal : Vector2 = endpoint_body.global_position - previous_link.pin_joint.global_position
	#set actual end pos
	previous_link.global_position+=backpedal
	previous_link.setup_pin(endpoint_body)
	
	@warning_ignore("integer_division")
	links[links.size()/2].apply_torque_impulse(500)
	
	for link in links:
		link.linear_velocity = Vector2.ZERO
		link.angular_velocity = 0
	
	pass
