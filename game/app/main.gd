extends Control
## Deliberately small technical shell, NOT a canonical town or gameplay slice.

var _session: GameSession
var _status: Label

func _ready() -> void:
    _session = GameSession.new()
    var content := VBoxContainer.new()
    content.position = Vector2(28, 28)
    content.custom_minimum_size = Vector2(660, 0)
    add_child(content)

    var heading := Label.new()
    heading.text = "Behind the Lanterns — Runtime Foundation"
    content.add_child(heading)

    _status = Label.new()
    content.add_child(_status)

    var advance_button := Button.new()
    advance_button.text = "Advance one in-game day (debug)"
    advance_button.pressed.connect(_advance_one_day)
    content.add_child(advance_button)

    var note := Label.new()
    note.text = "Technical foundation only. No town, NPCs or production gameplay yet."
    content.add_child(note)
    _refresh()

func _advance_one_day() -> void:
    _session.advance_to(_session.clock.current_minute() + WorldClock.MINUTES_PER_DAY)
    _refresh()

func _refresh() -> void:
    var now := _session.clock.current_minute()
    _status.text = "World minute: %d · Day: %d · Pending events: %d" % [
        now, int(now / WorldClock.MINUTES_PER_DAY) + 1,
        _session.scheduler.pending_count()
    ]
