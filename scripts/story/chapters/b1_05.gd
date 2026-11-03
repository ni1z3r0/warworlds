extends RefCounted
## Book One, V. The Heat-Ray: the Deputation, and the flight across the common.


static func data() -> Dictionary:
	var props := [
		{"kind": "road", "pts": [Vector2(60, 0), Vector2(70, 900)]},
		{"kind": "pit", "pos": Vector2(1350, 450), "r": 100.0},
		{"kind": "cylinder", "pos": Vector2(1350, 450)},
	]
	for p in [Vector2(940, 640), Vector2(800, 520), Vector2(660, 640), Vector2(520, 500), Vector2(380, 620), Vector2(250, 480), Vector2(860, 760), Vector2(560, 360)]:
		props.append({"kind": "hummock", "pos": p, "r": 44.0})
	for p in [Vector2(300, 200), Vector2(420, 150), Vector2(200, 780), Vector2(700, 820), Vector2(1100, 200)]:
		props.append({"kind": "pine", "pos": p, "r": 24.0})
	return {
		"title": "V. The Heat-Ray",
		"place": "Horsell Common, at dusk",
		"ground": "heath",
		"light": Color(0.62, 0.5, 0.55),
		"player": {"as": "narrator", "pos": Vector2(1060, 700)},
		"npcs": [
			{"id": "flag", "name": "The man with the white flag", "pos": Vector2(980, 860), "coat": Color(0.85, 0.85, 0.8)},
			{"id": "ogilvy", "pos": Vector2(1020, 900), "coat": Color(0.25, 0.22, 0.2)},
			{"id": "stent", "pos": Vector2(1060, 880), "coat": Color(0.15, 0.15, 0.18)},
			{"id": "henderson", "pos": Vector2(990, 920), "coat": Color(0.3, 0.28, 0.24)},
		],
		"props": props,
		"areas": {"road": Rect2(0, 0, 110, 900)},
		"labels": [["the road to Horsell and safety", Vector2(20, 450)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["martian", Vector2(1380, 430)],
				["narr", "Out on the heather, out of sight. \"I did not dare to go back towards the pit, but I felt a passionate longing to peer into it.\""],
				["move", "flag", Vector2(1250, 560), 40.0],
				["move", "ogilvy", Vector2(1285, 590), 40.0],
				["move", "stent", Vector2(1230, 600), 40.0],
				["move", "henderson", Vector2(1265, 625), 40.0],
				["narr", "\"I noted a little black knot of men, the foremost of whom was waving a white flag. This was the Deputation.\""],
				["wait", 4.0],
				["puffs", Vector2(1350, 440)],
				["narr", "\"Suddenly there was a flash of light, and a quantity of luminous greenish smoke came out of the pit in three distinct puffs\""],
				["burn", "flag"],
				["burn", "ogilvy"],
				["burn", "stent"],
				["burn", "henderson"],
				["narr", "\"It was as if some invisible jet impinged upon them and flashed into white flame.\" Poor Ogilvy. And now it is turning towards you."],
				["checkpoint"],
				["ray", {"from": Vector2(1350, 440), "min": 2.45, "max": 3.85, "start": 3.85, "speed": 0.42, "len": 1500.0}],
			]},
			{"goal": "RUN west to the road. Duck behind the sand hummocks when the ray sweeps near.", "when": {"reach": "road"}, "do": [
				["narr", "\"I ran weeping silently as a child might do.\""],
				["end"],
			]},
		],
	}
