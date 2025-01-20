package ruffian
import sa "core:container/small_array"
import "core:math"
import "core:strings"

string_is_ascii :: proc(str: string) -> bool {
    _, ok := strings.ascii_set_make(str)
    return ok
}

index_of :: proc(arr: ^$A/[dynamic]$T, elem: T) -> int {
    for i in 0 ..< len(arr) {
        if arr[i] == elem {
            return i
        }
    }
    return -1
}

sa_slice :: proc(arr: ^$A/sa.Small_Array($N, $T)) -> []T {
    return sa.slice(arr)
}


point_idx :: proc(p: Point) -> int {
    return p.y * MAP_WIDTH + p.x
}


snap_unit_octant :: proc(vec: Point) -> Point {
    angle := math.atan2(f64(vec.y), f64(vec.x))
    octant := int(8 * angle / (2 * math.PI) + 8) % 8
    return Dirs[Direction(octant)]
}

snap_unit_quad :: proc(vec: Point) -> Point {
    angle := math.atan2(f64(vec.y), f64(vec.x))
    quadrant := int(4 * angle / (2 * math.PI) + 4) % 4
    return Dirs[Direction(quadrant)]
}
