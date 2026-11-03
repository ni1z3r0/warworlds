extends RefCounted
## Book One, XI. At the Window: the artilleryman arrives.


static func data() -> Dictionary:
	return {
		"title": "XI. At the Window",
		"place": "Your house at Maybury, the small hours of Saturday",
		"ground": "floor",
		"light": Color(0.5, 0.45, 0.5),
		"lantern": true,
		"lanterns": [Vector2(1250, 270)],
		"player": {"as": "narrator", "pos": Vector2(440, 330)},
		"npcs": [{"id": "artilleryman", "pos": Vector2(1460, 300), "visible": false, "coat": Color(0.18, 0.2, 0.4)}],
		"walls": [
			Rect2(300, 150, 1000, 16), Rect2(300, 734, 1000, 16), Rect2(300, 150, 16, 600),
			Rect2(1284, 150, 16, 420), Rect2(1284, 640, 16, 110),
			Rect2(900, 400, 160, 16), Rect2(1140, 400, 144, 16), Rect2(900, 166, 16, 234),
			Rect2(560, 166, 16, 214), Rect2(560, 460, 16, 290),
		],
		"props": [
			{"kind": "stairs", "rect": Rect2(330, 180, 110, 200)},
			{"kind": "rug", "rect": Rect2(680, 470, 300, 180)},
			{"kind": "table", "pos": Vector2(830, 560)},
			{"kind": "table", "pos": Vector2(1080, 250)},
			{"kind": "window", "id": "window", "pos": Vector2(1284, 268), "prompt": "look out of the window", "reach": 90.0},
			{"kind": "door", "id": "door", "pos": Vector2(1292, 605), "prompt": "unfasten the door", "reach": 80.0},
			{"kind": "crate", "id": "pantry", "pos": Vector2(1220, 705), "prompt": "take food from the pantry", "reach": 60.0},
		],
		"areas": {"study": Rect2(920, 170, 360, 225)},
		"labels": [["Hall and stairs", Vector2(330, 420)], ["Dining room", Vector2(700, 460)], ["Your study (upstairs)", Vector2(930, 190)], ["Pantry", Vector2(1190, 680)], ["Garden", Vector2(1420, 200)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "You sit shivering at the foot of the stairs. Then \"I got up almost mechanically, went into the dining room and drank some whisky, and then I was moved to change my clothes.\""],
			]},
			{"goal": "Go up to your study", "when": {"reach": "study"}, "do": []},
			{"goal": "Look out of the study window", "when": {"use": "window"}, "do": [
				["plate", "plate_0059.jpg", "\"It seemed indeed as if the whole country in that direction was on fire\""],
				["narr", "You watch \"the three gigantic black things that were going to and fro in the glare about the sand-pits.\""],
				["narr", "\"Were they intelligent mechanisms? Such a thing I felt was impossible. Or did a Martian sit within each, ruling, directing, using, much as a man's brain sits and rules in his body?\""],
				["show", "artilleryman", true],
				["move", "artilleryman", Vector2(1380, 300), 40.0],
				["narr", "Mars is setting, \"when a soldier came into my garden.\""],
			]},
			{"goal": "Call down to the soldier from the window", "when": {"use": "window"}, "do": [
				["say", "narrator", "Hist!"],
				["say", "artilleryman", "Who's there?"],
				["say", "narrator", "Where are you going?"],
				["say", "artilleryman", "God knows."],
				["say", "narrator", "Are you trying to hide?"],
				["say", "artilleryman", "That's it."],
				["say", "narrator", "Come into the house,"],
				["move", "artilleryman", Vector2(1345, 605), 70.0],
			]},
			{"goal": "Go down and let him in (the door on the east side)", "when": {"use": "door"}, "do": [
				["move", "artilleryman", Vector2(1225, 605), 60.0],
				["say", "artilleryman", "My God!"],
				["say", "narrator", "What has happened?"],
				["say", "artilleryman", ["What hasn't?", "They wiped us out—simply wiped us out,"]],
				["move", "artilleryman", Vector2(830, 500), 60.0],
			]},
			{"goal": "Give him whisky, in the dining room", "when": {"talk": "artilleryman"}, "do": [
				["say", "narrator", "Take some whisky,"],
				["narr", "\"He drank it. Then abruptly he sat down before the table, put his head on his arms, and began to sob and weep like a little boy\""],
				["narr", "\"He was a driver in the artillery, and had only come into action about seven.\""],
				["say", "artilleryman", ["I lay still,", "scared out of my wits, with the fore quarter of a horse atop of me. We'd been wiped out. And the smell—good God! Like burnt meat!"]],
				["narr", "He tells you how it fought. \"A kind of arm carried a complicated metallic case, about which green flashes scintillated, and out of the funnel of this there smoked the Heat-Ray.\""],
			]},
			{"goal": "He has eaten nothing since midday. Fetch food from the pantry", "when": {"use": "pantry"}, "do": [
				["narr", "\"I found some mutton and bread in the pantry and brought it into the room.\""],
			]},
			{"goal": "Bring it to him", "when": {"talk": "artilleryman"}, "do": [
				["narr", "\"We lit no lamp for fear of attracting the Martians, and ever and again our hands would touch upon bread or meat.\""],
			]},
			{"goal": "At dawn, go back up to the study window", "when": {"use": "window"}, "do": [
				["narr", "\"In one night the valley had become a valley of ashes.\""],
				["narr", "\"three of the metallic giants stood about the pit, their cowls rotating as though they were surveying the desolation they had made.\""],
				["end"],
			]},
		],
	}
