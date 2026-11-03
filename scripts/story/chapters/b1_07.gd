extends RefCounted
## Book One, VII. How I Reached Home.


static func data() -> Dictionary:
	var props := [
		{"kind": "road", "pts": [Vector2(1600, 480), Vector2(1100, 470), Vector2(800, 460), Vector2(400, 450), Vector2(250, 470)]},
		{"kind": "bridge", "rect": Rect2(1020, 420, 120, 100)},
		{"kind": "house", "rect": Rect2(130, 300, 190, 140), "label": "Your house", "lit": true},
	]
	for x in [480, 600, 720, 840]:
		props.append({"kind": "house", "rect": Rect2(x, 300, 100, 90), "lit": x == 600})
	props.append({"kind": "fence", "pts": [Vector2(470, 400), Vector2(950, 400)]})
	return {
		"title": "VII. How I Reached Home",
		"place": "Maybury, Friday night",
		"ground": "town",
		"light": Color(0.42, 0.44, 0.6),
		"lantern": true,
		"lanterns": [Vector2(600, 420), Vector2(900, 470), Vector2(240, 460)],
		"player": {"as": "narrator", "pos": Vector2(1520, 480)},
		"npcs": [
			{"id": "man1", "name": "A man", "pos": Vector2(585, 425), "coat": Color(0.3, 0.28, 0.24)},
			{"id": "man2", "name": "Another man", "pos": Vector2(735, 425), "coat": Color(0.25, 0.25, 0.3)},
			{"id": "woman", "name": "A woman", "pos": Vector2(660, 380), "coat": Color(0.45, 0.25, 0.3)},
			{"id": "wife", "pos": Vector2(230, 470), "coat": Color(0.55, 0.22, 0.42)},
		],
		"props": props,
		"labels": [["Oriental Terrace", Vector2(560, 285)], ["Maybury arch", Vector2(1040, 400)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "You run until you can run no more, then walk on over the bridge into Maybury. Lamps are lit. Trains run. \"It was all so real and so familiar.\""],
			]},
			{"goal": "Ask the people at the gate for news", "when": {"talk": "man1"}, "do": [
				["say", "narrator", "What news from the common?"],
				["say", "man1", "Eh?"],
				["say", "narrator", "What news from the common?"],
				["say", "man2", "Ain't yer just been there?"],
				["say", "woman", ["People seem fair silly about the common,", "What's it all abart?"]],
				["say", "narrator", ["Haven't you heard of the men from Mars?", "the creatures from Mars?"]],
				["say", "woman", ["Quite enough,", "Thenks;"]],
				["narr", "\"and all three of them laughed.\""],
				["say", "narrator", "You'll hear more yet,"],
			]},
			{"goal": "Go home to your wife", "when": {"talk": "wife"}, "do": [
				["narr", "\"I startled my wife at the doorway, so haggard was I.\""],
				["say", "narrator", ["There is one thing,", "they are the most sluggish things I ever saw crawl. They may keep the pit and kill people who come near them, but they cannot get out of it. . . . But the horror of them!"]],
				["say", "wife", "Don't, dear!"],
				["say", "narrator", ["Poor Ogilvy!", "To think he may be lying dead there!"]],
				["say", "wife", "They may come here,"],
				["say", "narrator", "They can scarcely move,"],
				["say", "narrator", ["They have done a foolish thing,", "They are dangerous because, no doubt, they are mad with terror. Perhaps they expected to find no living things—certainly no intelligent living things."]],
				["say", "narrator", ["A shell in the pit,", "if the worst comes to the worst, will kill them all."]],
				["narr", "\"I remember that dinner table with extraordinary vividness even now.\""],
				["end"],
			]},
		],
	}
