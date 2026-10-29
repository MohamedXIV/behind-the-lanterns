class_name SessionCodec
extends RefCounted
## JSON representation only. File-system recovery and defeat checkpoints are separate work.

static func encode(session: GameSession) -> String:
    var data := session.snapshot()
    if data.is_empty():
        return ""
    return JSON.stringify(data)

static func decode(json_text: String) -> GameSession:
    if json_text.is_empty():
        return null
    var data: Variant = JSON.parse_string(json_text)
    return GameSession.from_snapshot(data)
