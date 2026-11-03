extends RefCounted
## Book One, II. The Falling Star: Ogilvy finds the cylinder at dawn.


static func data() -> Dictionary:
	var pines := []
	for p in [Vector2(520, 160), Vector2(620, 240), Vector2(700, 130), Vector2(760, 700), Vector2(860, 760), Vector2(980, 160), Vector2(1450, 220), Vector2(1500, 650), Vector2(1380, 760), Vector2(600, 520), Vector2(460, 420)]:
		pines.append({"kind": "pine", "pos": p, "r": 24.0})
	return {
		"title": "II. The Falling Star",
		"place": "Horsell Common, at dawn. You are Ogilvy, the astronomer.",
		"ground": "heath",
		"light": Color(0.9, 0.8, 0.75),
		"player": {"as": "ogilvy", "pos": Vector2(820, 860), "coat": Color(0.25, 0.22, 0.2)},
		"npcs": [{"id": "henderson", "pos": Vector2(300, 590), "coat": Color(0.3, 0.28, 0.24)}],
		"props": pines + [
			{"kind": "road", "pts": [Vector2(140, 0), Vector2(150, 320), Vector2(130, 900)]},
			{"kind": "pit", "pos": Vector2(1150, 430), "r": 100.0},
			{"kind": "cylinder", "id": "cylinder", "pos": Vector2(1150, 430), "prompt": "examine the cylinder", "reach": 140.0},
			{"kind": "house", "rect": Rect2(190, 660, 150, 100), "label": "Henderson's house"},
			{"kind": "fence", "pts": [Vector2(180, 540), Vector2(400, 540), Vector2(400, 780)]},
		],
		"areas": {"pit": Rect2(980, 290, 340, 280)},
		"labels": [["to Horsell", Vector2(160, 30)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "\"Then came the night of the first falling star.\" At dawn Ogilvy, who saw it fall, goes out alone onto Horsell Common to find it. You are Ogilvy."],
			]},
			{"goal": "Find the fallen star, by the sand-pits to the east", "when": {"reach": "pit"}, "do": [
				["narr", "\"He was all alone on the common.\""],
				["plate", "plate_0035.jpg", "Half buried in a great pit of sand: not a stone at all, but an enormous metal cylinder, still hot from its fall."],
			]},
			{"goal": "Examine the cylinder", "when": {"use": "cylinder"}, "do": [
				["narr", "Ogilvy noticed \"that some of the grey clinker, the ashy incrustation that covered the meteorite, was falling off the circular edge of the end.\""],
				["narr", "\"Something within the cylinder was unscrewing the top!\""],
				["say", "ogilvy", ["Good heavens!", "There's a man in it—men in it! Half roasted to death! Trying to escape!"]],
			]},
			{"goal": "Run for help: find someone in the town, to the west", "when": {"talk": "henderson"}, "do": [
				["say", "ogilvy", ["Henderson,", "you saw that shooting star last night?"]],
				["say", "henderson", "Well?"],
				["say", "ogilvy", "It's out on Horsell Common now."],
				["say", "henderson", ["Good Lord!", "Fallen meteorite! That's good."]],
				["say", "ogilvy", "But it's something more than a meteorite. It's a cylinder—an artificial cylinder, man! And there's something inside."],
				["say", "henderson", "What's that?"],
				["narr", "\"He was deaf in one ear.\" Ogilvy tells him everything. \"Then he dropped his spade, snatched up his jacket, and came out into the road.\""],
				["move", "henderson", Vector2(160, 300), 80.0],
				["narr", "\"The two men hurried back at once to the common\""],
				["end"],
			]},
		],
	}
