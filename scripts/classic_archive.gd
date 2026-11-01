class_name ClassicArchive
extends RefCounted
## Read-only, bounds-checked classic BSA archive. No original assets are copied.
var data: PackedByteArray
var entries: Dictionary = {}
var ordered_entries: Array[Vector2i] = []
var error: String = ""

func open(path: String) -> bool:
	entries.clear()
	ordered_entries.clear()
	error = ""
	if not FileAccess.file_exists(path):
		error = "Cannot find archive: " + path
		return false
	data = FileAccess.get_file_as_bytes(path)
	if data.size() < 4:
		error = "Cannot read archive: " + path
		return false
	var count := data.decode_u16(0)
	var kind := data.decode_u16(2)
	if kind != 256 and kind != 512:
		error = "Unsupported BSA directory"
		return false
	var stride := 18 if kind == 256 else 8
	var directory := data.size() - count * stride
	var offset := 4
	if directory < 4:
		error = "Truncated BSA directory"
		return false
	for i in count:
		var p := directory + i * stride
		var end := p
		while kind == 256 and end < p + 14 and data[end] != 0:
			end += 1
		var key := data.slice(p, end).get_string_from_ascii() if kind == 256 else str(data.decode_u32(p))
		var length := data.decode_u32(p + stride - 4)
		if offset + length > directory:
			error = "Invalid BSA record bounds"
			entries.clear()
			ordered_entries.clear()
			return false
		entries[key] = Vector2i(offset, length)
		# Numeric IDs need not be unique. Indexed sound lookup must retain both.
		ordered_entries.append(Vector2i(offset, length))
		offset += length
	return true

func record(key: String) -> PackedByteArray:
	if not entries.has(key):
		return PackedByteArray()
	var span: Vector2i = entries[key]
	return data.slice(span.x, span.x + span.y)

func record_at(index: int) -> PackedByteArray:
	if index < 0 or index >= ordered_entries.size():
		return PackedByteArray()
	var span := ordered_entries[index]
	return data.slice(span.x, span.x + span.y)


