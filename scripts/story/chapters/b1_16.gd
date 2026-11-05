extends RefCounted
## Book One, XVI. The Exodus from London (second scene of XIV-XVI). The
## brother rescues Mrs and Miss Elphinstone from three robbers in a grass
## lane towards High Barnet, then leads their pony-chaise to the Great North
## Road: "a boiling stream of people, a torrent of human beings rushing
## northward". The first attempt to cross fails, as in the novel; the second
## must dodge the wheels while the crowd sweeps you north.


static func data() -> Dictionary:
	var props := [
		{"kind": "road", "pts": [Vector2(-40, 860), Vector2(260, 720), Vector2(380, 540), Vector2(560, 440), Vector2(700, 410), Vector2(800, 405)]},
		{"kind": "road", "pts": [Vector2(1140, 190), Vector2(1350, 170), Vector2(1640, 150)]},
		# villas guarding the lane's mouth, and along the far side of the road
		{"kind": "house", "rect": Rect2(620, 40, 140, 280), "lit": false},
		{"kind": "house", "rect": Rect2(620, 500, 140, 330), "lit": false},
		{"kind": "house", "rect": Rect2(1180, 400, 150, 120), "lit": false},
		{"kind": "house", "rect": Rect2(1180, 580, 150, 260), "lit": false},
		{"kind": "hedge", "pts": [Vector2(120, 600), Vector2(250, 470), Vector2(400, 360), Vector2(560, 330)]},
		{"kind": "hedge", "pts": [Vector2(320, 820), Vector2(470, 640), Vector2(600, 560)]},
		{"kind": "pine", "pos": Vector2(90, 380), "r": 30.0},
		{"kind": "pine", "pos": Vector2(170, 260), "r": 28.0},
		{"kind": "pine", "pos": Vector2(1450, 420), "r": 30.0},
		{"kind": "pine", "pos": Vector2(1500, 700), "r": 34.0},
	]
	return {
		"title": "XV-XVI. The Exodus from London",
		"place": "A grass lane towards High Barnet, and the Great North Road, Monday morning",
		"ground": "heath",
		"light": Color(1.0, 0.94, 0.8),
		"player": {"as": "brother", "pos": Vector2(140, 790), "coat": Color(0.3, 0.3, 0.34)},
		"chaise": {"pos": Vector2(470, 480), "dir": Vector2(0.4, -0.9).normalized()},
		"npcs": [
			{"id": "mrs_elphinstone", "pos": Vector2(470, 480), "coat": Color(0.92, 0.9, 0.86), "ride": 0},
			{"id": "miss_elphinstone", "pos": Vector2(430, 455), "coat": Color(0.15, 0.12, 0.14)},
			{"id": "rough1", "name": "A rough", "pos": Vector2(410, 470), "coat": Color(0.3, 0.26, 0.2)},
			{"id": "rough2", "name": "A rough", "pos": Vector2(445, 430), "coat": Color(0.25, 0.22, 0.18)},
			{"id": "rough3", "name": "A burly rough", "pos": Vector2(515, 400), "coat": Color(0.35, 0.25, 0.18)},
			{"id": "girl", "name": "A little girl", "pos": Vector2(600, 470), "coat": Color(0.7, 0.55, 0.6), "visible": false},
		],
		"voices": {"crowd": "Voices on the road", "mother": "A woman in the crowd", "rider": "A man on horseback"},
		"traffic": [
			{"rect": Rect2(780, 0, 390, 900), "dir": Vector2.UP, "vehicles": 7, "walkers": 46, "band": Vector2(85, 305), "speed": [55.0, 115.0], "push": 55.0, "dust": true,
				"why": "You were borne down under the hoofs and wheels, like the man with the gold."},
		],
		"props": props,
		"areas": {"rescue": Rect2(300, 480, 240, 160), "corner": Rect2(650, 360, 110, 110), "bend": Rect2(330, 480, 200, 180),
			"east": Rect2(1200, 0, 400, 390)},
		"labels": [["THE GREAT NORTH ROAD", Vector2(890, 880)], ["towards Barnet, north", Vector2(900, 30)],
			["the lane eastward, to Hadley", Vector2(1360, 130)], ["the grass lane", Vector2(30, 900)]],
		"steps": [
			{"when": {"auto": true}, "do": [
				["fire", Vector2(1250, 640), 12.0],
				["fire", Vector2(1210, 720), 9.0],
				["narr", "Monday morning, nearly nine. You have struck east from Edgware along quiet lanes. \"He saw few fugitives until, in a grass lane towards High Barnet, he happened upon two ladies who became his fellow travellers. He came upon them just in time to save them.\""],
				["sfx", "scream", -2.0],
			]},
			{"goal": "Screams up the lane! Hurry towards them", "when": {"reach": "rescue"}, "do": [
				["narr", "You see \"a couple of men struggling to drag them out of the little pony-chaise in which they had been driving, while a third with difficulty held the frightened pony’s head.\""],
				["narr", "\"One of the ladies, a short woman dressed in white, was simply screaming; the other, a dark, slender figure, slashed at the man who gripped her arm with a whip she held in her disengaged hand.\""],
				["checkpoint"],
			]},
			{"goal": "Go for the man nearest you", "when": {"talk": "rough1"}, "do": [
				["narr", "\"being an expert boxer, went into him forthwith and sent him down against the wheel of the chaise.\""],
				["down", "rough1", true],
				["sfx", "step_floor_1", 0.0],
				["narr", "Then \"the whip stung across his face, a third antagonist struck him between the eyes\". The burly rough who held the pony comes at you."],
				["move", "rough3", Vector2(400, 520), 70.0],
				["move", "rough2", Vector2(260, 600), 60.0],
			]},
			{"goal": "Stand your ground against the burly rough", "when": {"talk": "rough3"}, "do": [
				["narr", "\"The man before him, a burly rough, tried to close, and he stopped him with a blow in the face.\" But there are two of them now, and you are partly stunned."],
				["sfx", "rifle", 0.0],
				["narr", "The slender lady has found a revolver under the seat. \"She fired at six yards’ distance, narrowly missing my brother. The less courageous of the robbers made off, and his companion followed him, cursing his cowardice.\""],
				["move", "rough3", Vector2(-60, 700), 110.0],
				["move", "rough2", Vector2(-60, 760), 120.0],
				["down", "rough1", false],
				["move", "rough1", Vector2(-60, 820), 60.0],
				["say", "miss_elphinstone", "Take this!"],
				["say", "brother", "Go back to the chaise,"],
				["ride", "miss_elphinstone", 1],
				["checkpoint"],
			]},
			{"goal": "Go to the chaise", "when": {"talk": "miss_elphinstone"}, "do": [
				["say", "brother", ["I’ll sit here,", "if I may"]],
				["say", "miss_elphinstone", "Give me the reins,"],
				["narr", "They are the wife and the younger sister of a surgeon at Stanmore, who promised to overtake them hours ago. \"They made a sort of encampment by the wayside, and the pony became happy in the hedge.\""],
				["say", "miss_elphinstone", "We have money,"],
				["say", "brother", "So have I,"],
				["narr", "\"Mrs. Elphinstone—that was the name of the woman in white—would listen to no reasoning, and kept calling upon “George”\". Her sister-in-law agrees to your plan: cross the Great North Road, and make for Harwich and the sea."],
				["narr", "\"So, designing to cross the Great North Road, they went on towards Barnet, my brother leading the pony to save it as much as possible.\""],
				["follow", true],
				["loop", "panic_loop", true, -14.0],
				["checkpoint"],
			]},
			{"goal": "Lead the pony east along the lane, towards the noise", "when": {"reach": "corner"}, "do": [
				["loop", "panic_loop", true, -2.0],
				["say", "mrs_elphinstone", ["Good heavens!", "What is this you are driving us into?"]],
				["narr", "\"For the main road was a boiling stream of people, a torrent of human beings rushing northward, one pressing on another.\""],
				["say", "crowd", ["Way!", "Make way!"]],
				["show", "girl", true],
				["narr", "\"a little girl of eight or nine, all alone, threw herself under the hedge close by my brother, weeping.\""],
			]},
			{"goal": "Help the little girl", "when": {"talk": "girl"}, "do": [
				["say", "girl", ["I can’t go on!", "I can’t go on!"]],
				["narr", "\"My brother woke from his torpor of astonishment and lifted her up, speaking gently to her, and carried her to Miss Elphinstone.\""],
				["say", "mother", ["Ellen!", "Ellen!"]],
				["say", "girl", "Mother!"],
				["move", "girl", Vector2(880, 300), 120.0],
				["say", "rider", "They are coming,"],
				["narr", "Then, in the road, \"a bearded, eagle-faced man lugging a small handbag, which split even as my brother’s eyes rested on it and disgorged a mass of sovereigns\". He throws himself on the coins. \"A horse rose close upon him, and in another moment, half rising, he had been borne down under the horse’s hoofs.\""],
				["say", "brother", "Stop!"],
				["narr", "Too late. \"He saw Miss Elphinstone covering her eyes\"."],
				["show", "girl", false],
				["say", "brother", ["Let us go back!", "We cannot cross this—hell,"]],
			]},
			{"goal": "Lead them back down the lane, away from the crowd", "when": {"reach": "bend"}, "do": [
				["narr", "\"So soon as they had retreated he realised how urgent and unavoidable it was to attempt this crossing.\""],
				["say", "brother", "We must go that way,"],
				["say", "brother", ["Point the revolver at the man behind,", "if he presses us too hard. No!—point it at his horse."]],
				["narr", "Wait at the edge of the road for a gap between the carts, then go. Once you are among the wheels, the stream will carry you north."],
				["checkpoint"],
			]},
			{"goal": "Cross the Great North Road to the lane north-east. Keep clear of the wheels!", "when": {"reach": "east"}, "do": [
				["follow", false],
				["narr", "\"They swept through Chipping Barnet with the torrent; they were nearly a mile beyond the centre of the town before they had fought across to the opposite side of the way.\""],
				["narr", "\"They struck eastward through Hadley\". \"Near this place they halted for the rest of the afternoon, for the violence of the day had already utterly exhausted all three of them.\""],
				["end"],
			]},
		],
	}
