extends MarginContainer

## Description: This module is for displaying what the post will be sent/exported as.

# =====================
# ======= Nodes =======
# =====================

@onready var post_preview = $PostPreview;

# =====================
# ===== Variables =====
# =====================

var plain_text_post: String = "";

# =====================
# ====== Methods ======
# =====================

func update_preview(post_data: Dictionary):
	clear_text();
	
	var text = "";
	text += post_data["edit_date"] + "\n";
	text += post_data["creation_date"] + "\n";
	text += post_data["post_title"] + "\n";
	text += post_data["post_summary"] + "\n";
	text += post_data["post_body"];
	plain_text_post = text;
	
	process_post(post_data, post_data["post_images"]);


func process_post(post_data: Dictionary, img_list):
	post_preview.push_bold();
	post_preview.add_text(post_data["post_title"]);
	post_preview.pop();
	post_preview.newline();
	post_preview.newline();
	post_preview.push_italics();
	post_preview.add_text("Edited: ");
	post_preview.pop();
	post_preview.add_text(post_data["edit_date"]);
	post_preview.push_italics();
	post_preview.add_text("/ Created: ");
	post_preview.pop();
	post_preview.add_text(post_data["creation_date"]);
	post_preview.newline();
	post_preview.newline(); 
	
	var post_lines = post_data["post_body"].split("\n", true);
	
	for line in post_lines:
		if (line.contains("## >>")): # header
			post_preview.push_bold();
			var a_line = line.replace("#", "");
			post_preview.add_text(a_line);
			post_preview.pop();
			post_preview.newline();
		elif (line.contains("![")): # image
			var addt_txt = line.substr(0, line.find("!"));
			var addt_end_txt = line.substr(line.find(")") + 1);
			post_preview.add_text(addt_txt);
				
			var tex = get_image_texture(line, img_list);
			if (tex):
				post_preview.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER);
				post_preview.add_image(tex, 128);
				post_preview.pop();
			
			post_preview.add_text(addt_end_txt);
		elif (line.contains("http") && line.contains("[") && line.contains(")")): # url TODO better checks
			var link_begin = line.find("(");
			var link_end = line.find(")");
			var link_txt_begin = line.find("[");
			var link_txt_end = line.find("]");
			
			var addt_txt = line.substr(0, link_txt_begin);
			var addt_end_txt = line.substr(link_end + 1);
			post_preview.add_text(addt_txt);
			var url = line.substr(link_begin + 1, link_end - link_begin - 1);
			post_preview.push_meta(url);
			post_preview.add_text(line.substr(link_txt_begin + 1, link_txt_end - link_txt_begin - 1));
			post_preview.pop();
			post_preview.add_text(addt_end_txt);
		else: # regular
			post_preview.add_text(line);
		
		post_preview.newline();


func get_image_texture(img_line: String, img_list):
	var img_path = img_line.get_slice("(", 1);
	var link_end = img_path.find(")");
	img_path = img_path.substr(0, link_end); # if there are additional chars at the end
	
	var imgs = img_list.get_children();
	for x in range(1, imgs.size(), 1): #ignoring title
			var img_name = imgs[x].get_meta("file_path");
			if (img_name.replace("public", "") == img_path):
				var components = imgs[x].get_child(0).get_children(); # hbox holds all
				for component in components:
					if (component is TextureRect):
						return component.texture;
	
	return null;


func process_post_for_imgs(img_list):
	var post_lines = plain_text_post.split("\n", true);
	
	var imgs_in_devlog: Array[String] = [];
	for line in post_lines:
		if (line.contains("![")): # image link in markdown format
			var left_side = line.find("(");
			var right_side = line.find(")");
			imgs_in_devlog.append(line.substr(left_side + 1, right_side - left_side - 1));
	
	var file_paths = img_list.get_file_paths();
	var filenames = img_list.get_filenames();
	var dir_access = DirAccess.open("user://");
	
	var imgs_to_send: Array[String] = [];
	for img in imgs_in_devlog:
		var found_img_index = filenames.find(img);
		if (found_img_index != -1):
			var img_path = file_paths[found_img_index];
			if (dir_access.file_exists(img_path)):
				imgs_to_send.append(img_path);
	
	return imgs_to_send;


func clear_text():
	plain_text_post = "";
	post_preview.text = "";


# =====================
# ====== Getters ======
# =====================

func get_text():
	return plain_text_post;
