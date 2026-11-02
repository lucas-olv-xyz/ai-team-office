extends Node
class_name WsClient

## Conecta ao backend Python (a operação). Se não houver backend,
## fica tentando reconectar a cada 3s e o escritório mostra tarefas locais.

signal message_received(data: Dictionary)
signal connection_changed(connected: bool)

var url := "ws://127.0.0.1:8765"
var agent_names: PackedStringArray = []

var _peer := WebSocketPeer.new()
var _connected := false
var _retry := 0.0


func _ready() -> void:
	_peer.connect_to_url(url)


func _process(delta: float) -> void:
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				connection_changed.emit(true)
				_send({"type": "hello", "agents": agent_names})
			while _peer.get_available_packet_count() > 0:
				var data = JSON.parse_string(_peer.get_packet().get_string_from_utf8())
				if data is Dictionary:
					message_received.emit(data)
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				connection_changed.emit(false)
			_retry += delta
			if _retry > 3.0:
				_retry = 0.0
				_peer = WebSocketPeer.new()
				_peer.connect_to_url(url)


func send_message(obj: Dictionary) -> void:
	_send(obj)


func _send(obj: Dictionary) -> void:
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(JSON.stringify(obj))
