extends RefCounted
## Disposable model proving time-anchored reconciliation, NOT production Farming.

static func is_mature(crop: Dictionary, now_minute: int) -> bool:
    if not crop.get("soil_compatible", false):
        return false
    var planted_at := int(crop.get("planted_at", -1))
    var growth_minutes := int(crop.get("growth_minutes", -1))
    var required_waterings := int(crop.get("required_waterings", -1))
    if planted_at < 0 or growth_minutes < 0 or required_waterings < 0:
        return false
    if now_minute < planted_at + growth_minutes:
        return false
    var watering_count := 0
    for watering_at in crop.get("watered_at", []):
        if int(watering_at) >= planted_at and int(watering_at) <= now_minute:
            watering_count += 1
    return watering_count >= required_waterings
