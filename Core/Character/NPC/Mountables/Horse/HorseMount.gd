extends Node3D

class_name HorseMount


@onready var animation_tree: AnimationTree = $AnimationTree

var locomotion_state_machine_playback: AnimationNodeStateMachinePlayback

@onready var snort_audio: AudioStreamPlayer3D = $Audio/SnortAudio
@onready var neigh_audio: AudioStreamPlayer3D = $Audio/NeighAudio
@onready var foot_step_audio: AudioStreamPlayer3D = $Audio/FootStepAudio

@onready var neigh_or_snort_timer: Timer = $NeighOrSnortTimer


var last_snort_audio_index: int = 0
var last_neigh_audio_index: int = 0


var horse_snort_audio_streams: Array[Resource] = [
	preload("res://Assets/Audio/Foley/horse/snort/538697__brunoauzet__horse-snort_1.mp3"),
	preload("res://Assets/Audio/Foley/horse/snort/538697__brunoauzet__horse-snort-2.mp3"),
	preload("res://Assets/Audio/Foley/horse/snort/538697__brunoauzet__horse-snort-4.mp3"),
	preload("res://Assets/Audio/Foley/horse/snort/538697__brunoauzet__horse-snort-5.mp3"),
]

var horse_neigh_audio_streams: Array[Resource] = [
	preload("res://Assets/Audio/Foley/horse/neigh/510903__lydmakeren__horse_neighing_1.mp3"),
	preload("res://Assets/Audio/Foley/horse/neigh/510903__lydmakeren__horse_neighing_2.mp3"),
	preload("res://Assets/Audio/Foley/horse/neigh/510903__lydmakeren__horse_neighing_3.mp3"),
	preload("res://Assets/Audio/Foley/horse/neigh/510903__lydmakeren__horse_neighing_4.mp3"),
]

func _ready() -> void:
	locomotion_state_machine_playback = animation_tree.get("parameters/LocomotionStateMachine/playback") as AnimationNodeStateMachinePlayback
	#locomotion_state_machine_playback.travel("idle")
	neigh_or_snort_timer.start(randi_range(10.0, 30.0))
	neigh_or_snort_timer.timeout.connect(_on_neigh_or_snort_timer_timeout)

func play_random_audio(audio_player: AudioStreamPlayer3D, audio_streams: Array[Resource], last_index: int) -> int:
	var audio_index = randi_range(0, audio_streams.size() - 1) # Select a random audio clip to play
	if audio_index == last_index: # Select the next clip in the list if we select the same sound 2 times in a row.
		audio_index = (audio_index + 1) % audio_streams.size()
	var audio_stream = audio_streams[audio_index]
	audio_player.stream = audio_stream
	audio_player.play()
	return audio_index # Return the last audio index played, caller must store it and pass it in next time so we don't play the same sound twice

func play_snort_audio():
	last_snort_audio_index = play_random_audio(neigh_audio, horse_snort_audio_streams, last_snort_audio_index)

func play_neigh_audio():
	last_neigh_audio_index = play_random_audio(neigh_audio, horse_neigh_audio_streams, last_neigh_audio_index)

func play_footstep_audio():
	pass

func _on_neigh_or_snort_timer_timeout() -> void:
	play_snort_audio()
	#if randi_range(0, 1) == 0:
		#play_snort_audio()
	#else:
		#play_neigh_audio()
	neigh_or_snort_timer.start(randi_range(10.0, 30.0))
