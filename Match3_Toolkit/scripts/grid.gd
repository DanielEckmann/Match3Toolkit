extends Node2D

# Some of the code taken from https://www.youtube.com/watch?v=YhykrMFHOV4&list=PL4vbr3u7UKWqwQlvwvgNcgDL1p_3hcNn2
# however most of it heavily changed. Where code was taken as-is, it is marked by a comment

enum states {WAIT, MOVE, GAME_OVER}
enum colors {YELLOW, PINK, ORANGE, LIGHT_GREEN, GREEN, BLUE, NONE}
enum bomb_types {HORIZONTAL, VERTICAL, COLOR, RADIUS}

var state

signal score_update(value, color)
signal game_over()
signal grid_empty()
signal reset()

# Control Type
@export var use_collapse: bool

# Grid Variables
@export var width: int
@export var height: int
@export var start: Vector2
@export var offset: int
@export var y_offset: int
@export var use_bombs: bool
@export var use_p_bombs: bool
@export var p_bomb_color: colors
@export var p_bomb_limit: int
@export var no_refill: bool
@export var color_count: int
@export var obstacles: PackedVector2Array
@export var blocked_elements: PackedVector2Array
@export var movable_obstacles: PackedVector2Array
@export var removable_obstacles: PackedVector2Array
@export var growing_obstacles: PackedVector2Array
@export var shielded_pieces: PackedVector2Array
@export var time_bombs: PackedVector2Array
@export var jellyfish: PackedVector2Array

var sprites = [
	preload("res://Match 3 Assets/new_pieces/yellow.png"),
	preload("res://Match 3 Assets/new_pieces/pink.png"),
	preload("res://Match 3 Assets/new_pieces/orange.png"),
	preload("res://Match 3 Assets/new_pieces/light_green.png"),
	preload("res://Match 3 Assets/new_pieces/green.png"),
	preload("res://Match 3 Assets/new_pieces/blue.png")
]

var bomb_sprites = [
	preload("res://Match 3 Assets/new_pieces/yellow_row.png"),
	preload("res://Match 3 Assets/new_pieces/yellow_column.png"),
	preload("res://Match 3 Assets/new_pieces/yellow_color.png"),
	preload("res://Match 3 Assets/new_pieces/yellow_radius.png"),
	preload("res://Match 3 Assets/new_pieces/pink_row.png"),
	preload("res://Match 3 Assets/new_pieces/pink_column.png"),
	preload("res://Match 3 Assets/new_pieces/pink_color.png"),
	preload("res://Match 3 Assets/new_pieces/pink_radius.png"),
	preload("res://Match 3 Assets/new_pieces/orange_row.png"),
	preload("res://Match 3 Assets/new_pieces/orange_column.png"),
	preload("res://Match 3 Assets/new_pieces/orange_color.png"),
	preload("res://Match 3 Assets/new_pieces/orange_radius.png"),
	preload("res://Match 3 Assets/new_pieces/light_green_row.png"),
	preload("res://Match 3 Assets/new_pieces/light_green_column.png"),
	preload("res://Match 3 Assets/new_pieces/light_green_color.png"),
	preload("res://Match 3 Assets/new_pieces/light_green_radius.png"),
	preload("res://Match 3 Assets/new_pieces/green_row.png"),
	preload("res://Match 3 Assets/new_pieces/green_column.png"),
	preload("res://Match 3 Assets/new_pieces/green_color.png"),
	preload("res://Match 3 Assets/new_pieces/green_radius.png"),
	preload("res://Match 3 Assets/new_pieces/blue_row.png"),
	preload("res://Match 3 Assets/new_pieces/blue_column.png"),
	preload("res://Match 3 Assets/new_pieces/blue_color.png"),
	preload("res://Match 3 Assets/new_pieces/blue_radius.png")
]

var piece_prefab = preload("res://scenes/pieces/piece.tscn")
var bomb_prefab = preload("res://scenes/pieces/gadgets/bomb.tscn")
var obstacle_prefab = preload("res://scenes/pieces/obstacles/obstacle.tscn")
var grow_obstacle_prefab = preload("res://scenes/pieces/obstacles/growing_obstacle.tscn")
var move_obstacle_prefab = preload("res://scenes/pieces/obstacles/movable_obstacle.tscn")
var remove_obstacle_prefab = preload("res://scenes/pieces/obstacles/removable_obstacle.tscn")
var timebomb_prefab = preload("res://scenes/pieces/obstacles/time_bomb.tscn")
var jellyfish_prefab = preload("res://scenes/pieces/gadgets/jellyfish.tscn")
var bomb_dict = {}
var grow_obs_list = []
var grow_obs_destroyed = false
class Tile_data:
	var pos: Vector2
	var color: colors
	
	func _init(p, c):
		pos = p
		color = c


var total_time = 0.0
var time_between_turns = []
var curr_turn_time = 0.0
var total_moves = 0
var successful = false
var curr_goal = "score"

var all_pieces = []

var game_start = true
var p_bomb_used = false

# touch variables
var first_touch = Vector2(0, 0)
var final_touch = Vector2(0, 0)
var controlling = false

"""SYSTEM FUNCTIONS"""
# Called when the node enters the scene tree for the first time.
func _ready():
	state = states.WAIT
	game_start = true
	all_pieces = make_2d_array()
	spawn_pieces()
	game_start = false
	state = states.MOVE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	total_time += delta
	curr_turn_time += delta

# This function was taken from source outlined at the top
func _input(event):
	if Input.is_action_just_pressed("right_click") && use_p_bombs:
		if !p_bomb_used && state == states.MOVE && is_in_grid(pixel_to_grid(get_global_mouse_position())):
			paint_bomb(pixel_to_grid(get_global_mouse_position()), p_bomb_color)
	
	if Input.is_action_just_pressed("ui_touch"):
		if state == states.MOVE && is_in_grid(pixel_to_grid(get_global_mouse_position())):
			controlling = true
			first_touch = get_global_mouse_position()
			if use_collapse:
				collapse_position(pixel_to_grid(first_touch))
		else:
			controlling = false
	
	if Input.is_action_just_released("ui_touch"):
		if state == states.MOVE && (is_in_grid(pixel_to_grid(get_global_mouse_position())) && controlling):
			controlling = false
			final_touch = get_global_mouse_position()
			if !use_collapse:
				touch_difference(pixel_to_grid(first_touch), pixel_to_grid(final_touch))

"""INPUT FUNCTIONS"""

func collapse_position(pos):
	state = states.WAIT
	
	var piece = all_pieces[pos.x][pos.y]
	if piece == null:
		state = states.MOVE
		return
	if !piece.movable || piece.color == colors.NONE:
		state = states.MOVE
		return
	var visited_pieces = []
	var queue = []
	var shape = []
	queue.push_back(piece)
	visited_pieces.append(piece)
	
	while !queue.is_empty():
		var curr = queue.pop_front()
		shape.append(curr)
		var neighbors = get_neighbors(pixel_to_grid(curr.pos), false)
		if neighbors != null:
			for n in neighbors:
				if n.color == curr.color && !visited_pieces.has(n):
					queue.push_back(n)
					visited_pieces.append(n)
	
	var tile = shape[shape.size()/2]
	if shape.size() >= 5:
		bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.COLOR
	elif shape.size() >= 4:
		bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.VERTICAL
	
	for p in shape:
		var neighbors = get_neighbors(pixel_to_grid(p.pos), false)
		if neighbors != null:
			for n in neighbors:
				n._on_adjacent_match()
	damage(shape)
	get_parent().get_node("destroy_timer").start()

# This function was taken from source outlined at the top
func touch_difference(pos_1, pos_2):
	var diff = pos_2 - pos_1
	if abs(diff.x) > abs(diff.y):
		if diff.x > 0:
			swap_pieces(pos_1, Vector2.RIGHT)
		elif diff.x < 0:
			swap_pieces(pos_1, Vector2.LEFT)
	elif abs(diff.y) > abs(diff.x):
		# Vector UP is (0, -1) and DOWN is (0, 1), so a bit of confusing naming
		if diff.y > 0:
			swap_pieces(pos_1, Vector2.DOWN)
		elif diff.y < 0:
			swap_pieces(pos_1, Vector2.UP)

# This function was taken from source outlined at the top
func swap_pieces(loc, dir):
	var first_piece = all_pieces[loc.x][loc.y]
	var other_piece = all_pieces[loc.x + dir.x][loc.y + dir.y]
	
	if(first_piece == null || other_piece == null) || (!first_piece.movable || !other_piece.movable):
		return
	
	if first_piece.blocked || other_piece.blocked:
		return
	
	state = states.WAIT
	
	all_pieces[loc.x][loc.y] = other_piece
	all_pieces[loc.x + dir.x][loc.y + dir.y] = first_piece
	
	first_piece.move(grid_to_pixel(loc.x + dir.x, loc.y + dir.y))
	other_piece.move(grid_to_pixel(loc.x, loc.y))
	
	if !find_matches():
		all_pieces[loc.x][loc.y] = first_piece
		all_pieces[loc.x + dir.x][loc.y + dir.y] = other_piece
	
		other_piece.move(grid_to_pixel(loc.x + dir.x, loc.y + dir.y))
		first_piece.move(grid_to_pixel(loc.x, loc.y))
		
		state = states.MOVE

func paint_bomb(pos, color):
	if p_bomb_limit <= 0:
		return
	
	var neighbors = get_neighbors(pos, false)
	for n in neighbors:
		n.set_color(color, sprites[color])
	all_pieces[pos.x][pos.y].set_color(color, sprites[color])
	
	p_bomb_used = true
	p_bomb_limit -= 1

"""GAME FUNCTIONS"""

# This was originally adapted from the source above, but heavily changed
func spawn_pieces():
	if game_start:
		var type_arr = []
		for k in range (0, color_count):
			type_arr.append(k)
		
		for o in obstacles:
			var obstacle = obstacle_prefab.instantiate()
			add_child(obstacle)
			obstacle.set_position(grid_to_pixel(o.x, o.y + y_offset))
			obstacle.move(grid_to_pixel(o.x, o.y))
			all_pieces[o.x][o.y] = obstacle
		
		for o in movable_obstacles:
			var obstacle = move_obstacle_prefab.instantiate()
			add_child(obstacle)
			obstacle.set_position(grid_to_pixel(o.x, o.y + y_offset))
			obstacle.move(grid_to_pixel(o.x, o.y))
			all_pieces[o.x][o.y] = obstacle
		
		for o in removable_obstacles:
			var obstacle = remove_obstacle_prefab.instantiate()
			add_child(obstacle)
			obstacle.set_position(grid_to_pixel(o.x, o.y + y_offset))
			obstacle.move(grid_to_pixel(o.x, o.y))
			all_pieces[o.x][o.y] = obstacle
		
		for o in growing_obstacles:
			var obstacle = grow_obstacle_prefab.instantiate()
			add_child(obstacle)
			obstacle.set_position(grid_to_pixel(o.x, o.y + y_offset))
			obstacle.move(grid_to_pixel(o.x, o.y))
			all_pieces[o.x][o.y] = obstacle
		
		for b in time_bombs:
			randomize()
			type_arr.shuffle()
			var type = type_arr[0]
			var bomb = timebomb_prefab.instantiate()
			add_child(bomb)
			bomb.set_attributes(type, sprites[type], 1)
			bomb.set_position(grid_to_pixel(b.x, b.y + y_offset))
			bomb.move(grid_to_pixel(b.x, b.y))
			all_pieces[b.x][b.y] = bomb
		
		for i in width:
			for j in height:
				if all_pieces[i][j] != null:
					continue
				# choose random number
				randomize()
				type_arr.shuffle()
				
				var pos = 0
				var type = type_arr[pos]
				
				while (match_at(i, j, type) && pos < type_arr.size() - 1):
					pos += 1
					type = type_arr[pos]
					
				# instantiate piece
				var piece
				piece = piece_prefab.instantiate()
				add_child(piece)
				piece.set_attributes(type, sprites[type], 1)
				piece.set_position(grid_to_pixel(i, j + y_offset))
				piece.move(grid_to_pixel(i, j))
				all_pieces[i][j] = piece
		
		for j in jellyfish:
			var type = all_pieces[j.x][j.y].color
			var jelly = jellyfish_prefab.instantiate()
			add_child(jelly)
			jelly.set_attributes(type, sprites[type], 1)
			jelly.set_position(grid_to_pixel(j.x, j.y + y_offset))
			jelly.move(grid_to_pixel(j.x, j.y))
			if all_pieces[j.x][j.y] != null:
				all_pieces[j.x][j.y].queue_free()
			all_pieces[j.x][j.y] = jelly
		
		for i in width:
			for j in height:
				all_pieces[i][j].moved = false
		
		for b in blocked_elements:
			all_pieces[b.x][b.y].block()
		
		for b in shielded_pieces:
			all_pieces[b.x][b.y].shield()
	else:
		var type_arr = []
		for k in range (0, color_count):
			type_arr.append(k)
		
		var spawned_pieces = []
		
		for i in width:
			for j in height:
				if all_pieces[i][j] != null:
					continue
				# choose random number
				randomize()
				type_arr.shuffle()
				
				var type = type_arr[0]
				
				# instantiate piece
				var piece = piece_prefab.instantiate()
				add_child(piece)
				spawned_pieces.append(piece)
				piece.set_attributes(type, sprites[type], 1)
				piece.set_position(grid_to_pixel(i, j + y_offset))
				piece.move(grid_to_pixel(i, j))
				all_pieces[i][j] = piece
		
		if !find_matches():
			turn_end()

func find_matches():
	var matches = get_shapes()
	if matches == null:
		return false
	var horizontal_matches = matches.horizontal
	var vertical_matches = matches.vertical
	var matched_pieces = []
	
	for m in horizontal_matches:
		var is_radius_bomb = false
		for p in m:
			if !matched_pieces.has(p):
				matched_pieces.append(p)
			if p.hor_matched && p.ver_matched:
				is_radius_bomb = determine_radius_bomb(p)
		
		if is_radius_bomb:
			continue
		
		var tile = m[m.size()/2]
		if m.size() >= 5:
			bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.COLOR
		elif m.size() >= 4:
			bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.VERTICAL
	
	for m in vertical_matches:
		var is_radius_bomb = false
		for p in m:
			if !matched_pieces.has(p):
				matched_pieces.append(p)
			if p.hor_matched && p.ver_matched:
				is_radius_bomb = determine_radius_bomb(p)
		
		if is_radius_bomb:
			continue
		
		var tile = m[m.size()/2]
		if m.size() >= 5:
			bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.COLOR
		elif m.size() >= 4:
			bomb_dict[Tile_data.new(tile.pos, tile.color)] = bomb_types.HORIZONTAL
	
	for p in matched_pieces:
		var neighbors = get_neighbors(pixel_to_grid(p.pos), false)
		for n in neighbors:
			n._on_adjacent_match()
	damage(matched_pieces)
	get_parent().get_node("destroy_timer").start()
	return true

# This function was taken from source outlined at the top
func match_at(column, row, type):
	# this function checks if a match is created on initial generation of the board only
	if column > 1:
		if (all_pieces[column - 1][row].color == type && all_pieces[column - 2][row].color == type):
			return true
	if row > 1:
		if (all_pieces[column][row - 1].color == type && all_pieces[column][row - 2].color == type):
			return true
	return false

func turn_end():
	state = states.MOVE
	p_bomb_used = false
	var grid_empty = true
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				all_pieces[i][j]._on_turn_end()
				grid_empty = false
	
	grow_obstacles()
	grow_obs_list = []
	
	grow_obs_destroyed = false
	
	total_moves += 1
	time_between_turns.append(curr_turn_time)
	curr_turn_time = 0.0
	
	if grid_empty:
		emit_signal("grid_empty")

func damage(array):
	for i in array:
		if !i.shielded:
			i.take_damage(1)

# This function was taken from source outlined at the top
func destroy_matched():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				if all_pieces[i][j].matched:
					emit_signal("score_update", all_pieces[i][j].value, all_pieces[i][j].color)
					all_pieces[i][j].queue_free()
	
	spawn_bombs()
	get_parent().get_node("collapse_timer").start()

# This function was taken from source outlined at the top
func collapse_columns():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null:
				for k in range(j + 1, height):
					if all_pieces[i][k] != null && all_pieces[i][k].movable:
						all_pieces[i][k].move(grid_to_pixel(i, j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	
	if no_refill:
		if !find_matches():
			turn_end()
		return
	get_parent().get_node("refill_timer").start()

func spawn_bombs():
	if !use_bombs:
		return
	
	for t in bomb_dict.keys():
		instantiate_bomb(t.pos, t.color, bomb_dict[t])
	bomb_dict.clear()

func grow_obstacles():
	#for p in grow_obs_list:
		#instantiate_growing_obstacle(p)
	if grow_obs_list.is_empty() || grow_obs_destroyed:
		return
	grow_obs_list.shuffle()
	var o = grow_obs_list[0]
	instantiate_growing_obstacle(o)

func determine_radius_bomb(piece):
	var horizontal_match = []
	var vertical_match = []
	
	var queue = []
	queue.push_back(piece)
	
	while !queue.is_empty():
		var t = queue.pop_front()
		if t.color == piece.color:
			if t != piece:
				horizontal_match.append(t)
			for n in get_horizontal_neighbors(pixel_to_grid(t.pos)):
				if !horizontal_match.has(n) && n != piece:
					queue.push_back(n)
	
	queue = []
	queue.push_back(piece)
	
	while !queue.is_empty():
		var t = queue.pop_front()
		if t.color == piece.color:
			if t != piece:
				vertical_match.append(t)
			for n in get_vertical_neighbors(pixel_to_grid(t.pos)):
				if !vertical_match.has(n) && n != piece:
					queue.push_back(n)
	
	var horizontal_count = horizontal_match.size() + 1 # adding 1 because center is not in list
	var vertical_count = vertical_match.size() + 1
	
	if horizontal_count >= 5:
		return false
	if vertical_count >= 5:
		return false
	
	bomb_dict[Tile_data.new(piece.pos, piece.color)] = bomb_types.RADIUS
	return true

func instantiate_bomb(pos, color, type):
	var piece_pos = pixel_to_grid(pos)
	if all_pieces[piece_pos.x][piece_pos.y] != null:
		if all_pieces[piece_pos.x][piece_pos.y].is_in_group("bomb"):
			return
	var bomb = bomb_prefab.instantiate()
	add_child(bomb)
	var sprite_pos = color * 4 + type
	bomb.set_attributes(color, bomb_sprites[sprite_pos], 1)
	bomb.set_type(type)
	bomb.set_position(pos)
	bomb.move(pos)
	if all_pieces[piece_pos.x][piece_pos.y] != null:
		all_pieces[piece_pos.x][piece_pos.y].destroy()
		all_pieces[piece_pos.x][piece_pos.y].queue_free()
	all_pieces[piece_pos.x][piece_pos.y] = bomb

func instantiate_growing_obstacle(pos):
	var obs = grow_obstacle_prefab.instantiate()
	add_child(obs)
	obs.set_position(pos)
	obs.move(pos)
	var piece_pos = pixel_to_grid(pos)
	if all_pieces[piece_pos.x][piece_pos.y] != null:
		all_pieces[piece_pos.x][piece_pos.y].destroy()
		all_pieces[piece_pos.x][piece_pos.y].queue_free()
	all_pieces[piece_pos.x][piece_pos.y] = obs

func end_game():
	state = states.GAME_OVER
	emit_signal("game_over")
	Engine.time_scale = 0.0
	
	var score = $"../top_ui/ScoreLabel".get_score()
	var csv_line = PackedStringArray(["%f" % total_time, "%f" % mean(time_between_turns), "%d" % total_moves, "%d" % score, curr_goal, successful])
	var f = FileAccess.open("./tests/tests.csv", FileAccess.READ_WRITE)
	f.seek_end(0)
	f.store_csv_line(csv_line)
	f.close()

func reset_game():
	state = states.WAIT
	p_bomb_used = false
	p_bomb_limit = 3
	controlling = false
	successful = false
	total_moves = 0
	total_time = 0.0
	time_between_turns.clear()
	curr_turn_time = 0.0
	emit_signal("reset")
	Engine.time_scale = 1.0
	for n in get_children():
		remove_child(n)
		n.queue_free()
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				all_pieces[i][j].queue_free()
	game_start = true
	all_pieces = make_2d_array()
	spawn_pieces()
	game_start = false
	state = states.MOVE
	get_parent().get_node("gameover_timer").start()

"""HELPER FUNCTIONS"""

func mean(array):
	var mean = 0.0
	for i in array:
		mean += i
	mean = mean / array.size()
	return mean

func is_null(array):
	for i in array:
		if i == null:
			return true
	return false

# This function was taken from source outlined at the top
func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
			
	return array

# This function was taken from source outlined at the top
func grid_to_pixel(column, row):
	var new_x = start.x + offset * column
	var new_y = start.y - offset * row
	
	return Vector2(new_x, new_y)

# This function was taken from source outlined at the top
func pixel_to_grid(pixel_coords):
	var new_x = round((pixel_coords.x - start.x) / offset)
	var new_y = round((pixel_coords.y - start.y) / -offset)
	
	return Vector2(new_x, new_y)

# This function was taken from source outlined at the top
func is_in_grid(pos):
	if pos.x >= 0 && pos.x < width:
		if pos.y >= 0 && pos.y < height:
			return true
	return false

"""GETTER FUNCTIONS"""

func get_shapes():
	var checked_pieces = []
	var horizontal_matches = []
	var vertical_matches = []
	
	for i in width:
		for j in height:
			var piece = all_pieces[i][j]
			if all_pieces[i][j] == null || all_pieces[i][j].shielded:
				continue
			if checked_pieces.has(piece) || piece.color == colors.NONE:
				continue
			var queue = []
			var shape = []
			var visited = []
			queue.push_back(piece)
			visited.append(piece)
			
			while !queue.is_empty():
				var curr = queue.pop_front()
				shape.append(curr)
				var neighbors = get_horizontal_neighbors(pixel_to_grid(curr.pos))
				if neighbors != null:
					for n in neighbors:
						if n.color == curr.color && !visited.has(n) && !n.shielded:
							queue.push_back(n)
							visited.append(n)
			
			if shape.size() >= 3:
				horizontal_matches.append(shape)
				for p in shape:
					p.hor_matched = true
					if !checked_pieces.has(p):
						checked_pieces.append(p)
			
			shape = []
			visited = []
			queue.push_back(piece)
			visited.append(piece)
			
			while !queue.is_empty():
				var curr = queue.pop_front()
				shape.append(curr)
				var neighbors = get_vertical_neighbors(pixel_to_grid(curr.pos))
				if neighbors != null:
					for n in neighbors:
						if n.color == curr.color && !visited.has(n) && !n.shielded:
							queue.push_back(n)
							visited.append(n)
			
			if shape.size() >= 3:
				vertical_matches.append(shape)
				for p in shape:
					p.ver_matched = true
					if !checked_pieces.has(p):
						checked_pieces.append(p)
	if horizontal_matches.is_empty() && vertical_matches.is_empty():
		return null
	
	return {"horizontal":horizontal_matches, "vertical":vertical_matches}

func get_neighbors(pos, get_diagonal):
	var neighbors = []
	if pos.x + 1 < width:
		if all_pieces[pos.x + 1][pos.y] != null:
			neighbors.append(all_pieces[pos.x + 1][pos.y])
	if pos.x - 1 >= 0:
		if all_pieces[pos.x - 1][pos.y] != null:
			neighbors.append(all_pieces[pos.x - 1][pos.y])
	if pos.y + 1 < height:
		if all_pieces[pos.x][pos.y + 1] != null:
			neighbors.append(all_pieces[pos.x][pos.y + 1])
	if pos.y - 1 >= 0:
		if all_pieces[pos.x][pos.y - 1] != null:
			neighbors.append(all_pieces[pos.x][pos.y - 1])
	
	if get_diagonal:
		if pos.x + 1 < width && pos.y + 1 < height:
			if all_pieces[pos.x + 1][pos.y + 1] != null:
				neighbors.append(all_pieces[pos.x + 1][pos.y + 1])
		if pos.x + 1 < width && pos.y - 1 >= 0:
			if all_pieces[pos.x + 1][pos.y - 1] != null:
				neighbors.append(all_pieces[pos.x + 1][pos.y - 1])
		if pos.x - 1 >= 0 && pos.y + 1 < height:
			if all_pieces[pos.x - 1][pos.y + 1] != null:
				neighbors.append(all_pieces[pos.x - 1][pos.y + 1])
		if pos.x - 1 >= 0 && pos.y - 1 >= 0:
			if all_pieces[pos.x - 1][pos.y - 1] != null:
				neighbors.append(all_pieces[pos.x - 1][pos.y - 1])
	
	if !neighbors.is_empty():
		return neighbors
	
	return null

func get_horizontal_neighbors(pos):
	var neighbors = []
	if pos.x + 1 < width:
		if all_pieces[pos.x + 1][pos.y] != null:
			neighbors.append(all_pieces[pos.x + 1][pos.y])
	if pos.x - 1 >= 0:
		if all_pieces[pos.x - 1][pos.y] != null:
			neighbors.append(all_pieces[pos.x - 1][pos.y])
	
	if !neighbors.is_empty():
		return neighbors
	
	return null

func get_vertical_neighbors(pos):
	var neighbors = []
	if pos.y + 1 < height:
		if all_pieces[pos.x][pos.y + 1] != null:
			neighbors.append(all_pieces[pos.x][pos.y + 1])
	if pos.y - 1 >= 0:
		if all_pieces[pos.x][pos.y - 1] != null:
			neighbors.append(all_pieces[pos.x][pos.y - 1])
	
	if !neighbors.is_empty():
		return neighbors
	
	return null

"""SIGNAL FUNCTIONS"""

func _on_grow_obstacle(pos):
	var neighbors = get_neighbors(pixel_to_grid(pos), false)
	if neighbors == null:
		return
	neighbors.shuffle()
	var to_replace
	# This is stupid, but godot wont let me do neighbors[0]
	for n in neighbors:
		if n.color == colors.NONE:
			return
		to_replace = n
		break
	
	grow_obs_list.append(to_replace.pos)

func _on_grow_obstacle_destroyed():
	grow_obs_destroyed = true

func _on_bomb_destroyed(position, type, color):
	var pos = pixel_to_grid(position)
	
	if type == bomb_types.HORIZONTAL:
		for i in width:
			all_pieces[i][pos.y].destroy()
	elif type == bomb_types.VERTICAL:
		for j in height:
			all_pieces[pos.x][j].destroy()
	elif type == bomb_types.COLOR:
		for i in width:
			for j in height:
				if all_pieces[i][j].color == color:
					all_pieces[i][j].destroy()
	elif type == bomb_types.RADIUS:
		var neighbors = get_neighbors(pos, true)
		if neighbors != null:
			for p in neighbors:
				p.destroy()

func _on_destroy_timer_timeout():
	destroy_matched()

func _on_collapse_timer_timeout():
	collapse_columns()

func _on_refill_timer_timeout():
	spawn_pieces()

func _on_reset_button_pressed():
	reset_game()

func _on_goal_counter_end_game(goal_type, success):
	successful = success
	match goal_type:
		0:
			curr_goal = "score"
		1:
			curr_goal = "clear"
		2:
			curr_goal = "res clear"
	end_game()
