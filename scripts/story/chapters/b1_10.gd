extends RefCounted
## Book One, X. In the Storm.


static func data() -> Dictionary:
	var props := [
		{"kind": "road", "pts": [Vector2(0, 300), Vector2(260, 600), Vector2(560, 900)]},
		{"kind": "road", "pts": [Vector2(1380, 900), Vector2(1380, 150)]},
		{"kind": "pit", "pos": Vector2(740, 230), "r": 80.0},
		{"kind": "cylinder", "pos": Vector2(740, 230)},
		{"kind": "pool", "pos": Vector2(270, 690), "r": 34.0},
		{"kind": "cart", "pos": Vector2(230, 640)},
		{"kind": "horse", "pos": Vector2(320, 690)},
		{"kind": "furze", "pos": Vector2(215, 570), "r": 38.0},
		{"kind": "furze", "pos": Vector2(345, 575), "r": 34.0},
		{"kind": "house", "rect": Rect2(470, 460, 90, 70), "label": "a squatter's hut"},
		{"kind": "door", "id": "hut", "pos": Vector2(515, 545), "prompt": "hammer at the door", "reach": 70.0},
		{"kind": "ditch", "rect": Rect2(540, 590, 560, 56)},
		{"kind": "fence", "pts": [Vector2(1335, 880), Vector2(1335, 200)]},
		{"kind": "body", "id": "body", "pos": Vector2(1360, 430), "prompt": "look at what lies by the fence", "reach": 60.0},
		{"kind": "house", "rect": Rect2(1440, 50, 150, 110), "label": "Your house"},
	]
	for y in range(280, 840, 70):
		for x in [1110, 1180, 1250]:
			props.append({"kind": "pine", "pos": Vector2(x + (y % 140) * 0.2, y), "r": 24.0})
	return {
		"title": "X. In the Storm",
		"place": "Between Pyrford and Maybury Hill, near midnight, in a thunderstorm",
		"ground": "heath",
		"light": Color(0.2, 0.2, 0.32),
		"lantern": true,
		"rain": true,
		"player": {"as": "narrator", "pos": Vector2(225, 575)},
		"npcs": [{"id": "stranger", "name": "A man", "pos": Vector2(1380, 560), "visible": false, "coat": Color(0.2, 0.2, 0.22)}],
		"machines": [
			{"pos": Vector2(780, 250), "path": [Vector2(780, 250), Vector2(690, 300), Vector2(820, 330)], "speed": 18.0, "view": 360.0},
			{"pos": Vector2(40, 160), "path": [], "speed": 0.0, "view": 380.0},
		],
		"props": props,
		"areas": {"cover_hut": Rect2(455, 450, 120, 120), "woods": Rect2(1090, 300, 200, 500), "cover_woods": Rect2(1080, 250, 230, 590), "lane": Rect2(1330, 600, 100, 280), "home": Rect2(1420, 160, 180, 90)},
		"labels": [["to Pyrford", Vector2(20, 290)], ["the pine woods towards Maybury", Vector2(1080, 240)], ["the lane from the College Arms", Vector2(1395, 860)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["narr", "\"We got to Leatherhead without misadventure about nine o'clock\" and you leave your wife with your cousins. \"Her face, I remember, was very white as we parted.\""],
				["narr", "\"It was nearly eleven when I started to return.\" You drive the landlord's dog cart back towards Maybury, as you promised him."],
				["storm_on"],
				["narr", "\"I saw that the driving clouds had been pierced as it were by a thread of green fire, suddenly lighting their confusion and falling into the field to my left. It was the third falling star!\""],
				["plate", "plate_0067.jpg", "\"A monstrous tripod, higher than many houses, striding over the young pine trees, and smashing them aside in its career; a walking engine of glittering metal, striding now across the heather\""],
				["narr", "\"At the sight of the second monster my nerve went altogether.\" The horse bolts, the dog cart heels over, and you are flung into a pool of water."],
				["sfx", "horse", -4.0],
				["machine", 1, Vector2(590, 330), 110.0],
				["narr", "\"Behind the main body was a huge mass of white metal like a gigantic fisherman's basket, and puffs of green smoke squirted out from the joints of the limbs as the monster swept by me.\""],
				["checkpoint"],
			]},
			{"goal": "Make a run for the squatter's hut. Move between the lightning flashes: when it flashes, be in cover.", "when": {"use": "hut"}, "do": [
				["narr", "\"I hammered at the door, but I could not make the people hear\""],
				["checkpoint"],
			]},
			{"goal": "Crawl along the ditch into the pine woods towards Maybury (east)", "when": {"reach": "woods"}, "do": [
				["narr", "\"It was very dark indeed in the wood\""],
				["checkpoint"],
			]},
			{"goal": "Come out into the lane from the College Arms, and climb the hill home", "when": {"reach": "lane"}, "do": [
				["show", "stranger", true],
				["move", "stranger", Vector2(1380, 960), 220.0],
				["narr", "\"There in the darkness a man blundered into me and sent me reeling back.\""],
			]},
			{"goal": "Something lies by the fence", "when": {"use": "body"}, "do": [
				["narr", "You \"saw between my feet a heap of black broadcloth and a pair of boots.\" The lightning flashes again."],
				["narr", "\"It was the landlord of the Spotted Dog, whose conveyance I had taken.\""],
				["checkpoint"],
			]},
			{"goal": "Get home", "when": {"reach": "home"}, "do": [
				["narr", "\"I let myself in with my latchkey, closed, locked and bolted the door, staggered to the foot of the staircase, and sat down.\""],
				["end"],
			]},
		],
	}
