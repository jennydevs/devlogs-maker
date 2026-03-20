extends MarginContainer


# =====================
# ======= Nodes =======
# =====================

@onready var img_list = $Scroll/VBox;

# =====================
# ====== Signals ======
# =====================

signal connect_startup(component: String);
signal create_notif_popup(msg);
signal create_action_popup(msg, button_info, action);

# ============================
# ====== Signal Methods ======
# ============================

func _on_delete_button_pressed(image_item, img_path: String):
	create_action_popup.emit(
		"Are you sure you want to delete this image?",
		{ 'yes': "Delete Image", 'no': "Cancel" },
		_on_serious_delete_button_pressed.bind(image_item, img_path) 
	);


func _on_serious_delete_button_pressed(image_item, img_path: String):
	var request = Requests.new();
	var config = request.load_config();
	
	if (typeof(config) == TYPE_DICTIONARY): # error
		create_notif_popup.emit("Failed to load config file.");
		return;
	
	var global_path = ProjectSettings.globalize_path(img_path);
	var error = OS.move_to_trash(global_path); # TODO check for errors
	if (error != OK):
		create_notif_popup.emit("Failed to delete file / File doesn't exist");
		return;
	
	image_item.queue_free();


func _on_copy_button_pressed(filename):
	DisplayServer.clipboard_set(filename);

# =====================
# ====== Methods ======
# =====================

func startup():
	load_imgs();
	connect_startup.emit("images");


func load_imgs():
	var request = Requests.new();
	var config = request.load_config();
	if (typeof(config) == TYPE_DICTIONARY): # error
		create_notif_popup.emit("Failed to load config file.");
		return;
	
	var dir_access = DirAccess.open("user://");
	if (!dir_access.dir_exists("assets")): # startup
		return;

	var path = "user://assets/images";
	if (dir_access.dir_exists(path)):
		dir_access.change_dir(path);
		var files = dir_access.get_files();
		for filename in files:
			match filename.get_extension():
				"jpg":
					setup_img(path + "/" + filename);
				"png":
					setup_img(path + "/" + filename);
				_:
					pass;


func setup_img(img_path: String):
	var img = Image.new();
	var img_tex = ImageTexture.new();
	img.load(img_path); # should check for errors
	img_tex.set_image(img);
	
	img_list.add_child(build_img_part(img_tex, img_path));


func build_img_part(img_tex: ImageTexture, img_path: String):
	var image_item = load("res://scenes/components/image_item.tscn").instantiate();
	var filename = img_path.get_file();
	
	image_item.set_meta("file_path", img_path);
	image_item.get_node("HB/Tex").texture = img_tex;
	image_item.get_node("HB/Filename").text = filename;
	var copy_button = image_item.get_node("HB/Copy");
	copy_button.pressed.connect(_on_copy_button_pressed.bind(filename));
	var delete_button = image_item.get_node("HB/Delete");
	delete_button.pressed.connect(_on_delete_button_pressed.bind(image_item, img_path));
	
	return image_item;
