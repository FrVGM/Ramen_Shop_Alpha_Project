extends AudioStreamPlayer
# No necesitamos class_name si lo registras en Autoload, 
# se llamará 'AudioManager' en todo el juego.

var playlist: Array[AudioStream] = [
	preload("res://Audio/OST/OST1.mp3"),
	preload("res://Audio/OST/OST2.mp3"),
	preload("res://Audio/OST/OST3.mp3"),
	preload("res://Audio/OST/OST4.mp3"),
	preload("res://Audio/OST/OST5.mp3"),
	preload("res://Audio/OST/OST6.mp3"),
	preload("res://Audio/OST/OST7.mp3")
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Para que suene incluso en pausa
	bus = "Music" # Asegúrate de tener un bus llamado 'Music' en tu mezclador
	self.finished.connect(_on_song_finished)

func play_daily_song(day: int):
	if playlist.is_empty(): return
	
	# Calculamos la canción del día
	var index = (day - 1) % playlist.size()
	var new_song = playlist[index]

	if stream == new_song and playing:
		return

	# EFECTO CROSSFADE (Transición suave)
	var tween = create_tween()
	# Bajamos volumen
	tween.tween_property(self, "volume_db", -80.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	tween.tween_callback(func():
		stream = new_song
		play()
	)
	
	# Subimos volumen a 0dB (o tu volumen preferido)
	tween.tween_property(self, "volume_db", 0.0, 1.5).set_trans(Tween.TRANS_SINE)

# Para los efectos de sonido rápidos (Hover/Click)
func play_sfx(sfx_stream: AudioStream):
	var asp = AudioStreamPlayer.new()
	asp.stream = sfx_stream
	asp.bus = "SFX"
	add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func _on_song_finished():
	# Cuando la canción termina, simplemente le damos Play otra vez
	play()
