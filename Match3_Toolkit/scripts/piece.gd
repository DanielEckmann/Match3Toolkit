extends Node2D

# Basis of Code taken from https://www.youtube.com/watch?v=YhykrMFHOV4&list=PL4vbr3u7UKWqwQlvwvgNcgDL1p_3hcNn2

class_name Piece

enum colors {YELLOW, PINK, ORANGE, LIGHT_GREEN, GREEN, BLUE, NONE}

@export var color: colors
@export var sprite: CompressedTexture2D
@export var health: int
@export var movable: bool

var move_tween
var matched = false
var moved = false
var blocked = false
var shielded = false
var hor_matched = false
var ver_matched = false
var value = 1

var pos
var block_sprite = preload("res://Match 3 Assets/new_obstacles/lock.png")
var shield_sprite = preload("res://Match 3 Assets/new_obstacles/shield.png")
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func set_attributes(color, sprite, health):
	self.color = color
	self.sprite = sprite
	self.health = health
	
	var s = get_node("Sprite2D")
	s.set_texture(sprite)

func set_color(color, sprite):
	self.color = color
	self.sprite = sprite
	
	var s = get_node("Sprite2D")
	s.set_texture(sprite)

func move(target):
	move_tween = self.create_tween()
	move_tween.tween_property(self, "position", target, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	move_tween.play()
	pos = target
	moved = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func take_damage(amount):
	if blocked:
		unblock()
		return
	
	health -= amount
	hor_matched = false
	ver_matched = false
	if health <= 0:
		destroy()

func shield():
	shielded = true
	var s = self.get_node("ShieldSprite")
	s.set_texture(shield_sprite)

func block():
	blocked = true
	movable = false
	var s = self.get_node("BlockSprite")
	s.set_texture(block_sprite)

func unblock():
	blocked = false
	movable = true
	var s = self.get_node("BlockSprite")
	s.set_texture(null)

func _on_adjacent_match():
	pass

func _on_turn_end():
	hor_matched = false
	ver_matched = false

func destroy():
	dim()
	matched = true

func dim():
	var sprite = get_node("Sprite2D")
	sprite.modulate = Color(1, 1, 1, 0.5)
