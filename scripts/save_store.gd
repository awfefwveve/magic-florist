extends RefCounted

# Client-side deterrence only. Never treat this embedded key as a server secret.
const PASSWORD: String = "MagicFlorist.local.v1.2026"
const SIGN_KEY: String = "flower-garden-envelope-v1"
var base: String
var writable: bool = true
var status: String = ""

func _init(path: String = "user://garden") -> void:
	base = path

func signature(body: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, SIGN_KEY.to_utf8_buffer(), body.to_utf8_buffer()).hex_encode()

func read_slot(path: String, state: RefCounted) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, PASSWORD)
	if file == null:
		return {}
	var envelope: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not envelope is Dictionary or not envelope.has_all(["body", "signature"]):
		return {}
	if not envelope.body is String or not envelope.signature is String or signature(envelope.body) != envelope.signature:
		return {}
	var data: Variant = JSON.parse_string(envelope.body)
	if not state.valid(data):
		return {}
	return data

func load_into(state: RefCounted) -> bool:
	var data: Dictionary = read_slot(base + ".sav", state)
	if not data.is_empty():
		var old_version: bool = int(data.get("version",0)) < int(state.snapshot().version)
		var original: String = base + ".v%d-original" % int(data.version)
		if old_version and not FileAccess.file_exists(original):
			if DirAccess.copy_absolute(base + ".sav", original) != OK:
				writable = false
				status = "이전 버전 원본을 보존하지 못해 자동 저장을 중지했어요."
				return state.restore(data)
		state.restore(data)
		status = "이전 버전 저장을 변환하고 원본을 별도로 보존했어요." if old_version else "저장한 꽃집을 불러왔어요."
		return true
	var backup: Dictionary = read_slot(base + ".bak", state)
	if not backup.is_empty():
		var original: String = base + ".v%d-original" % int(backup.version)
		if int(backup.version) < int(state.snapshot().version) and not FileAccess.file_exists(original):
			if DirAccess.copy_absolute(base + ".bak", original) != OK:
				writable = false
				status = "이전 버전 백업 원본을 보존하지 못해 자동 저장을 중지했어요."
				return state.restore(backup)
		state.restore(backup)
		status = "이전 백업에서 꽃집을 복구했어요."
		return true
	if FileAccess.file_exists(base + ".sav") or FileAccess.file_exists(base + ".bak"):
		writable = false
		status = "저장을 읽지 못했어요. 원본을 보존하며 임시 플레이합니다. 자동 저장은 중지됐어요."
	return false

func save(state: RefCounted) -> bool:
	if not writable:
		return false
	var data: Dictionary = state.snapshot()
	if not state.valid(data):
		status = "진행 상태를 확인하지 못해 저장을 보류했어요."
		return false
	var body: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open_encrypted_with_pass(base + ".tmp", FileAccess.WRITE, PASSWORD)
	if file == null:
		status = "저장 공간에 쓸 수 없어요."
		return false
	file.store_string(JSON.stringify({"body": body, "signature": signature(body)}))
	file.flush()
	file.close()
	if read_slot(base + ".tmp", state).is_empty():
		status = "새 저장 파일 검증에 실패했어요. 이전 저장은 보존했어요."
		return false
	if FileAccess.file_exists(base + ".sav"):
		var old_valid: bool = not read_slot(base + ".sav", state).is_empty()
		var destination: String = base + ".bak" if old_valid else base + ".rejected-" + str(Time.get_unix_time_from_system())
		if DirAccess.copy_absolute(base + ".sav", destination) != OK:
			status = "기존 파일 백업에 실패해 저장을 보류했어요."
			return false
		if DirAccess.remove_absolute(base + ".sav") != OK:
			return false
	if DirAccess.rename_absolute(base + ".tmp", base + ".sav") != OK:
		status = "저장 파일 교체에 실패했어요. 백업은 보존했어요."
		return false
	status = "자동 저장됨"
	return true
