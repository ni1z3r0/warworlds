extends RefCounted
## Book One, I. The Eve of the War: the observatory at Ottershaw.


static func data() -> Dictionary:
	return {
		"title": "I. The Eve of the War",
		"place": "Ogilvy's observatory at Ottershaw, near midnight",
		"ground": "floor",
		"light": Color(0.32, 0.33, 0.48),
		"lantern": true,
		"lanterns": [Vector2(1010, 640)],
		"round_room": {"c": Vector2(800, 470), "r": 330.0, "door": PI / 2},
		"player": {"as": "narrator", "pos": Vector2(800, 730)},
		"npcs": [{"id": "ogilvy", "pos": Vector2(930, 540), "coat": Color(0.25, 0.22, 0.2)}],
		"props": [
			{"kind": "telescope", "id": "telescope", "pos": Vector2(800, 420), "prompt": "look through the telescope", "reach": 90.0},
			{"kind": "table", "pos": Vector2(600, 330)},
			{"kind": "siphon", "pos": Vector2(615, 325)},
			{"kind": "lantern", "pos": Vector2(1010, 640)},
		],
		"areas": {"door": Rect2(720, 805, 160, 95)},
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "You have come up to Ottershaw at Ogilvy's invitation, \"to take a turn with him that night in a scrutiny of the red planet.\""],
				["narr", "\"the black and silent observatory, the shadowed lantern throwing a feeble glow upon the floor in the corner, the steady ticking of the clockwork of the telescope, the little slit in the roof\""],
			]},
			{"goal": "Talk to Ogilvy", "when": {"talk": "ogilvy"}, "do": [
				["narr", "\"Ogilvy moved about, invisible but audible.\" He has been watching the outbreaks of gas on Mars all week, and offers you the eyepiece."],
			]},
			{"goal": "Look through the telescope", "when": {"use": "telescope"}, "do": [
				["narr", "\"Looking through the telescope, one saw a circle of deep blue and the little round planet swimming in the field.\""],
				["scope"],
				["narr", "\"A reddish flash at the edge, the slightest projection of the outline just as the chronometer struck midnight\""],
			]},
			{"goal": "Tell Ogilvy what you saw", "when": {"talk": "ogilvy"}, "do": [
				["narr", "Ogilvy takes your place at the eyepiece, and exclaims at \"the streamer of gas that came out towards us.\""],
				["say", "ogilvy", "The chances against anything manlike on Mars are a million to one"],
				["narr", "\"That night another invisible missile started on its way to the earth from Mars, just a second or so under twenty-four hours after the first one.\""],
			]},
			{"goal": "Go home (the door is behind you)", "when": {"reach": "door"}, "do": [
				["narr", "You walk home to Maybury under the stars. \"I never dreamed of it then as I watched; no one on earth dreamed of that unerring missile.\""],
				["end"],
			]},
		],
	}
