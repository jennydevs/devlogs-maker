extends MarginContainer

# =====================
# ======= Nodes =======
# =====================

@onready var list = $ScrollContainer/List;

# =====================
# ===== Variables =====
# =====================

var devlogs = {};

var edit_devlog = {
	"name": "",
	"sha": "",
	"decoded_content": ""
};

var directory = {
	"name": "directory.txt",
	"sha": "",
	"data": "",
};

# =====================
# ====== Signals ======
# =====================

signal connect_startup(component: String);
signal clear_post;
signal fill_in_details(post_info: Dictionary);
signal create_error_popup(error, error_type);
signal create_notif_popup(msg);
signal create_action_popup(msg, button_info, action);

# ============================
# ====== Signal Methods ======
# ============================

func _on_get_devlogs():
	clear_list();
	
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	var devlogs_path = config.get_value("repo_info", "content_path");
	var result = request.get_files(self, "get_devlog_files", devlogs_path);
	
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);


func _on_http_request_completed(result, response_code, _headers, body, action: String):
	var request = Requests.new();
	var request_result = request.process_results(result, response_code);
	if (request_result.has("error")):
		create_notif_popup.emit(request_result["error"]);  # TODO create error popup type
		return;
	
	var body_str = body.get_string_from_utf8();
	var response = request.convert_to_json(body_str);
	
	var msg = "";
	match response_code:
		HTTPClient.RESPONSE_OK:
			match action:
				"get_devlogs_files":
					devlogs.clear();
					for entry in response:
						if (entry["type"] == "dir"):
							devlogs[entry["name"]] = { 
								"path": entry["path"],
								"sha": entry["sha"],
								"git_url": entry["git_url"]
							};
					setup_devlogs_list();
				"get_devlog_to_edit":
					edit_devlog["name"] = response["name"];
					edit_devlog["sha"] = response["sha"];
					edit_devlog["decoded_content"] = Marshalls.base64_to_utf8(response["content"]);
					fill_in_devlog();
				"get_directory":
					directory["data"] = Marshalls.base64_to_utf8(response["content"]);
					directory["sha"] = response["sha"];
				"get_devlog":
					fill_out_devlog(body_str);
				"delete_devlog":
					pass;
		_:
			pass;
	
	msg = request.build_notif_msg(action, response_code, body_str);
	if (msg != ""):
		create_notif_popup.emit(msg);


func _on_edit_button_pressed(folder_name: String):
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	var devlog_path = config.get_value("repo_info", "content_path") + folder_name + "/" + folder_name + ".txt";
	var result = request.get_files(self, "get_devlog_to_edit", devlog_path);
	
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);


func _on_delete_button_pressed(delete_entry_button: Button):
	create_action_popup.emit(
		"Are you sure you want to delete this post?",
		{ 'yes': "Delete Post", 'no': "Cancel" },
		_on_serious_delete_button_pressed.bind(delete_entry_button) 
	);


func _on_serious_delete_button_pressed(delete_entry_button: Button):
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	var button_ref = delete_entry_button;
	var file_sha = button_ref.get_meta("sha");
	var filename = button_ref.get_meta("name");
	var result = request.delete_file(
		self, "delete_devlog", 
		config.get_value("repo_info", "content_path") + filename, file_sha
	);
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);
		return;
	
	await result["request_signal"];
	await get_tree().create_timer(1.0).timeout;
	
	if (edit_button_ref && (button_ref.get_meta("sha") == edit_button_ref.get_meta("sha"))):
		clear_post.emit();
	update_directory(filename, "delete_filename");
	button_ref.get_parent().queue_free(); # delete entry in list


# =====================
# ====== Methods ======
# =====================

func startup():
	connect_startup.emit("devlogs_list");

## Create and add data to the visual representation of each devlog.
func create_post_info(filename: String):
	var post_item = load("res://scenes/components/post_item.tscn").instantiate();
	
	post_item.get_node("Filename").text = filename;
	
	var edit_button = post_item.get_node("Edit");
	edit_button.pressed.connect(_on_edit_button_pressed.bind(filename));
	var delete_button = post_item.get_node("Delete");
	delete_button.pressed.connect(_on_delete_button_pressed.bind(filename));
	
	list.add_child(post_item);

## Create the list of devlogs nodes given the name of each devlog.
func setup_devlogs_list():
	var devlog_names = devlogs.keys();
	for devlog_name in devlog_names:
		create_post_info(devlog);


## Deletes the devlog nodes in the list.
func clear_list():
	var amt_of_children = list.get_child_count();
	if (amt_of_children > 1): # tthere is more than just the title
		var children = list.get_children();
		for i in range(amt_of_children - 1, 0, -1):
			list.remove_child(children[i]);
			children[i].queue_free();


func fill_out_devlog(text: String):
	var curr_filename = edit_button_ref.get_meta("name");
	if (check_filename(curr_filename) == "devlog"):
		var split_text = text.rsplit("\n");
		var post_data = {
			"filename": curr_filename, "creation_date": split_text[1],
			"post_title": split_text[2], "post_summary": split_text[3]
		};
		
		var str_len = 0;
		for i in range(4): # get the start of the text body
			str_len += split_text[i].length();
		post_data["post_body"] = text.substr(str_len + 4, -1); # 4 of \n
		
		fill_in_details.emit(post_data);
	else:
		create_notif_popup.emit("Not a recognizable file name!\nPlease edit a different file.");


func check_filename(curr_filename: String) -> String:
	var regex = RegEx.new();
	regex.compile("^(\\d{4})_(\\d{2})_(\\d{2})");
	var matches = regex.search(curr_filename);
	if (matches):
		return "devlog";
	
	return "";


func get_edit_ref():
	return edit_button_ref;


func set_edit_ref(updated):
	edit_button_ref = updated;


## Update the directory given a filename and an action 
## action: String, "add_filename" / "delete_filename" 
func update_directory(filename: String, action: String):
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	var directory_path = config.get_value("repo_info", "content_path") + directory["name"];
	var result = null;
	if (directory["data"] == ""): # didn't get directory yet, else follow local dir data
		result = request.get_file(self, "get_directory", directory_path);
		if (result.has("error")):
			create_error_popup.emit(result["error"], result["error_type"]);
			return;
		
		await result["request_signal"];
	
	var commit_data = { "sha": directory["sha"] };
	var update_content = directory["data"];
	var trimmed_filename = filename.trim_suffix("." + filename.get_extension());
	
	if (action == "add_filename"):
		update_content = trimmed_filename + "\n" + directory["data"];
		commit_data["msg"] = "Add devlog to directory!";
	elif (action == "delete_filename"):
		var index = directory["data"].find(trimmed_filename);
		if (index == -1): return;
		update_content = directory["data"].erase(index, trimmed_filename.length() + 1); # + '\n'
		commit_data["msg"] = "Delete devlog from directory!";
	
	commit_data["content"] = update_content;
	
	# Update directory with modified content
	result = request.create_update_file(self, "edit_directory", directory_path, commit_data);
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);
		return;
