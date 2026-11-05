extends RefCounted
## Book One, XIII. How I Fell In with the Curate.
## The narrator has escaped burning Weybridge in a drifting boat. Sick with
## the heat, he lands on the Middlesex bank near Walton, crawls into the
## shade of a hedge, and wakes to find the curate beside him. The dialogue
## is Wells' own, word for word.


static func data() -> Dictionary:
	var props := [
		{"kind": "river", "pts": [Vector2(-60, 700), Vector2(400, 722), Vector2(900, 685), Vector2(1300, 710), Vector2(1660, 690)], "w": 130.0},
		# Halliford, across the water, deserted and burning
		{"kind": "house", "rect": Rect2(470, 800, 100, 64)},
		{"kind": "house", "rect": Rect2(660, 790, 90, 70)},
		{"kind": "house", "rect": Rect2(860, 805, 110, 60)},
		{"kind": "house", "rect": Rect2(1060, 795, 90, 66)},
		{"kind": "boat", "pos": Vector2(250, 628), "dir": Vector2(0.95, -0.3)},
		{"kind": "hedge", "pts": [Vector2(-20, 360), Vector2(420, 330), Vector2(820, 350), Vector2(1240, 320)]},
		{"kind": "road", "pts": [Vector2(1250, 615), Vector2(1330, 450), Vector2(1400, 220), Vector2(1440, -20)]},
		{"kind": "furze", "pos": Vector2(500, 520), "r": 34.0},
		{"kind": "furze", "pos": Vector2(1050, 540), "r": 30.0},
		{"kind": "pine", "pos": Vector2(1500, 520), "r": 30.0},
		{"kind": "pine", "pos": Vector2(1540, 380), "r": 26.0},
	]
	return {
		"title": "XIII. How I Fell In with the Curate",
		"place": "The Middlesex bank of the Thames, near Walton, late on Sunday afternoon",
		"ground": "heath",
		"light": Color(1.0, 0.8, 0.62),
		# parboiled and deadly sick: the narrator can barely walk at first
		"player_speed": 0.55,
		"player": {"as": "narrator", "pos": Vector2(300, 585), "coat": Color(0.5, 0.42, 0.36)},
		"npcs": [
			{"id": "curate", "pos": Vector2(760, 410), "coat": Color(0.12, 0.11, 0.12), "collar": true, "visible": false},
		],
		"heliograph": Vector2(1480, 70),
		"props": props,
		"areas": {"shade": Rect2(560, 360, 320, 90), "north": Rect2(1340, 0, 200, 110)},
		"labels": [["the Thames", Vector2(40, 745)], ["Halliford, burning", Vector2(760, 885)],
			["towards Walton bridge", Vector2(1420, 770)], ["northward, towards Sunbury", Vector2(1180, 30)],
			["the hedge", Vector2(860, 300)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["fire", Vector2(520, 830), 14.0],
				["fire", Vector2(705, 822), 11.0],
				["fire", Vector2(915, 835), 15.0],
				["fire", Vector2(1105, 826), 10.0],
				["fire", Vector2(1180, 620), 6.0],
				["fire", Vector2(1225, 612), 5.0],
				["narr", "Weybridge is burning behind you. \"I saw an abandoned boat, very small and remote, drifting down-stream\". You swam to it, and drifted down the river away from the destruction."],
				["narr", "Across the water, Halliford is on fire. \"It was strange to see the place quite tranquil, quite desolate under the hot blue sky, with the smoke and little threads of flame going straight up into the heat of the afternoon.\""],
				["narr", "At last \"my fever and faintness overcame my fears, and I landed on the Middlesex bank and lay down, deadly sick, amid the long grass.\""],
				["checkpoint"],
			]},
			{"goal": "Get out of the sun: crawl to the shade of the hedge to the north", "when": {"reach": "shade"}, "do": [
				["speed", 1.0],
				["narr", "\"I got up presently, walked perhaps half a mile without meeting a soul, and then lay down again in the shadow of a hedge.\""],
				["narr", "\"I was also very thirsty, and bitterly regretful I had drunk no more water. It is a curious thing that I felt angry with my wife\""],
				["wait", 1.5],
				["show", "curate", true],
				["narr", "\"I do not clearly remember the arrival of the curate, so that probably I dozed. I became aware of him as a seated figure in soot-smudged shirt sleeves, and with his upturned, clean-shaven face staring at a faint flickering that danced over the sky.\""],
				["checkpoint"],
			]},
			{"goal": "Speak to the stranger", "when": {"talk": "curate"}, "do": [
				["say", "narrator", "Have you any water?"],
				["narr", "\"He shook his head.\""],
				["say", "curate", "You have been asking for water for the last hour,"],
				["narr", "\"His face was a fair weakness, his chin retreated, and his hair lay in crisp, almost flaxen curls on his low forehead\""],
				["say", "curate", ["What does it mean?", "What do these things mean?"]],
				["say", "curate", ["Why are these things permitted? What sins have we done?", "As if it were Sodom and Gomorrah!"]],
				["say", "narrator", "What are we?"],
				["say", "curate", ["All the work—all the Sunday schools—What have we done—what has Weybridge done?", "The church! We rebuilt it only three years ago. Gone!"]],
				["say", "curate", "The smoke of her burning goeth up for ever and ever!"],
				["narr", "He points a lean finger towards Weybridge. \"it was evident he was a fugitive from Weybridge\""],
			]},
			{"goal": "Ask him where you are", "when": {"talk": "curate"}, "do": [
				["say", "narrator", "Are we far from Sunbury?"],
				["say", "curate", ["What are we to do?", "Are these creatures everywhere? Has the earth been given over to them?"]],
				["say", "narrator", "Are we far from Sunbury?"],
				["say", "curate", "Only this morning I officiated at early celebration"],
				["say", "narrator", ["Things have changed,", "You must keep your head. There is still hope."]],
				["say", "curate", "Hope!"],
				["say", "narrator", "Yes. Plentiful hope—for all this destruction!"],
				["say", "curate", ["This must be the beginning of the end,", "The end! The great and terrible day of the Lord!"]],
			]},
			{"goal": "Steady him: put your hand on his shoulder", "when": {"talk": "curate"}, "do": [
				["say", "narrator", ["Be a man!", "You are scared out of your wits! What good is religion if it collapses under calamity?", "He is not an insurance agent."]],
				["narr", "\"For a time he sat in blank silence.\""],
				["say", "curate", ["But how can we escape?", "They are invulnerable, they are pitiless."]],
				["say", "narrator", ["Neither the one nor, perhaps, the other,", "One of them was killed yonder not three hours ago."]],
				["say", "curate", ["Killed!", "How can God’s ministers be killed?"]],
				["say", "curate", "What is that flicker in the sky?"],
			]},
			{"goal": "The flicker on the hills to the north-east: tell him what it is", "when": {"talk": "curate"}, "do": [
				["narr", "\"I told him it was the heliograph signalling—that it was the sign of human help and effort in the sky.\""],
				["say", "narrator", ["We are in the midst of it,", "quiet as it is. That flicker in the sky tells of the gathering storm."]],
				["move", "curate", Vector2(780, 440), 60.0],
				["say", "curate", "Listen!"],
				["loop", "distant_guns", true, -10.0],
				["sfx", "ulla", -20.0],
				["narr", "\"From beyond the low hills across the water came the dull resonance of distant guns and a remote weird crying. Then everything was still.\""],
				["narr", "\"A cockchafer came droning over the hedge and past us.\""],
				["say", "narrator", ["We had better follow this path,", "northward."]],
				["move", "curate", Vector2(1300, 470), 70.0],
				["checkpoint"],
			]},
			{"goal": "Follow the path northward, around the end of the hedge", "when": {"reach": "north"}, "do": [
				["move", "curate", Vector2(1420, 60), 90.0],
				["narr", "So you go on together towards London: the narrator, and a curate at the very verge of his reason. You will be together a long time."],
				["end"],
			]},
		],
	}
