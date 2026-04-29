extends MarginContainer

# =====================
# ======= Nodes =======
# =====================

@onready var list = $ScrollContainer/List;

# =====================
# ===== Variables =====
# =====================

var devlogs = {};
var edit_devlog = {}; #"name": "", "sha": "", "decoded_content": ""
var delete_devlog = {}; # "decoded_content", "folder_name": ""

# =====================
# ====== Signals ======
# =====================

signal connect_startup(component: String);
signal clear_post;
signal fill_in_details(post_info: Dictionary);
signal delete_a_devlog(delete_devlog: Dictionary);
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
	var result = request.get_files(self, "get_devlogs_files", devlogs_path);
	
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
							devlogs[entry["name"]] = { "sha": entry["sha"], "git_url": entry["git_url"] };
					setup_devlogs_list();
				"get_devlog_to_edit":
					edit_devlog["name"] = response["name"];
					edit_devlog["sha"] = response["sha"];
					edit_devlog["decoded_content"] = Marshalls.base64_to_utf8(response["content"]);
					fill_in_devlog();
				"get_devlog_to_delete":
					delete_devlog["decoded_content"] = Marshalls.base64_to_utf8(response["content"]);
				_:
					pass;
		_:
			pass;
	
	msg = request.build_notif_msg(action, response_code, body_str);
	if (msg != ""): create_notif_popup.emit(msg);


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


func _on_delete_button_pressed(folder_name: String):
	create_action_popup.emit(
		"Are you sure you want to delete this post?\nIf you're currently editing it, it will be cleared too.",
		{ 'yes': "Delete devlog", 'no': "Cancel" },
		_on_serious_delete_button_pressed.bind(folder_name) 
	);


func _on_serious_delete_button_pressed(folder_name: String):
	var request = Requests.new();
	var config = request.load_config();
	if (!config is ConfigFile):
		create_error_popup.emit(config["error"], config["error_type"]);
		return;
	
	var devlog_path = config.get_value("repo_info", "content_path") + folder_name + "/" + folder_name + ".txt";
	var result = request.get_files(self, "get_devlog_to_delete", devlog_path);
	
	if (result.has("error")):
		create_error_popup.emit(result["error"], result["error_type"]);
		return;
	 
	delete_devlog["folder_name"] = folder_name;
	
	await result["request_signal"];
	
	delete_a_devlog.emit(delete_devlog);


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
		create_post_info(devlog_name);

## Deletes the devlog nodes in the list.
func clear_list():
	var amt_of_children = list.get_child_count();
	if (amt_of_children > 1): # if there is more than just the title
		var children = list.get_children();
		for i in range(amt_of_children - 1, 0, -1):
			list.remove_child(children[i]);
			children[i].queue_free();


func fill_in_devlog():
	var whole_devlog = edit_devlog["decoded_content"];
	var text_chunks = whole_devlog.rsplit("\n");
	var post_data = {
		"filename": edit_devlog["name"], "creation_date": text_chunks[1],
		"post_title": text_chunks[2], "post_summary": text_chunks[3]
	};
	
	var str_len = 0;
	for i in range(4): # get the start of the text body in character length
		str_len += text_chunks[i].length();
	post_data["post_body"] = whole_devlog.substr(str_len + 4, -1); # 4 of '\n' included
	
	fill_in_details.emit(post_data);
	
	#create_notif_popup.emit("Not a recognizable file name!\nPlease edit a different file.");


func get_edit_devlog():
	return edit_devlog;


func clear_edit_devlog():
	edit_devlog.clear();
