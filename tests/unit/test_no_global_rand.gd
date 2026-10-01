extends GutTest
## D-034: randomness only through Rng streams. Global calls are banned outside core/rng.gd.

const SCAN_DIRS := ["res://autoload", "res://core", "res://components", "res://actors",
	"res://world", "res://ui", "res://balance", "res://art", "res://tools"]
const ALLOWED := ["res://core/rng.gd"]
const BAN_RE := "(?<![\\.\\w])(randi|randf|randi_range|randf_range|randomize)\\s*\\(|RandomNumberGenerator\\s*\\.\\s*new\\s*\\(|@GlobalScope\\s*\\.\\s*(randi|randf|randi_range|randf_range|randomize|randfn|seed|rand_from_seed)\\s*\\("

func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		_collect(dir_path.path_join(d), out)

func test_no_global_randomness() -> void:
	var files: Array = []
	for d in SCAN_DIRS:
		_collect(d, files)
	var re := RegEx.new()
	re.compile(BAN_RE)
	assert_true(files.has("res://core/rng.gd"), "scan reached core/")
	assert_true(files.has("res://art/palette/palette.gd"), "scan reached art/")
	var offenders: Array = []
	for path in files:
		if path in ALLOWED:
			continue
		var text := FileAccess.get_file_as_string(path)
		for m in re.search_all(text):
			offenders.append("%s: %s" % [path, m.get_string()])
	assert_eq(offenders, [], "global randomness found")

func test_ban_regex_catches_and_allows() -> void:
	var re := RegEx.new()
	re.compile(BAN_RE)
	assert_not_null(re.search("var x = randi()"))
	assert_not_null(re.search("randf_range(0, 1)"))
	assert_null(re.search("rng.randi_range(0, 2)"))
	assert_null(re.search("my_randi(3)"))
	assert_not_null(re.search("var r := RandomNumberGenerator.new()"))
	assert_not_null(re.search("@GlobalScope.randi()"))
	assert_null(re.search("rng.randi_range(0, 3)"))
