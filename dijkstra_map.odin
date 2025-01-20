package ruffian
import "base:builtin"
import sa "core:container/small_array"
import "core:fmt"
import "core:mem"
import "core:slice"

// Dijkstra Map as described in https://roguebasin.com/index.php/The_Incredible_Power_of_Dijkstra_Maps
DMap :: distinct [MAP_WIDTH * MAP_HEIGHT]int

// FIXME: find a method that doesn't use a value on the verge of overflowing
DMAP_MAX_UNINIT :: max(int) - 10

DMaps: struct {
    player: DMap,
}

DMap_clear :: proc(dm: ^DMap) {
    for i in 0 ..< len(dm) {
        dm[i] = DMAP_MAX_UNINIT
    }
}

DMap_lowest_neighbor :: proc(dm: ^DMap, p: Point) -> int {
    cur_min := DMAP_MAX_UNINIT
    for vec in DirsCard {
        pos := p + vec
        if in_bounds(pos) && get_tile_type(pos) == .Floor {
            val := dm[point_idx(pos)]
            if val < cur_min {
                cur_min = val
            }
        }
    }
    return cur_min
}

DMap_calc :: proc(dm: ^DMap, points: ..Point) {
    for point in points {
        idx := point_idx(point)
        dm[idx] = 0
    }

    for mutated := true; mutated; {
        mutated = false
        for y in 0 ..< MAP_HEIGHT {
            for x in 0 ..< MAP_WIDTH {
                pos := Point{x, y}
                if tile_is_walkable(pos) {
                    lowest := DMap_lowest_neighbor(dm, pos)
                    if d_val := dm[point_idx(pos)]; d_val > lowest + 1 {
                        dm[point_idx(pos)] = lowest + 1
                        mutated = true
                    }
                }

                pos2 := Point{MAP_WIDTH - 1 - x, MAP_HEIGHT - 1 - y}
                if tile_is_walkable(pos2) {
                    lowest := DMap_lowest_neighbor(dm, pos2)
                    if d_val := dm[point_idx(pos2)]; d_val > lowest + 1 {
                        dm[point_idx(pos2)] = lowest + 1
                        mutated = true
                    }
                }
            }
        }
    }
}
