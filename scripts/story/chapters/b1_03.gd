extends RefCounted
## Book One, III. On Horsell Common: the crowd at the pit.


static func data() -> Dictionary:
	var pines := []
	for p in [Vector2(320, 160), Vector2(240, 340), Vector2(420, 260), Vector2(1250, 640), Vector2(1400, 560), Vector2(560, 760), Vector2(1450, 360)]:
		pines.append({"kind": "pine", "pos": p, "r": 26.0})
	return {
		"title": "III. On Horsell Common",
		"place": "The sand-pits on Horsell Common, Friday afternoon",
		"ground": "heath",
		"light": Color(1.0, 0.96, 0.88),
		"player": {"as": "narrator", "pos": Vector2(250, 740)},
		"npcs": [
			{"id": "ogilvy", "pos": Vector2(870, 470), "coat": Color(0.25, 0.22, 0.2)},
			{"id": "stent", "pos": Vector2(940, 400), "coat": Color(0.15, 0.15, 0.18)},
			{"id": "henderson", "pos": Vector2(840, 390), "coat": Color(0.3, 0.28, 0.24)},
			{"id": "boy1", "name": "A boy", "pos": Vector2(770, 560), "coat": Color(0.4, 0.3, 0.2)},
			{"id": "boy2", "name": "A boy", "pos": Vector2(800, 590), "coat": Color(0.3, 0.3, 0.35)},
			{"id": "boy3", "name": "A boy", "pos": Vector2(1010, 570), "coat": Color(0.35, 0.25, 0.2)},
		],
		"crowd": [
			{"rect": Rect2(610, 270, 120, 320), "n": 10, "face": Vector2(900, 430)},
			{"rect": Rect2(1070, 270, 120, 320), "n": 10, "face": Vector2(900, 430)},
		],
		"props": pines + [
			{"kind": "road", "pts": [Vector2(0, 800), Vector2(800, 790), Vector2(1600, 770)]},
			{"kind": "pit", "pos": Vector2(900, 430), "r": 110.0},
			{"kind": "cylinder", "pos": Vector2(900, 430)},
			{"kind": "cart", "pos": Vector2(560, 650)},
			{"kind": "house", "rect": Rect2(1340, 90, 170, 110), "label": "Lord Hilton's house"},
		],
		"areas": {"pitedge": Rect2(620, 260, 560, 400), "hilton": Rect2(1300, 60, 260, 200)},
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "By the afternoon the news is all over Woking, and the curious have come out to stare at the Thing in the pit. \"Extra-terrestrial\" had no meaning for most of the onlookers."],
			]},
			{"goal": "Go and see the Thing in the pit", "when": {"reach": "pitedge"}, "do": [
				["narr", "\"There were four or five boys sitting on the edge of the Pit, with their feet dangling, and amusing themselves—until I stopped them—by throwing stones at the giant mass.\""],
			]},
			{"goal": "Stop the boys throwing stones at the cylinder", "when": {"talk": "boy1"}, "do": [
				["narr", "You speak to them sharply. They run off to play at \"touch\" in and out of the bystanders."],
				["move", "boy1", Vector2(480, 520), 90.0],
				["move", "boy2", Vector2(520, 600), 90.0],
				["move", "boy3", Vector2(1300, 480), 90.0],
			]},
			{"goal": "Talk to Ogilvy, down in the pit", "when": {"talk": "ogilvy"}, "do": [
				["narr", "\"As soon as Ogilvy saw me among the staring crowd on the edge of the pit he called to me to come down, and asked me if I would mind going over to see Lord Hilton, the lord of the manor.\""],
				["narr", "\"They wanted a light railing put up, and help to keep the people back.\""],
			]},
			{"goal": "Take Ogilvy's message to Lord Hilton's house (north-east)", "when": {"reach": "hilton"}, "do": [
				["narr", "Lord Hilton is away in London. You leave Ogilvy's message and go home. By evening the papers are shouting \"A MESSAGE RECEIVED FROM MARS.\""],
				["end"],
			]},
		],
	}
