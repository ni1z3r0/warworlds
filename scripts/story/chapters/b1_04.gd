extends RefCounted
## Book One, IV. The Cylinder Opens.


static func data() -> Dictionary:
	var pines := []
	for p in [Vector2(120, 300), Vector2(200, 420), Vector2(150, 560), Vector2(280, 330), Vector2(260, 640), Vector2(330, 480), Vector2(1400, 200), Vector2(1450, 700)]:
		pines.append({"kind": "pine", "pos": p, "r": 28.0})
	return {
		"title": "IV. The Cylinder Opens",
		"place": "The pit on Horsell Common, at sunset",
		"ground": "heath",
		"light": Color(1.0, 0.72, 0.55),
		"player": {"as": "narrator", "pos": Vector2(900, 860)},
		"npcs": [
			{"id": "stent", "pos": Vector2(900, 330), "coat": Color(0.15, 0.15, 0.18)},
			{"id": "boy", "name": "A boy", "pos": Vector2(760, 640), "coat": Color(0.4, 0.3, 0.2)},
		],
		"voices": {"voice": "A voice in the crowd"},
		"crowd": [
			{"rect": Rect2(600, 260, 170, 360), "n": 16, "face": Vector2(900, 430)},
			{"rect": Rect2(1030, 260, 170, 360), "n": 16, "face": Vector2(900, 430)},
			{"rect": Rect2(760, 570, 280, 90), "n": 10, "face": Vector2(900, 430)},
		],
		"panic_from": Vector2(900, 430),
		"props": pines + [
			{"kind": "road", "pts": [Vector2(0, 820), Vector2(1600, 800)]},
			{"kind": "pit", "pos": Vector2(900, 430), "r": 110.0},
			{"kind": "cylinder", "pos": Vector2(900, 430)},
		],
		"areas": {"edge": Rect2(700, 560, 400, 140), "trees": Rect2(60, 250, 320, 460)},
		"labels": [["the pine woods", Vector2(140, 240)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "You come back to the common at sunset. The crowd is larger than ever, and \"I had the sunset in my eyes.\""],
			]},
			{"goal": "Push through the crowd to the edge of the pit", "when": {"reach": "edge"}, "do": [
				["say", "stent", "Keep back! Keep back!"],
				["say", "boy", ["It's a-movin',", "a-screwin' and a-screwin' out. I don't like it. I'm a-goin' 'ome, I am."]],
				["move", "boy", Vector2(700, 960), 90.0],
			]},
			{"goal": "Watch the cylinder", "when": {"after": 1.5}, "do": [
				["open_cylinder"],
				["narr", "\"the lid of the cylinder fell upon the gravel with a ringing concussion.\" \"I think everyone expected to see a man emerge\""],
				["martian", Vector2(990, 430)],
				["plate", "plate_0043.jpg", "\"Those who have never seen a living Martian can scarcely imagine the strange horror of its appearance.\""],
				["panic"],
				["say", "voice", "He's fallen in the pit!"],
			]},
			{"goal": "Get away from the pit: run for the pine woods to the west", "when": {"reach": "trees"}, "do": [
				["narr", "Among the trees you stop and turn. \"I was a battleground of fear and curiosity.\""],
				["end"],
			]},
		],
	}
