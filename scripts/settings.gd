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

# ============================
# ====== Signal Methods ======
# ============================

func _on_save_settings_pressed(apply_changes: bool) -> void:
	update_settings(get_user_input_areas(), apply_changes);

# =====================
# ====== Methods ======
# =====================

func startup() -> void: 
	get_node("VB/HB/Apply").pressed.connect(_on_save_settings_pressed.bind(true));
	get_node("VB/HB/Cancel").pressed.connect(_on_save_settings_pressed.bind(false));
	
	connect_startup.emit("settings");
	update_settings(get_user_input_areas(), false);


func update_settings(user_set: Dictionary, apply_settings: bool) -> void:
	var config = load_config_file();
	if (config == null): return;
	
	var user_values = ["user_name", "user_email"];
	var repo_values = ["repo_owner", "repo_name", "repo_branch_update", "content_path"];
	
	if (apply_settings): # save
		for repo_value in repo_values:
			config.set_value("repo_info", repo_value, user_set[repo_value]['text']);
		
		var user_nodes = ["VB/Author", "VB/Email"];
		for i in range(0, user_values.size()):
			config.set_value("user_info", user_values[i], get_node(user_nodes[i])['text']);
		
		var upload_path = "https://api.github.com/repos/%s/%s/contents/%s" % [
			user_set.repo_owner.text, user_set.repo_name.text, user_set.content_path.text
		];
		config.set_value("urls", "base_repo", upload_path);
		
		config.save("user://config.cfg");
		create_notif_popup.emit("Saved!");
	else: # load
		for user_value in user_values:
			user_set[user_value]['text'] = config.get_value("user_info", user_value);
		for repo_value in repo_values:
			user_set[repo_value]['text'] = config.get_value("repo_info", repo_value);


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
