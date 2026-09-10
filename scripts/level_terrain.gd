@tool
extends TileMapLayer
# paints the level 01 blockout from the map below. "X" is solid ground,
# "." is open air. one letter per cell.
#
# this exists because hand-writing tile data into the .tscn does not survive
# a save. the layer fills itself the first time the scene is opened, and once
# you save the scene the cells are stored in it, so this never runs again and
# never overwrites tiles you painted by hand. tick "rebuild" in the inspector
# to wipe the layer and lay the map down again.

const MAP: Array[String] = [
	"......................",
	"......................",
	"......................",
	"X.....................",
	"X................XXXXX",
	"XXX.............XXXXXX",
	"X..XXX.........XXXXXXX",
	"X.....XXX.....XXXXXXXX",
	"X..XXX.......XXXXXXXXX",
	"X.....XXXX..XXXXXXXXXX",
	"XXXXXX.....XXXXXXXXXXX",
	"XXXXXXXXXXXXXXXXXXXXXX",
]

# which tile in the atlas to draw. the art is picked from the shape of the
# ground, not stored in the map
const GRASS: Vector2i = Vector2i(0, 0)
const OUTSIDE: Vector2i = Vector2i(1, 0)
const INSIDE: Vector2i = Vector2i(0, 1)
const DIRT: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]
const SOURCE: int = 0

@export var rebuild: bool = false:
	set(value):
		rebuild = false
		if value:
			build()

func _ready() -> void:
	if get_used_cells().is_empty():
		build()

func is_solid(x: int, y: int) -> bool:
	if y < 0 or y >= MAP.size():
		return false
	if x < 0 or x >= MAP[y].length():
		return false
	return MAP[y][x] == "X"

# buried cell gets plain dirt, an open right edge gets the outside corner,
# taller ground on the left gets the inside corner, anything else is grass
func pick_tile(x: int, y: int) -> Vector2i:
	if is_solid(x, y - 1):
		return DIRT[(x * 7 + y * 13) % DIRT.size()]
	if not is_solid(x + 1, y):
		return OUTSIDE
	if is_solid(x - 1, y - 1):
		return INSIDE
	return GRASS

func build() -> void:
	clear()
	for y in MAP.size():
		for x in MAP[y].length():
			if is_solid(x, y):
				set_cell(Vector2i(x, y), SOURCE, pick_tile(x, y))
