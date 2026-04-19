extends Node2D

## 간단한 테트리스 테스트 씬. 10×20 보드, 7종 테트로미노, 간단 월킥, 락 딜레이, DAS, 고스트, 라인클리어.

# 1) Constants
const BOARD_W: int = 10
const BOARD_H: int = 20
const CELL: int = 28
const BOARD_ORIGIN: Vector2 = Vector2(40.0, 40.0)

const SPAWN_COL: int = 3
const SPAWN_ROW: int = 0

const LOCK_DELAY: float = 0.5
const DAS_DELAY: float = 0.17
const DAS_RATE: float = 0.05
const SOFT_DROP_RATE: float = 0.05

# 각 피스의 4회전 상태. 원점(좌상) 기준 (col, row) 셀 오프셋.
const SHAPES: Array = [
	# 0: I
	[
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)],
		[Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	],
	# 1: O
	[
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	],
	# 2: T
	[
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
	# 3: S
	[
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
	],
	# 4: Z
	[
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)],
	],
	# 5: J
	[
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)],
	],
	# 6: L
	[
		[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)],
	],
]

const COLORS: Array[Color] = [
	Color(0.20, 0.90, 0.95), # I
	Color(0.95, 0.85, 0.20), # O
	Color(0.70, 0.35, 0.90), # T
	Color(0.35, 0.90, 0.45), # S
	Color(0.95, 0.30, 0.35), # Z
	Color(0.30, 0.45, 0.95), # J
	Color(0.95, 0.60, 0.20), # L
]

const SCORE_TABLE: Array[int] = [0, 100, 300, 500, 800]

# 2) State
var _board: Array = [] # 2D. 0=빈칸, 1..7=색 인덱스+1
var _piece_kind: int = -1
var _piece_rot: int = 0
var _piece_pos: Vector2i = Vector2i.ZERO
var _next_kind: int = -1

var _gravity_accum: float = 0.0
var _lock_accum: float = 0.0
var _is_on_ground: bool = false
var _das_dir: int = 0
var _das_timer: float = 0.0
var _das_active: bool = false
var _soft_drop_timer: float = 0.0

var _score: int = 0
var _lines: int = 0
var _level: int = 0
var _is_game_over: bool = false

# 3) Node refs
@onready var _score_label: Label = $ScoreLabel
@onready var _next_label: Label = $NextLabel
@onready var _game_over_label: Label = $GameOverLabel


# 4) Callbacks
func _ready() -> void:
	_reset()


func _process(delta: float) -> void:
	if _is_game_over:
		return
	_handle_das(delta)
	_handle_soft_drop(delta)
	_handle_gravity(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tetris_restart"):
		_reset()
		return
	if _is_game_over:
		return
	if event.is_action_pressed(&"tetris_left"):
		if _try_move(-1, 0):
			_das_dir = -1
			_das_timer = 0.0
			_das_active = false
	elif event.is_action_pressed(&"tetris_right"):
		if _try_move(1, 0):
			_das_dir = 1
			_das_timer = 0.0
			_das_active = false
	elif event.is_action_released(&"tetris_left") and _das_dir == -1:
		_das_dir = 0
	elif event.is_action_released(&"tetris_right") and _das_dir == 1:
		_das_dir = 0
	elif event.is_action_pressed(&"tetris_rotate_cw"):
		_try_rotate(1)
	elif event.is_action_pressed(&"tetris_rotate_ccw"):
		_try_rotate(-1)
	elif event.is_action_pressed(&"tetris_hard_drop"):
		_hard_drop()


func _draw() -> void:
	var board_rect := Rect2(BOARD_ORIGIN, Vector2(BOARD_W * CELL, BOARD_H * CELL))
	draw_rect(board_rect, Color(0.08, 0.08, 0.11), true)

	var grid_col := Color(0.18, 0.18, 0.22)
	for x in range(BOARD_W + 1):
		var sx: float = BOARD_ORIGIN.x + x * CELL
		draw_line(Vector2(sx, BOARD_ORIGIN.y), Vector2(sx, BOARD_ORIGIN.y + BOARD_H * CELL), grid_col, 1.0)
	for y in range(BOARD_H + 1):
		var sy: float = BOARD_ORIGIN.y + y * CELL
		draw_line(Vector2(BOARD_ORIGIN.x, sy), Vector2(BOARD_ORIGIN.x + BOARD_W * CELL, sy), grid_col, 1.0)

	for r in range(BOARD_H):
		var row: Array = _board[r]
		for c in range(BOARD_W):
			var v: int = row[c]
			if v > 0:
				_draw_cell(c, r, COLORS[v - 1], 1.0)

	if _piece_kind >= 0 and not _is_game_over:
		var ghost_y: int = _ghost_row()
		for off in SHAPES[_piece_kind][_piece_rot]:
			var gc: int = _piece_pos.x + off.x
			var gr: int = ghost_y + off.y
			if gr >= 0:
				_draw_cell(gc, gr, COLORS[_piece_kind], 0.22)

		for off in SHAPES[_piece_kind][_piece_rot]:
			var pc: int = _piece_pos.x + off.x
			var pr: int = _piece_pos.y + off.y
			if pr >= 0:
				_draw_cell(pc, pr, COLORS[_piece_kind], 1.0)

	var next_origin: Vector2 = Vector2(BOARD_ORIGIN.x + BOARD_W * CELL + 40.0, BOARD_ORIGIN.y + 40.0)
	draw_rect(Rect2(next_origin, Vector2(4 * CELL, 4 * CELL)), Color(0.08, 0.08, 0.11), true)
	if _next_kind >= 0:
		for off in SHAPES[_next_kind][0]:
			var rect := Rect2(next_origin + Vector2(off.x * CELL, off.y * CELL), Vector2(CELL, CELL))
			draw_rect(rect.grow(-1.0), COLORS[_next_kind], true)
			draw_rect(rect.grow(-1.0), COLORS[_next_kind].lightened(0.3), false, 1.0)


# 5) Internal helpers
func _reset() -> void:
	_board.clear()
	for r in range(BOARD_H):
		var row: Array = []
		for c in range(BOARD_W):
			row.append(0)
		_board.append(row)
	_score = 0
	_lines = 0
	_level = 0
	_is_game_over = false
	_gravity_accum = 0.0
	_lock_accum = 0.0
	_is_on_ground = false
	_das_dir = 0
	_das_active = false
	_das_timer = 0.0
	_soft_drop_timer = 0.0
	_next_kind = randi_range(0, 6)
	_spawn_next()
	_game_over_label.visible = false
	_update_labels()
	queue_redraw()


func _spawn_next() -> void:
	_piece_kind = _next_kind
	_next_kind = randi_range(0, 6)
	_piece_rot = 0
	_piece_pos = Vector2i(SPAWN_COL, SPAWN_ROW)
	_gravity_accum = 0.0
	_lock_accum = 0.0
	_is_on_ground = false
	if not _can_place(_piece_kind, _piece_rot, _piece_pos):
		_game_over()


func _game_over() -> void:
	_is_game_over = true
	_game_over_label.visible = true


func _handle_gravity(delta: float) -> void:
	var interval: float = _current_gravity_interval()
	_gravity_accum += delta
	while _gravity_accum >= interval:
		_gravity_accum -= interval
		if _can_place(_piece_kind, _piece_rot, _piece_pos + Vector2i(0, 1)):
			_piece_pos.y += 1
			_is_on_ground = false
			_lock_accum = 0.0
		else:
			_is_on_ground = true
	if _is_on_ground:
		_lock_accum += delta
		if _lock_accum >= LOCK_DELAY:
			_lock_piece()


func _handle_das(delta: float) -> void:
	if _das_dir == 0:
		return
	_das_timer += delta
	if not _das_active:
		if _das_timer >= DAS_DELAY:
			_das_active = true
			_das_timer = 0.0
		return
	while _das_timer >= DAS_RATE:
		_das_timer -= DAS_RATE
		if not _try_move(_das_dir, 0):
			break


func _handle_soft_drop(delta: float) -> void:
	if not Input.is_action_pressed(&"tetris_soft_drop"):
		_soft_drop_timer = 0.0
		return
	_soft_drop_timer += delta
	while _soft_drop_timer >= SOFT_DROP_RATE:
		_soft_drop_timer -= SOFT_DROP_RATE
		if _try_move(0, 1):
			_score += 1
		else:
			break
	_update_labels()


func _current_gravity_interval() -> float:
	# 레벨에 따른 초/칸. 최소 0.05초.
	return maxf(0.05, 1.0 * pow(0.85, _level))


func _can_place(kind: int, rot: int, pos: Vector2i) -> bool:
	for off in SHAPES[kind][rot]:
		var c: int = pos.x + off.x
		var r: int = pos.y + off.y
		if c < 0 or c >= BOARD_W or r >= BOARD_H:
			return false
		if r >= 0:
			var row: Array = _board[r]
			if row[c] != 0:
				return false
	return true


func _try_move(dx: int, dy: int) -> bool:
	var target: Vector2i = _piece_pos + Vector2i(dx, dy)
	if _can_place(_piece_kind, _piece_rot, target):
		_piece_pos = target
		if dy == 0:
			_lock_accum = 0.0
		return true
	return false


func _try_rotate(dir: int) -> bool:
	var new_rot: int = (_piece_rot + dir + 4) % 4
	# 간단 월킥: 제자리 → 좌/우 → 위 → 좌2/우2 순서로 시도.
	var kicks: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(-2, 0), Vector2i(2, 0),
	]
	for kick in kicks:
		var target: Vector2i = _piece_pos + kick
		if _can_place(_piece_kind, new_rot, target):
			_piece_rot = new_rot
			_piece_pos = target
			_lock_accum = 0.0
			return true
	return false


func _hard_drop() -> void:
	var dy: int = 0
	while _can_place(_piece_kind, _piece_rot, _piece_pos + Vector2i(0, dy + 1)):
		dy += 1
	_piece_pos.y += dy
	_score += dy * 2
	_lock_piece()


func _lock_piece() -> void:
	for off in SHAPES[_piece_kind][_piece_rot]:
		var c: int = _piece_pos.x + off.x
		var r: int = _piece_pos.y + off.y
		if r >= 0 and r < BOARD_H and c >= 0 and c < BOARD_W:
			var row: Array = _board[r]
			row[c] = _piece_kind + 1
	var cleared: int = _clear_lines()
	if cleared > 0:
		_score += SCORE_TABLE[cleared] * (_level + 1)
		_lines += cleared
		_level = _lines / 10
	_update_labels()
	_spawn_next()


func _clear_lines() -> int:
	var cleared: int = 0
	var r: int = BOARD_H - 1
	while r >= 0:
		var row: Array = _board[r]
		var full: bool = true
		for c in range(BOARD_W):
			if row[c] == 0:
				full = false
				break
		if full:
			_board.remove_at(r)
			var new_row: Array = []
			for c in range(BOARD_W):
				new_row.append(0)
			_board.insert(0, new_row)
			cleared += 1
		else:
			r -= 1
	return cleared


func _ghost_row() -> int:
	var y: int = _piece_pos.y
	while _can_place(_piece_kind, _piece_rot, Vector2i(_piece_pos.x, y + 1)):
		y += 1
	return y


func _draw_cell(col: int, row: int, color: Color, alpha: float) -> void:
	var p: Vector2 = BOARD_ORIGIN + Vector2(col * CELL, row * CELL)
	var fill: Color = color
	fill.a = alpha
	draw_rect(Rect2(p + Vector2(1.0, 1.0), Vector2(CELL - 2, CELL - 2)), fill, true)
	var border: Color = color.lightened(0.3)
	border.a = alpha
	draw_rect(Rect2(p + Vector2(1.0, 1.0), Vector2(CELL - 2, CELL - 2)), border, false, 1.0)


func _update_labels() -> void:
	_score_label.text = "SCORE: %d\nLINES: %d\nLEVEL: %d" % [_score, _lines, _level]
	_next_label.text = "NEXT"
