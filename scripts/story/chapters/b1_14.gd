extends RefCounted
## Book One, XIV. In London. Played as the narrator's brother, a medical
## student lodging near Regent's Park. Before dawn on Monday the panic wakes
## him: a policeman hammering on doors, the Commander-in-Chief's dispatch,
## and cabs galloping for Chalk Farm station. Leads straight on into
## XV-XVI. The Exodus from London (b1_16).


static func data() -> Dictionary:
	var props := [
		# the lodging house: his attic, the stairs down, the front door
		{"kind": "floor", "rect": Rect2(80, 90, 460, 260)},
		{"kind": "table", "id": "drawer", "pos": Vector2(170, 170), "prompt": "take your money from the drawer", "reach": 70.0},
		{"kind": "window", "id": "window", "pos": Vector2(330, 340), "prompt": "look out of the window", "reach": 70.0},
		{"kind": "stairs", "rect": Rect2(480, 130, 50, 170)},
		{"kind": "street", "rect": Rect2(0, 440, 1600, 170)},
		{"kind": "road", "pts": [Vector2(1520, 520), Vector2(1530, 200), Vector2(1560, -40)]},
		# "a cart carelessly driven smashed ... against the water trough up the street"
		{"kind": "cart", "pos": Vector2(815, 395)},
		{"kind": "crate", "pos": Vector2(785, 345)},
		{"kind": "crate", "pos": Vector2(850, 352)},
		{"kind": "pool", "pos": Vector2(820, 418), "r": 16.0},
		{"kind": "lantern", "pos": Vector2(640, 380)},
		{"kind": "lantern", "pos": Vector2(1100, 380)},
		# the houses across the road, window after window lighting up
		{"kind": "house", "rect": Rect2(60, 680, 220, 160), "lit": true},
		{"kind": "house", "rect": Rect2(330, 680, 240, 160), "lit": true},
		{"kind": "house", "rect": Rect2(620, 690, 200, 150), "lit": true},
		{"kind": "house", "rect": Rect2(870, 680, 260, 160), "lit": true},
		{"kind": "house", "rect": Rect2(1180, 690, 240, 150), "lit": true},
		{"kind": "house", "rect": Rect2(620, 90, 240, 230), "lit": true},
		{"kind": "house", "rect": Rect2(900, 90, 240, 230), "lit": true},
		{"kind": "house", "rect": Rect2(1180, 90, 240, 230), "lit": true},
	]
	var walls := [
		Rect2(70, 80, 480, 10), Rect2(70, 80, 10, 280), Rect2(540, 80, 10, 280),
		Rect2(70, 350, 420, 10),                     # the street front (the door is at the right)
		Rect2(760, 315, 120, 125),                   # the smashed cart and water trough block the pavement
	]
	return {
		"title": "XIV. In London",
		"place": "A street of lodging houses near Regent's Park, before dawn on Monday",
		"ground": "town",
		"light": Color(0.5, 0.48, 0.66),
		"lantern": true,
		"lanterns": [Vector2(640, 380), Vector2(1100, 380), Vector2(1530, 300)],
		"player": {"as": "brother", "pos": Vector2(250, 230), "coat": Color(0.75, 0.72, 0.66)},
		"npcs": [
			{"id": "lodger", "name": "Your fellow lodger", "pos": Vector2(480, 120), "coat": Color(0.8, 0.78, 0.72), "visible": false},
			{"id": "policeman", "name": "A policeman", "pos": Vector2(120, 400), "coat": Color(0.08, 0.1, 0.2), "visible": false},
			{"id": "newsvendor", "name": "A newsvendor", "pos": Vector2(1300, 410), "coat": Color(0.4, 0.3, 0.2), "visible": false},
		],
		"voices": {"crowd": "Voices in the street"},
		"traffic": [
			{"rect": Rect2(0, 440, 1600, 170), "dir": Vector2.RIGHT, "vehicles": 7, "walkers": 26, "speed": [130.0, 230.0], "push": 30.0,
				"why": "A cab came galloping out of the dark and ran you down."},
		],
		"walls": walls,
		"hide_walls": [4],   # the cart and trough are drawn as props
		"props": props,
		"areas": {"street_door": Rect2(470, 360, 120, 70), "chalk_farm": Rect2(1450, 0, 150, 160)},
		"labels": [["your attic", Vector2(90, 110)], ["to Chalk Farm station", Vector2(1380, 40)],
			["the smashed cart and the water trough", Vector2(700, 345)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "You are the narrator's brother. \"My younger brother was in London when the Martians fell at Woking. He was a medical student working for an imminent examination\". All Sunday the news has been vague; London has gone to bed calm."],
				["sfx", "church_bell", -6.0],
				["narr", "\"He went to bed a little after midnight, and was awakened from lurid dreams in the small hours of Monday by the sound of door knockers, feet running in the street, distant drumming, and a clamour of bells. Red reflections danced on the ceiling.\""],
			]},
			{"goal": "Run to the window", "when": {"use": "window"}, "do": [
				["show", "policeman", true],
				["move", "policeman", Vector2(330, 400), 120.0],
				["wait", 1.0],
				["say", "policeman", ["They are coming!", "the Martians are coming!"]],
				["move", "policeman", Vector2(1700, 400), 110.0],
				["narr", "\"Up the street came galloping a closed carriage, bursting abruptly into noise at the corner, rising to a clattering climax under the window, and dying away slowly in the distance.\""],
				["show", "lodger", true],
				["move", "lodger", Vector2(400, 200), 80.0],
			]},
			{"goal": "Your fellow lodger has come in. Talk to him", "when": {"talk": "lodger"}, "do": [
				["say", "lodger", ["What the devil is it?", "A fire? What a devil of a row!"]],
				["say", "lodger", "What the devil is it all about?"],
				["narr", "\"My brother answered him vaguely and began to dress, running with each garment to the window in order to miss nothing of the growing excitement.\""],
			]},
			{"goal": "Go down and out into the street (the front door is at the right of the house)", "when": {"reach": "street_door"}, "do": [
				["show", "newsvendor", true],
				["move", "newsvendor", Vector2(700, 410), 90.0],
				["say", "crowd", "Black Smoke!"],
				["narr", "\"The contagion of such a unanimous fear was inevitable.\" A newsvendor comes running along the pavement, selling as he runs."],
			]},
			{"goal": "Buy a paper from the running newsvendor", "when": {"talk": "newsvendor"}, "do": [
				["say", "newsvendor", "London in danger of suffocation! The Kingston and Richmond defences forced! Fearful massacres in the Thames Valley!"],
				["narr", "From the paper you read \"that catastrophic dispatch of the Commander-in-Chief\": \"The Martians are able to discharge enormous clouds of a black and poisonous vapour by means of rockets. They have smothered our batteries, destroyed Richmond, Kingston, and Wimbledon, and are advancing slowly towards London, destroying everything on the way. It is impossible to stop them. There is no safety from the Black Smoke but in instant flight.\""],
				["narr", "\"That was all, but it was enough.\""],
				["move", "newsvendor", Vector2(-80, 410), 140.0],
				["loop", "panic_loop", true, -4.0],
			]},
			{"goal": "Go back up to your room for your money", "when": {"use": "drawer"}, "do": [
				["narr", "You \"put all his available money—some ten pounds altogether—into his pockets, and went out again into the streets.\""],
				["checkpoint"],
			]},
			{"goal": "Get to Chalk Farm station (north-east). Mind the cabs round the smashed cart", "when": {"reach": "chalk_farm"}, "do": [
				["narr", "At Chalk Farm there is \"a fruitless struggle to get aboard a North-Western train\": \"the engines of the trains that had loaded in the goods yard there _ploughed_ through shrieking people\"."],
				["narr", "So you take to the road instead, and have \"the luck to be foremost in the sack of a cycle shop.\" \"So he got out of the fury of the panic, and, skirting the Edgware Road, reached Edgware about seven, fasting and wearied, but well ahead of the crowd.\""],
				["end"],
			]},
		],
		"next": "b1_16",
	}
