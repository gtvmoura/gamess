extends SceneTree
## "Forno de sprites": renderiza os modelos 3D (Kenney, CC0) na mesma projeção
## isométrica 2:1 do jogo e salva PNGs + metadados (âncora no chão).
## Uso (precisa de tela, ex. xvfb):
##   godot --path . --rendering-method gl_compatibility -s res://tools/bake_sprites.gd -- --out=/caminho

const PPU := 90.51          # pixels por unidade (2x do jogo, onde 1 casa = 64 px de largura)
const VP := 1024
const MODELS := "res://assets/kenney/models/"
const VEHICLES := "res://assets/kenney/vehicles/"

var out_dir := ""


func _initialize() -> void:
	_run()


func _jobs() -> Array:
	var j: Array = []
	for n in ["building-small-a", "building-small-b", "building-small-c", "building-small-d", "building-garage"]:
		j.append([MODELS + n + ".glb", n, [0, 90, 180, 270]])
	for n in ["grass-trees", "grass-trees-tall", "pavement-fountain", "road-straight-lightposts", "grass", "pavement"]:
		j.append([MODELS + n + ".glb", n, [0]])
	for n in ["vehicle-truck-green", "vehicle-truck-purple", "vehicle-truck-red", "vehicle-truck-yellow", "vehicle-motorcycle"]:
		j.append([VEHICLES + n + ".glb", n, [0, 90, 180, 270]])
	return j


func _aabb(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://assets/sprites")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = Vector2i(VP, VP)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.86, 0.95)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.light_energy = 1.25
	vp.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VP / PPU
	cam.near = 0.05
	cam.far = 200.0
	cam.rotation_degrees = Vector3(-30, 45, 0)
	vp.add_child(cam)
	cam.current = true

	var meta := {}
	var sheet_items: Array = []
	for job in _jobs():
		var path: String = job[0]
		var name: String = job[1]
		var scene = load(path)
		if scene == null:
			printerr("não carregou ", path)
			continue
		var holder := Node3D.new()
		vp.add_child(holder)
		var inst: Node3D = scene.instantiate()
		holder.add_child(inst)
		for r in job[2]:
			holder.rotation_degrees.y = float(r)
			await process_frame
			var box := _aabb(holder)
			var center := box.get_center()
			cam.global_position = center + cam.global_transform.basis.z * 60.0
			for i in 3:
				await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var used := img.get_used_rect()
			if used.size.x <= 0:
				printerr("vazio ", name, r)
				continue
			var sub := img.get_region(used)
			var key := "%s_r%d" % [name, int(r)]
			sub.save_png(out_dir.path_join(key + ".png"))
			var anchor := cam.unproject_position(Vector3(0, 0, 0)) - Vector2(used.position)
			meta[key] = {"ax": anchor.x, "ay": anchor.y, "w": used.size.x, "h": used.size.y,
				"size": [box.size.x, box.size.y, box.size.z]}
			sheet_items.append([key, sub])
			print("ok ", key, " ", used.size)
		holder.queue_free()
		await process_frame

	var f := FileAccess.open(out_dir.path_join("sprites.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	_contact_sheet(sheet_items)
	quit()


## Uma imagem com todos os sprites e seus nomes (para conferir rapidamente).
func _contact_sheet(items: Array) -> void:
	var cell := 260
	var cols := 6
	var rows := ceili(items.size() / float(cols))
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.85, 0.87, 0.9))
	for i in items.size():
		var img: Image = (items[i][1] as Image).duplicate()
		var s := minf(1.0, (cell - 10.0) / maxf(img.get_width(), img.get_height()))
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)))
		var x := (i % cols) * cell + (cell - img.get_width()) / 2
		var y := (i / cols) * cell + (cell - img.get_height()) / 2
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))
	sheet.save_png(out_dir.path_join("_contact_sheet.png"))
