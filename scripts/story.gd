class_name Story
extends RefCounted
## The campaign follows the novel chapter by chapter, illustrated with
## Henrique Alvim Corrêa's plates for the 1906 Belgian edition (public domain;
## scans from Duke University Libraries via The Public Domain Review).
##
## Each chapter is a run of storybook pages ([plate file, narration]; a file of
## "" shows a title page instead) and, if it is built, something to play:
##   "story": id   - a walk-and-talk story scene (scripts/story/chapters/<id>.gd)
##   "scene": path - one of the action modes
## and "music": the Musopen recording that plays under it (audio/music/<id>.ogg).
## Text in "quotes" is H. G. Wells' own, checked word for word against
## the-war-of-the-worlds.txt by tools/check_quotes.py; the rest is ours.

const BOOK_ONE := "BOOK ONE  -  THE COMING OF THE MARTIANS"
const BOOK_TWO := "BOOK TWO  -  THE EARTH UNDER THE MARTIANS"

const CHAPTERS := [
	# ------------------------------------------------------------ BOOK ONE
	{
		"title": "I. The Eve of the War",
		"music": "scottish_andante",
		"book": BOOK_ONE,
		"cast": ["narrator", "ogilvy"],
		"story": "b1_01",
		"mode": "Story: the observatory at Ottershaw",
		"plates": [
			["plate_0011.jpg", "\"No one would have believed in the last years of the nineteenth century that this world was being watched keenly and closely by intelligences greater than man's and yet as mortal as his own.\""],
			["plate_0019.jpg", "Astronomers have seen great outbreaks of gas on Mars. Ogilvy, the astronomer, invites you up to his observatory at Ottershaw to watch."],
		],
	},
	{
		"title": "II. The Falling Star",
		"music": "steppes",
		"book": BOOK_ONE,
		"cast": ["ogilvy", "henderson"],
		"story": "b1_02",
		"mode": "Story: play as Ogilvy",
		"plates": [
			["plate_0027.jpg", "\"Then came the night of the first falling star.\" At dawn, Ogilvy goes out alone onto Horsell Common to find it."],
		],
	},
	{
		"title": "III. On Horsell Common",
		"music": "american_lento",
		"book": BOOK_ONE,
		"cast": ["narrator", "ogilvy", "stent", "henderson"],
		"story": "b1_03",
		"mode": "Story: the crowd at the pit",
		"plates": [
			["plate_0035.jpg", "In the sand-pit lies a great cylinder, hot and smoking. By midday half of Woking has come to stare at it."],
		],
	},
	{
		"title": "IV. The Cylinder Opens",
		"music": "pathetique_adagio",
		"book": BOOK_ONE,
		"cast": ["narrator", "stent", "martian"],
		"story": "b1_04",
		"mode": "Story: the evening at the pit",
		"plates": [
			["", "At sunset the crowd is larger still. The top of the cylinder has almost unscrewed."],
		],
	},
	{
		"title": "V. The Heat-Ray",
		"music": "coriolan",
		"book": BOOK_ONE,
		"cast": ["narrator", "ogilvy", "stent", "henderson"],
		"story": "b1_05",
		"mode": "Story: the Deputation, and the flight",
		"plates": [
			["plate_0043.jpg", "\"Those who have never seen a living Martian can scarcely imagine the strange horror of its appearance.\""],
		],
	},
	{
		"title": "VI. The Heat-Ray in the Chobham Road",
		"music": "coriolan",
		"book": BOOK_ONE,
		"cast": [],
		"plates": [
			["plate_0051.jpg", "On the Chobham road the crowd breaks and runs. Men step into an invisible flame and are gone."],
			["plate_0059.jpg", "By nightfall the common was silent, and \"the charred bodies lay about on it all night under the stars.\""],
		],
	},
	{
		"title": "VII. How I Reached Home",
		"music": "mozart_40",
		"book": BOOK_ONE,
		"cast": ["narrator", "wife"],
		"story": "b1_07",
		"mode": "Story: the walk home to Maybury",
		"plates": [
			["", "You run until you can run no more, and walk home through the ordinary evening of Woking, where no one believes you."],
		],
	},
	{
		"title": "VIII. Friday Night",
		"music": "mozart_40",
		"book": BOOK_ONE,
		"cast": [],
		"plates": [
			["", "Friday night. Troops are moving onto the common. In the pit, the Martians are hammering. A second falling star comes down near Pyrford."],
		],
	},
	{
		"title": "IX. The Fighting Begins",
		"music": "egmont",
		"book": BOOK_ONE,
		"cast": ["narrator", "wife", "landlord", "artilleryman"],
		"scene": "res://scenes/main.tscn",
		"mode": "Strategy: the dog cart road to Leatherhead",
		"plates": [
			["", "Saturday. The guns open fire and a machine rises from the pit. You borrow the landlord's dog cart to drive your wife to safety at Leatherhead."],
		],
	},
	{
		"title": "X. In the Storm",
		"music": "brahms_1",
		"book": BOOK_ONE,
		"cast": ["narrator", "landlord"],
		"story": "b1_10",
		"mode": "Story: through the storm, past the machines",
		"plates": [
			["plate_0067.jpg", "\"A monstrous tripod, higher than many houses, striding over the young pine trees, and smashing them aside in its career.\""],
			["plate_0075.jpg", "Driving the landlord's dog cart back alone through the thunderstorm, you meet the machines."],
		],
	},
	{
		"title": "XI. At the Window",
		"music": "marcia_funebre",
		"book": BOOK_ONE,
		"cast": ["narrator", "artilleryman"],
		"story": "b1_11",
		"mode": "Story: the artilleryman's story",
		"plates": [
			["", "From your study window you watch Woking burn. Before dawn a soldier climbs over your garden fence: the artilleryman, the last of his gun."],
		],
	},
	{
		"title": "XII. The Destruction of Weybridge and Shepperton",
		"music": "pathetique_march",
		"book": BOOK_ONE,
		"cast": ["artilleryman", "narrator"],
		"scene": "res://scenes/soldier.tscn",
		"mode": "First person: the artilleryman's gun",
		"plates": [
			["plate_0099.jpg", "At the meeting of the Wey and the Thames, the machines came striding, their hoods turning, their cages swinging."],
			["plate_0111.jpg", "The hidden guns opened fire. \"The shell burst clean in the face of the Thing.\" A machine could be brought down."],
			["plate_0123.jpg", "It fell into the river in a storm of steam. The others came wading through the shallows, burning everything."],
			["plate_0143.jpg", "They gathered up their fallen comrade and carried it away. Take a gun. Bring one down. Free the people in its cage."],
		],
	},
	{
		"title": "Interlude: The Martian",
		"music": "mountain_king",
		"book": BOOK_ONE,
		"cast": ["martian"],
		"scene": "res://scenes/pilot.tscn",
		"mode": "First person: the fighting-machine",
		"plates": [
			["plate_0099.jpg", "See it from the other side. You stride over England. The humans' guns are an annoyance. The air of this world is not."],
		],
	},
	{
		"title": "XIII. How I Fell In with the Curate",
		"music": "suk_meditation",
		"book": BOOK_ONE,
		"cast": ["narrator", "curate"],
		"plates": [
			["", "Swept down the Thames, you come ashore near Walton and meet a curate sitting in the ruins. \"What does it mean?\" he asks. Coming soon."],
		],
	},
	{
		"title": "XIV-XVI. In London; The Exodus",
		"music": "mendelssohn_80",
		"book": BOOK_ONE,
		"cast": ["brother", "mrs_elphinstone", "miss_elphinstone"],
		"plates": [
			["plate_0255.jpg", "Your brother, a medical student in London, wakes to the news. \"It was the beginning of the rout of civilisation, of the massacre of mankind.\" Coming soon: lead a column of refugees out of the city."],
		],
	},
	{
		"title": "XVII. The Thunder Child",
		"music": "hebrides",
		"book": BOOK_ONE,
		"cast": ["brother", "mrs_elphinstone", "miss_elphinstone"],
		"plates": [
			["plate_0159.jpg", "Off the Essex coast, the steamers crowded with refugees. Then the ironclad came: \"It was the torpedo ram, Thunder Child, steaming headlong, coming to the rescue of the threatened shipping.\""],
			["plate_0167.jpg", "She took two machines down with her. Then, out of the greyness, \"something flat and broad, and very large, that swept round in a vast curve.\" Coming soon."],
		],
	},
	# ------------------------------------------------------------ BOOK TWO
	{
		"title": "I-VI. The Ruined House",
		"music": "pathetique_finale",
		"book": BOOK_TWO,
		"cast": ["narrator", "curate", "martian"],
		"scene": "res://scenes/ruined_house.tscn",
		"mode": "Stealth: fifteen days beside the pit",
		"plates": [
			["plate_0183.jpg", "The fifth cylinder fell on the house where the narrator sheltered with the curate, and buried them alive."],
			["plate_0195.jpg", "Through a crack in the wall they could see into the new pit. A machine stood over it."],
			["plate_0203.jpg", "The Martians' handling-machines worked day and night, building, digging, feeding."],
			["plate_0211.jpg", "The curate broke. He would not be quiet. The narrator had to choose."],
			["plate_0223.jpg", "A tentacle came through the hole in the wall, searching the scullery in the dark."],
			["plate_0231.jpg", "A red weed from Mars choked the house, and \"grew with astonishing vigour and luxuriance\"."],
			["plate_0247.jpg", "Fifteen days later, the pit was empty. Survive until then. Keep the Curate quiet, and keep out of the light."],
		],
	},
	{
		"title": "VII. The Man on Putney Hill",
		"music": "brahms_4",
		"book": BOOK_TWO,
		"cast": ["narrator", "artilleryman"],
		"plates": [
			["plate_0239.jpg", "The red weed clogged the rivers until the streets flooded. On Putney Hill you meet the artilleryman again. Coming soon."],
		],
	},
	{
		"title": "VIII. Dead London",
		"music": "aases_death",
		"book": BOOK_TWO,
		"cast": ["narrator"],
		"plates": [
			["plate_0283.jpg", "London was empty. The windows stared like eyes."],
			["plate_0263.jpg", "A howl went over the city, and then stopped."],
			["plate_0291.jpg", "On Primrose Hill, the great pit, full of their machines."],
			["plate_0297.jpg", "The fighting-machines stood silent. Crows circled them."],
			["plate_0275.jpg", "The Martians were dead, \"slain, after all man's devices had failed, by the humblest things that God, in his wisdom, has put upon this earth.\" Coming soon."],
		],
	},
	{
		"title": "IX-X. Wreckage; The Epilogue",
		"music": "morning",
		"book": BOOK_TWO,
		"cast": ["narrator", "wife"],
		"plates": [
			["plate_0303.jpg", "And the people came back to look."],
			["", "You walk home to Woking, to an empty house. And then: \"my wife white and tearless.\" \"I came,\" she said. Coming soon: the finale."],
		],
	},
]
