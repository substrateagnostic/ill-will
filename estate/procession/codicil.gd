class_name ProcessionCodicil
extends Node
## Hard-currency desk.  The rising personal price is the only rubber band:
## visible, mild, and paid by the leader rather than gifted to a trailing seat.

signal claimed(player: int, cost: int, new_total: int)
signal relocated(old_space: int, new_space: int, jump: int)

const BASE_COST := 10
const COST_PER_DEED := 2
const MIN_JUMP := 7
const MAX_JUMP := 11

var space_index := 13

func price_for(deeds_held: int) -> int:
	return BASE_COST + COST_PER_DEED * deeds_held

func can_claim(grudge: int, deeds_held: int) -> bool:
	return grudge >= price_for(deeds_held)

func purchase(player: int, grudge: Array[int], deeds: Array[int]) -> Dictionary:
	var cost := price_for(deeds[player])
	if grudge[player] < cost:
		return {"ok": false, "cost": cost, "reason": "short"}
	grudge[player] -= cost
	deeds[player] += 1
	claimed.emit(player, cost, deeds[player])
	return {"ok": true, "cost": cost, "deeds": deeds[player]}

func choose_relocation(rng: RandomNumberGenerator, board_size: int) -> int:
	var old := space_index
	var jump := rng.randi_range(MIN_JUMP, MAX_JUMP)
	space_index = posmod(space_index + jump, board_size)
	relocated.emit(old, space_index, jump)
	return space_index

func set_space(index: int) -> void:
	space_index = index
