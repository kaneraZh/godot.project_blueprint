class_name MusicPlayer
extends AudioStreamPlayer

#func _init(): set_autoplay(true)

# Both normalized functions recive inputs on whichever
# value, put prefferably its mapped from 0.0 to 1.0,
# thus being called normalized, on godot it makes sense
# calling them up to value of 5.0, whuch would be 23.2...
# decibels, aproaching Godot's limit of 24.
# If the input value is 0.0, then the function will 
# default to mute_db in order to not set the decibel
# levels to negative infinity, as godot would default it
# to, mute_db is customizable, but its the minimum godot
# admits when setting an audio output in decibels.
# The function itslf is a log base 2 value v (for volume)
# times 10 ( log2(v)*10.0  on Python )
const MUTE_DB:float = -80.0
func get_volume_normalized():
	return pow(2.0, get_volume_db() / 10.0)
func set_volume_normalized(volume:float):
	var vol:float = log(volume)*10.0 / log(2.0)
	set_volume_db( vol if (vol>MUTE_DB) else MUTE_DB )

signal fade_start
signal fade_end
var _fading:bool=false: set=_set_fading, get=is_fading
func is_fading()->bool: return _fading
func _set_fading(f:bool)->void: _fading = f
func _fade(
	target_volume_normalized:float,
	time:float,
)->void:
	assert(time>=0.0, "cannot fade to a negative time")
	match time:
		0.0:
			emit_signal(&"fade_start")
			set_volume_normalized(target_volume_normalized)
			emit_signal(&"fade_end")
		_:
			var current_volume_normalized:float = get_volume_normalized()
			var t:Tween = get_tree().create_tween().bind_node(self)
			t.tween_method(Callable(self, &"set_volume_normalized"), current_volume_normalized, target_volume_normalized, time)
			t.connect(&"tween_all_completed", Callable(self, &"emit_signal").bind([&"fade_end", target_volume_normalized]))
			t.connect(&"tween_all_completed", Callable(t, &"queue_free"))
			emit_signal(&"fade_start", current_volume_normalized)
			t.call_deferred(&"start")

func fade_in(time:float)->void:
	if(get_volume_normalized()==1.0):return
	if(!is_fading()): _fade(1.0, time)
	else:
		connect(&"faded_out", Callable(self, &"_fade").bindv([1.0, time]), CONNECT_DEFERRED+CONNECT_ONE_SHOT)
		print_debug("<fade_in> queued")
func fade_out(time:float)->void:
	if(get_volume_normalized()==0.0):return
	elif(!is_fading()): _fade(0.0, time)
	else:
		connect(&"faded_in", Callable(self, &"_fade").bindv([0.0, time]), CONNECT_DEFERRED+CONNECT_ONE_SHOT)
		print_debug("<fading_out> queued after <faded_in> is finished")
func fade_out_in(fade_out:float, inbetween_time:float=0.0, fade_in:float=0.0)->void:
	assert(inbetween_time>=0.0, "<inbetween_time:%s> cannot be negative"%inbetween_time)
	fade_out(fade_out)
	await get_tree().create_timer(fade_out+inbetween_time).timeout
	fade_in(fade_in)

func _init()->void:
	connect(&"fading_in", Callable(self, &"set_fading_in").bind(true))
	connect(&"faded_in", Callable(self, &"set_fading_in").bind(false))
	connect(&"fading_out", Callable(self, &"set_fading_out").bind(true))
	connect(&"faded_out", Callable(self, &"set_fading_out").bind(false))
