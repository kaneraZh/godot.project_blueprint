@tool
extends Node

const MUTE_DB:float = -80.0
static func get_bus_volume_normalized(bus_idx:int):
	assert(AudioServer.get_bus_count()>bus_idx, "<bus_idx:%s> solicited is out of range"%bus_idx)
	return pow(2.0, AudioServer.get_bus_volume_db(bus_idx) / 10.0)
static func set_bus_volume_normalized(bus_idx:int, volume:float):
	assert(AudioServer.get_bus_count()>bus_idx, "<bus_idx:%s> solicited is out of range"%bus_idx)
	var vol:float = log(volume)*10.0 / log(2.0)
	AudioServer.set_bus_volume_db(bus_idx, vol if (vol>MUTE_DB) else MUTE_DB)

func _init():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	ProjectSettings.connect(&"settings_changed", Callable(self, &"_on_project_settings_update"), CONNECT_DEFERRED)
static func _on_project_settings_update():
	if(ProjectSettings.has_setting("custom/audio/master/volume_normalized")):
		set_bus_volume_normalized(
			AudioServer.get_bus_index(&"master"),
			ProjectSettings.get_setting("custom/audio/master/volume_normalized")
		)
	if(ProjectSettings.has_setting("custom/audio/sfx/volume_normalized")):
		set_bus_volume_normalized(
			AudioServer.get_bus_index(&"sfx"),
			ProjectSettings.get_setting("custom/audio/sfx/volume_normalized")
		)
	if(ProjectSettings.has_setting("custom/audio/music/volume_normalized")):
		set_bus_volume_normalized(
			AudioServer.get_bus_index(&"music"),
			ProjectSettings.get_setting("custom/audio/music/volume_normalized")
		)

var _player:MusicPlayer : get=get_player, set=_set_player
func get_player()->MusicPlayer: return _player
func _set_player(player:MusicPlayer)->void:
	_player = player
	_player.set_bus(&"music")
var _track:AudioStream : set=_set_track_current, get=get_track_current
func get_track_current()->AudioStream: return _track
func _set_track_current(m:AudioStream)->void:
	_track = m
	_player.set_stream(_track)
func is_fading()->bool:	return _player.is_fading()
func play(time:float)->void:
	assert(_track!=null, "<_track> is <null>")
	_player.connect(&"fade_start", Callable(_player, &"set_stream_paused").bind(true), CONNECT_ONE_SHOT)
	_player.fade_in(time)
func pause(time:float)->void:
	_player.connect(&"fade_end", Callable(_player, &"set_stream_paused").bind(false), CONNECT_ONE_SHOT)
	_player.fade_out(time)
func _set_next(track:AudioStream, fade_out:float=1.0, inbetween_tracks:float=0.0, fade_in:float=0.0)->void:
	
	if(	fade_out		== 0.0 &&
		inbetween_tracks== 0.0 &&
		fade_in			== 0.0 ):
		if(track!=_track): _set_track_current(track)
	else:
		if(track!=_track): _player.connect(&"fade_end", Callable(self, &"_set_track_current").bind(track), CONNECT_ONE_SHOT)
		_player.fade_out_in(fade_out, inbetween_tracks, fade_in)

var music_layers:Array[AudioStream] = [null,null,null]
func _update_track(fade_out:float=1.0, inbetween_tracks:float=0.0, fade_in:float=0.0)->void:
	var new_current:AudioStream = null
	var music:Array[AudioStream] = music_layers.duplicate()
	music.reverse()
	for stream in music:
		if(stream != null):new_current = stream
	_set_next(new_current, fade_out, inbetween_tracks, fade_in)
enum LAYER {WORLD, SCENE, DIALOG}
func set_world(track:AudioStream, fade_out:float=1.0, inbetween_tracks:float=0.0, fade_in:float=0.0):
	music_layers[LAYER.WORLD] = track
	_update_track(fade_out, inbetween_tracks, fade_in)
func set_scene(track:AudioStream, fade_out:float=1.0, inbetween_tracks:float=0.0, fade_in:float=0.0):
	music_layers[LAYER.SCENE] = track
	_update_track(fade_out, inbetween_tracks, fade_in)
func set_dialog(track:AudioStream, fade_out:float=1.0, inbetween_tracks:float=0.0, fade_in:float=0.0):
	music_layers[LAYER.DIALOG] = track
	_update_track(fade_out, inbetween_tracks, fade_in)

func play_sfx(s:AudioStream):
	var sfx:AudioStreamPlayer = AudioStreamPlayer.new()
	sfx.set_bus(&"SFX")
	sfx.set_stream(s)
	sfx.connect(&"finished", Callable(sfx, &"queue_free"))
	add_child(sfx)
	sfx.play()
