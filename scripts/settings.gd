extends MarginContainer

## This module is for updating your settings.
## Update repo information and the path where the devlog will be uploaded to.
## Update name and email to label your commits.

# =====================
# ====== Signals ======
# =====================

signal connect_startup(component: String);

signal create_error_popup(error, error_type);
signal create_notif_popup(msg);

# =====================
# ====== Methods ======
# =====================

func startup() -> void: 
	get_node("VB/HB/Apply").pressed.connect(_on_save_settings_pressed.bind(true));
	get_node("VB/HB/Cancel").pressed.connect(_on_save_settings_pressed.bind(false));
	
	connect_startup.emit("settings");
	
	var user_set = get_user_input_areas();
	
	setup_settings(user_set);


func setup_settings(user_set: Dictionary) -> void:
	var config = load_config_file();
	
	if (config == null): return;
	 
	user_set.author.text = config.get_value("user_info", "user_name");
	user_set.email.text = config.get_value("user_info", "user_email");
	
	user_set.repo_owner.text = config.get_value("repo_info", "repo_owner");
	user_set.repo_name.text = config.get_value("repo_info", "repo_name");
	user_set.repo_branch.text = config.get_value("repo_info", "repo_branch_update");
	user_set.content_path.text = config.get_value("repo_info", "content_path");
	user_set.image_path.text = config.get_value("repo_info", "image_path");


func save_settings(user_set: Dictionary) -> void:
	var config = load_config_file();
	
	if (config == null): return;
	
	config.set_value("repo_info", "repo_owner", user_set.repo_owner.text);
	config.set_value("repo_info", "repo_name", user_set.repo_name.text);
	config.set_value("repo_info", "repo_branch_update", user_set.repo_branch.text);
	config.set_value("repo_info", "content_path", user_set.content_path.text);
	config.set_value("repo_info", "image_path", user_set.image_path.text);
	
	var build_file_url = "https://api.github.com/repos/%s/%s/contents/%s" % [
		user_set.repo_owner.text, 
		user_set.repo_name.text, 
		user_set.content_path.text
	];
func get_user_input_areas():
	var nodes = [
		"VB/HB1/VB/RepoOwner", "VB/HB1/VB2/RepoName", "VB/RepoBranch", "VB/HB2/VB/ContentPath",
		"VB/Author", "VB/Email"
	];
	var values = [
		"repo_owner", "repo_name", "repo_branch_update", "content_path", 
		"user_name", "user_email"
	];
	
	var content = {};
	for i in range(0, values.size()):
		content[values[i]] = get_node(nodes[i]);

	return content;

# =====================
# ====== Helpers ======
# =====================

func load_config_file() -> ConfigFile:
	var config = ConfigFile.new();
	var error = config.load("user://config.cfg");
	
	if error != OK:
		create_error_popup.emit(error, AppInfo.ErrorType.ConfigError);
		return null;
	
	return config;
