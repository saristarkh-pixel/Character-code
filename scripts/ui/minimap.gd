extends Control
# the level map. one script, two views:
# - the corner map: a square that follows the player at full detail. places
#   off the edge are pinned to the border so you can still tell which way
#   they are.
# - the full map (full = true): the whole level shrunk to fit the screen,
#   over a dim, toggled with M.
# the ground is drawn from the real tile art, a few pixels per cell, flips
# and all. the player and the places that matter are their own sprites, and
# the player's icon copies whatever frame the player is showing.
# the level calls setup() on the corner map; the full map borrows everything
# from it through share().

# map pixels per terrain cell. the tile art is shrunk from 16 to this.
const TEXELS: int = 4

# the baked map outlives the level, so the reload between days doesn't
# redraw 40,000 tiles every time. the map never changes while the game runs.
static var baked: ImageTexture
static var baked_rect: Rect2i

@export var full: bool = false
# the gap between the frame and the map
@export var padding: float = 6.0
@export var frame_width: float = 3.0
# icon sizes against their sprites. true size on this map would be 0.25,
# which leaves the player a few pixels tall.
@export var player_icon_scale: float = 0.5
# how much room the full map leaves around itself
@export var full_margin: Vector2 = Vector2(80, 110)
# colours from the art: the hive for the frame, the two skies behind the
# ground, the rocket hull for the caption
@export var frame_color: Color = Color(0.51, 0.294, 0.141, 1)
@export var sky_day: Color = Color(0.455, 0.729, 0.961, 1)
@export var sky_night: Color = Color(0.075, 0.09, 0.188, 1)
@export var dim_color: Color = Color(0, 0, 0, 0.6)
@export var caption_color: Color = Color(0.976, 0.859, 0.576, 1)

var terrain: TileMapLayer
var player: Node2D
var used: Rect2i
var texture: ImageTexture
# pairs of [node, icon scale]. nodes that have been freed are skipped. the
# full map holds the same array, so markers only need adding in one place.
var markers: Array = []

func _ready() -> void:
	hide()
	# icons are shrunk, and the full map's ground too, so both are smoothed
	# rather than dropping every other pixel. the corner map's ground is drawn
	# 1:1 on whole pixels, so smoothing leaves it untouched.
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func setup(level_terrain: TileMapLayer, level_player: Node2D) -> void:
	terrain = level_terrain
	player = level_player
	used = terrain.get_used_rect()
	if baked == null or baked_rect != used:
		baked = _bake()
		baked_rect = used
	texture = baked
	show()

func share(other: Control) -> void:
	terrain = other.terrain
	player = other.player
	used = other.used
	texture = other.texture
	markers = other.markers

func add_marker(node: Node2D, icon_scale: float = 0.5) -> void:
	markers.append([node, icon_scale])

func clear_markers() -> void:
	markers.clear()

# every cell gets its tile, turned the way the map has it and shrunk to
# TEXELS square. shrunk tiles are cached, there are only a few dozen kinds.
func _bake() -> ImageTexture:
	var image := Image.create_empty(used.size.x * TEXELS, used.size.y * TEXELS, false, Image.FORMAT_RGBA8)
	var small: Dictionary = {}
	var sheets: Dictionary = {}
	var box := Rect2i(0, 0, TEXELS, TEXELS)
	for cell: Vector2i in terrain.get_used_cells():
		var source_id: int = terrain.get_cell_source_id(cell)
		var coords: Vector2i = terrain.get_cell_atlas_coords(cell)
		var alternative: int = terrain.get_cell_alternative_tile(cell)
		var key: Vector3i = Vector3i(source_id, coords.x + coords.y * 256, alternative)
		if not small.has(key):
			if not sheets.has(source_id):
				var source: TileSetAtlasSource = terrain.tile_set.get_source(source_id)
				sheets[source_id] = [source, source.texture.get_image()]
			small[key] = _shrink_tile(sheets[source_id][0], sheets[source_id][1], coords, alternative)
		image.blit_rect(small[key], box, (cell - used.position) * TEXELS)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _shrink_tile(source: TileSetAtlasSource, sheet: Image, coords: Vector2i, alternative: int) -> Image:
	var tile: Image = sheet.get_region(source.get_tile_texture_region(coords))
	tile.convert(Image.FORMAT_RGBA8)
	# godot turns a tile by transposing it first, then flipping. a clockwise
	# quarter turn plus a horizontal flip is a transpose.
	if alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE:
		tile.rotate_90(CLOCKWISE)
		tile.flip_x()
	if alternative & TileSetAtlasSource.TRANSFORM_FLIP_V:
		tile.flip_y()
	if alternative & TileSetAtlasSource.TRANSFORM_FLIP_H:
		tile.flip_x()
	# halving at a time averages whole blocks, so thin grass edges survive
	var width: int = tile.get_width()
	while width > TEXELS:
		width = maxi(width / 2, TEXELS)
		tile.resize(width, width, Image.INTERPOLATE_BILINEAR)
	return tile

# M opens and closes the full map. the game keeps running underneath, so it
# is no way to stop the chase clock.
func _unhandled_input(event: InputEvent) -> void:
	if full and texture and event.is_action_pressed("map"):
		visible = not visible
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if texture and visible:
		queue_redraw()

func _draw() -> void:
	if not texture:
		return
	var map_size: Vector2 = Vector2(texture.get_size())
	# inner is where the map lands on screen, view is which part of it shows
	var inner: Rect2
	var view: Rect2
	if full:
		draw_rect(Rect2(Vector2.ZERO, size), dim_color)
		var room: Vector2 = size - full_margin * 2.0
		var fit: float = minf(room.x / map_size.x, room.y / map_size.y)
		var shown: Vector2 = (map_size * fit).floor()
		inner = Rect2(((size - shown) * 0.5).floor(), shown)
		view = Rect2(Vector2.ZERO, map_size)
	else:
		var edge: float = padding + frame_width
		inner = Rect2(Vector2.ONE * edge, size - Vector2.ONE * edge * 2.0)
		# whole texels, so the ground doesn't shimmer as the player moves
		view = Rect2((_to_map(player.global_position) - inner.size * 0.5).floor(), inner.size)

	var outer: Rect2 = inner.grow(padding + frame_width)
	draw_rect(outer, frame_color)
	# open air is sky, so the ground reads against it
	draw_rect(outer.grow(-frame_width), sky_night if GameState.escaping else sky_day)

	# only the part of the view that is actually on the map
	var fit_scale: Vector2 = inner.size / view.size
	var src: Rect2 = view.intersection(Rect2(Vector2.ZERO, map_size))
	if src.has_area():
		draw_texture_rect_region(texture,
				Rect2(inner.position + (src.position - view.position) * fit_scale, src.size * fit_scale), src)

	for marker: Array in markers:
		if is_instance_valid(marker[0]):
			_draw_icon(marker[0], marker[1], inner, view, fit_scale)
	if is_instance_valid(player):
		_draw_icon(player, player_icon_scale, inner, view, fit_scale)

	if full:
		draw_string(get_theme_default_font(), Vector2(inner.position.x, outer.end.y + 34.0),
				"M  close map", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, caption_color)

# a node's own sprite, standing where the sprite stands in the world, kept
# inside the map's edge
func _draw_icon(node: Node2D, icon_scale: float, inner: Rect2, view: Rect2, fit_scale: Vector2) -> void:
	var sprite: Node2D = node if node is Sprite2D or node is AnimatedSprite2D else null
	if sprite == null:
		for child: Node in node.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				sprite = child
				break
	if sprite == null or not sprite.visible:
		return
	var tex: Texture2D
	if sprite is AnimatedSprite2D:
		tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	else:
		tex = sprite.texture
	if tex == null:
		return
	var region := Rect2(Vector2.ZERO, tex.get_size())
	if sprite is Sprite2D and sprite.region_enabled:
		region = sprite.region_rect

	# the bottom edge of the sprite in the world. for the player that is the
	# feet, for the props it is the ground they sit on. anchoring the icon
	# there keeps it on the ground whatever size it is drawn at.
	var world_scale: Vector2 = sprite.global_scale
	var bottom: Vector2 = sprite.global_position \
			+ Vector2(0.0, (region.size.y * 0.5 + sprite.offset.y) * world_scale.y)
	var shown: Vector2 = (region.size * icon_scale).round().max(Vector2.ONE)
	var half_width: float = floorf(shown.x * 0.5)
	var at: Vector2 = inner.position + (_to_map(bottom) - view.position) * fit_scale
	at = at.clamp(inner.position + Vector2(half_width, shown.y),
			inner.end - Vector2(half_width, 0.0)).floor()
	# flipped sprites are mirrored around their own middle
	draw_set_transform(at, 0.0, Vector2(-1.0 if sprite.flip_h else 1.0, 1.0))
	draw_texture_rect_region(tex, Rect2(Vector2(-half_width, -shown.y), shown), region)
	draw_set_transform(Vector2.ZERO)

# a world position to a pixel on the baked map
func _to_map(world: Vector2) -> Vector2:
	var cell: Vector2 = terrain.to_local(world) / Vector2(terrain.tile_set.tile_size)
	return (cell - Vector2(used.position)) * TEXELS
