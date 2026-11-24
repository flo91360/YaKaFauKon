extends Control
## Fin de séance : la minuterie réglée par l'ergo est arrivée au bout. Le jeu est
## sauvegardé ; l'enfant voit un mot gentil et revient à la liste des joueurs.

signal closed # jamais émis : on ne referme pas ce panneau pour rejouer
signal finished

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var profile: Dictionary = get_node("/root/Game").profile
	var box := UiTheme.centered_panel(self, 640)
	var title := UiTheme.label("C'est l'heure !", 36, UiTheme.COL_ACCENT.darkened(0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := "Bravo pour cette séance, %s. Ton personnage t'attend pour la prochaine fois : tout est sauvegardé." % profile.get("name", "")
	var l := UiTheme.label(text, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	box.add_child(UiTheme.speak_button(func(): return "C'est l'heure ! " + text))
	var ok := UiTheme.button("Terminer", UiTheme.COL_GOOD, 26)
	ok.name = "Terminer"
	ok.pressed.connect(func(): finished.emit())
	box.add_child(ok)
