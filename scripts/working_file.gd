extends FileDialog

signal connect_startup(component: String);
signal fill_in_details(post_info: Dictionary);
signal clear_post;
signal collected_img(img_data, img_name: String, img_path: String);

signal create_notif_popup(msg);
signal create_action_popup(msg, button_info, action);

var curr_file_mode = "";

func startup():
	
	file_selected.connect(_on_file_selected);
	
	current_dir = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	connect_startup.emit("file_dialog");


func import_file():
	file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	curr_file_mode = "txt_file";
	clear_filters();
	add_filter("*.txt", "Text Files");
	show();


func export_file(filename: String, file_text: String, file_img_paths: Array[String]):
	var download_path = OS.get_system_dir(OS.SystemDir.SYSTEM_DIR_DOWNLOADS);
	
	var dir_access = DirAccess.open(download_path);
	
	var folder_name = filename.replace("." + filename.get_extension(), "");
	if (!dir_access.dir_exists(folder_name)):
		var error = dir_access.make_dir(folder_name);
		if (error != OK):
			create_notif_popup.emit("Error %d\nFailed to create folder!" % error);
		else:
			save_post_files(download_path, folder_name, filename, file_text, file_img_paths);
	else:
		ask_to_overwrite_files(download_path, folder_name, filename, file_text, file_img_paths);


func ask_to_overwrite_files(
	download_path: String, folder_name: String, filename: String, 
	file_text: String, file_img_paths: Array[String]
):
	create_action_popup.emit(
		"Are you sure you want to overwrite this post?",
		{ 'yes': "Overwrite", 'no': "Cancel" },
		save_post_files.bind(download_path, folder_name, filename, file_text, file_img_paths)
	);

func save_post_files(
	download_path: String, folder_name: String, filename: String, 
	file_text: String, file_img_paths: Array[String]
):
	var created_file = FileAccess.open(download_path + "/" + folder_name + "/" + filename, FileAccess.WRITE);
	if (created_file.is_open()):
		created_file.store_string(file_text);
	for img_path in file_img_paths:
		var img = Image.new();
		img.load("user://assets/" + img_path);
		match img_path.get_file().get_extension():
			"jpg":
				img.save_jpg("%s/%s/%s" % [download_path, folder_name, img_path.get_file()]);
			"png":
				img.save_png("%s/%s/%s" % [download_path, folder_name, img_path.get_file()]);
	create_notif_popup.emit("Saved file(s)!");


func import_image():
	file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE;
	curr_file_mode = "img_file";
	clear_filters();
	add_filter("*.png, *.jpg", "Image Files");
	show();


func _on_file_selected(path: String):
	elif (curr_file_mode == "img_file"):
		setup_assets_folder();
		
		var file_exts = ["jpg", "png"];
		var filename = path.get_file();
		var img_ext = filename.get_extension();
		
		if (!file_exts.has(img_ext)):
			create_notif_popup.emit("Unsupported image extension!");
			return;
		
		var tex = ImageTexture.new();
		var img = Image.new();
		img.load(path);
		
		var save_path = "user://assets/images/" + filename;
		
		match img_ext:
			"jpg":
				img.save_jpg(save_path, 1.0);
			"png":
				img.save_png(save_path);
	
		tex.set_image(img);
		
		add_to_image_list.emit(tex, save_path);


func check_file_name(curr_file_name: String) -> String:
	var regex = RegEx.new();
	regex.compile("^(\\d{4})_(\\d{2})_(\\d{2})");
	var matches = regex.search(curr_file_name);

	if (matches):
		return "devlog";

	if (curr_file_name == "directory.txt"):
		return "directory";
	
	if (curr_file_name == "projects_info.txt"):
		return "project";
	
	return "";


func create_img_folder(config: ConfigFile):
	var dir_access = DirAccess.open("user://");
	if (!dir_access.dir_exists("assets")):
		var error = dir_access.make_dir("assets");
		if (error != OK):
			create_notif_popup.emit("Failed to create assets folder!");
	
	var img_path = config.get_value("repo_info", "image_path");
	img_path = img_path.rstrip("/");
	if (!dir_access.dir_exists("assets/%s" % img_path)):
		var error = dir_access.make_dir_recursive("assets/%s" % img_path);
		if (error != OK):
			create_notif_popup.emit("Failed to create folder(s) for image!");
	
