class_name InkDialogue
extends RefCounted
## Only boundary depending on inkgd. Replays bounded choice/context records;
## save data never feeds arbitrary Ink VM state into the third-party loader.
const MAX_TURNS: int = 32
const MAX_LINES: int = 128

static func render(compiled: String, turns: Array) -> Dictionary:
	if turns.is_empty() or turns.size() > MAX_TURNS: return {}
	var root: Window = Engine.get_main_loop().root
	if root.get_node_or_null("__InkRuntime") == null:
		var runtime: Node = load("res://addons/inkgd/ink_runtime.gd").new()
		runtime.stop_execution_on_error = false
		runtime.stop_execution_on_exception = false
		root.add_child(runtime)
	var story := InkStory.new(compiled)
	var frame: Dictionary = {}
	for turn_index in turns.size():
		var turn: Variant = turns[turn_index]
		if not WorldData.keys(turn, ["choice", "context"]) or not turn.context is Dictionary: return {}
		for key in turn.context:
			if not turn.context[key] is bool: return {}
			story.variables_state.set_variable(key, turn.context[key])
		if turn_index == 0:
			if turn.choice != -1: return {}
		else:
			if not WorldData.integer(turn.choice, 0, story.current_choices.size() - 1): return {}
			story.choose_choice_index(int(turn.choice))
		var lines: PackedStringArray = []
		var actions: Array = []
		var budget := 0
		while story.can_continue:
			budget += 1
			if budget > MAX_LINES: return {}
			var line := story.continue_story().strip_edges()
			if not line.is_empty(): lines.append(line)
			for tag in story.current_tags:
				if not str(tag).begins_with("command:"): return {}
				actions.append(str(tag).trim_prefix("command:").strip_edges())
		if story.has_error or story.has_warning: return {}
		var choices: Array = []
		for choice in story.current_choices: choices.append(choice.text.strip_edges())
		frame = {"text": "\n".join(lines), "choices": choices, "actions": actions, "ended": choices.is_empty()}
	return frame
