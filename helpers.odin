package ruffian
import "core:strings"
import sa "core:container/small_array"

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