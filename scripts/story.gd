class_name Story
extends RefCounted
## The campaign, told through Henrique Alvim Corrêa's illustrations for the
## 1906 Belgian edition of The War of the Worlds (public domain; scans from
## Duke University Libraries via The Public Domain Review).
##
## Each plate has narration. Text in "quotes" is H. G. Wells' own (public
## domain); everything else is our narration.

const BOOK_ONE := "BOOK ONE  -  THE COMING OF THE MARTIANS"
const BOOK_TWO := "BOOK TWO  -  THE EARTH UNDER THE MARTIANS"

## scene: the playable mode for the chapter, or "" if not built yet.
const CHAPTERS := [
	{
		"title": "Prologue: The Eve of the War",
		"book": BOOK_ONE,
		"scene": "",
		"plates": [
			["plate_0011.jpg", "\"No one would have believed in the last years of the nineteenth century that this world was being watched keenly and closely by intelligences greater than man's and yet as mortal as his own.\""],
			["plate_0019.jpg", "Across the gulf of space, Mars watched. Astronomers saw strange flashes on its face, and laughed at talk of life there."],
			["plate_0027.jpg", "\"Then came the night of the first falling star.\" Over the rooftops of Surrey, a line of green flame fell towards Horsell Common."],
		],
	},
	{
		"title": "I. Horsell Common",
		"book": BOOK_ONE,
		"scene": "res://scenes/main.tscn",
		"mode": "Strategy",
		"plates": [
			["plate_0035.jpg", "In the sand-pit lay a great cylinder, hot and smoking. Crowds gathered. Its top began, very slowly, to unscrew."],
			["plate_0043.jpg", "\"Those who have never seen a living Martian can scarcely imagine the strange horror of its appearance.\""],
			["plate_0051.jpg", "Then the heat-ray. Men stepped into an invisible flame and were gone. The crowd broke and ran."],
			["plate_0059.jpg", "By nightfall the common was burning, and a machine had risen from the pit. Get the survivors out."],
		],
	},
	{
		"title": "II. The Storm",
		"book": BOOK_ONE,
		"scene": "",
		"plates": [
			["plate_0067.jpg", "\"A monstrous tripod, higher than many houses, striding over the young pine trees, and smashing them aside in its career.\""],
			["plate_0075.jpg", "Through the thunderstorm the machines went hunting. In the woods, the dead lay where they had fallen. Coming soon: escape through the storm."],
		],
	},
	{
		"title": "III. The Guns at Shepperton",
		"book": BOOK_ONE,
		"scene": "res://scenes/soldier.tscn",
		"mode": "First person: the gunner",
		"plates": [
			["plate_0099.jpg", "At the meeting of the Wey and the Thames, the machines came striding, their hoods turning, their cages swinging."],
			["plate_0111.jpg", "The hidden guns opened fire, and \"the shell burst clean in the face of the Thing.\" A machine could be brought down."],
			["plate_0123.jpg", "It fell into the river in a storm of steam. The others came wading through the shallows, burning everything."],
			["plate_0143.jpg", "They gathered up their fallen comrade and carried it away. Take a gun. Bring one down. Free the people in its cage."],
		],
	},
	{
		"title": "Interlude: The Martian",
		"book": BOOK_ONE,
		"scene": "res://scenes/pilot.tscn",
		"mode": "First person: the fighting-machine",
		"plates": [
			["plate_0099.jpg", "See it from the other side. You stride over England. The humans' guns are an annoyance. The air of this world is not."],
		],
	},
	{
		"title": "IV. The Exodus",
		"book": BOOK_ONE,
		"scene": "",
		"plates": [
			["plate_0255.jpg", "London woke to the news, and fled. \"It was the beginning of the rout of civilisation, of the massacre of mankind.\" Coming soon: lead a column of refugees out of the city."],
		],
	},
	{
		"title": "V. The Thunder Child",
		"book": BOOK_ONE,
		"scene": "",
		"plates": [
			["plate_0159.jpg", "Off the Essex coast, the steamers crowded with refugees. Then the ironclad came: \"It was the torpedo-ram, Thunder Child, steaming headlong, coming to the rescue of the threatened shipping.\""],
			["plate_0167.jpg", "She took two machines down with her. Over the sea, something flat and broad flew low through the haze. Coming soon."],
		],
	},
	{
		"title": "VI. The Ruined House",
		"book": BOOK_TWO,
		"scene": "",
		"plates": [
			["plate_0183.jpg", "The fifth cylinder fell on the house where the narrator sheltered with the curate, and buried them alive."],
			["plate_0195.jpg", "Through a crack in the wall they could see into the new pit. A machine stood over it."],
			["plate_0203.jpg", "The Martians' handling-machines worked day and night, building, digging, feeding."],
			["plate_0211.jpg", "The curate broke. He would not be quiet. The narrator had to choose."],
			["plate_0223.jpg", "A tentacle came through the hole in the wall, searching the scullery in the dark."],
			["plate_0247.jpg", "Fifteen days later, the pit was empty. Coming soon: a stealth chapter inside the ruined house."],
		],
	},
	{
		"title": "VII. The Red Weed",
		"book": BOOK_TWO,
		"scene": "",
		"plates": [
			["plate_0231.jpg", "A red weed from Mars choked the houses and the gardens, and \"grew with astonishing vigour and luxuriance\"."],
			["plate_0239.jpg", "It clogged the rivers until the streets flooded. Coming soon: survivors cross a drowned, red country."],
		],
	},
	{
		"title": "VIII. Dead London",
		"book": BOOK_TWO,
		"scene": "",
		"plates": [
			["plate_0283.jpg", "London was empty. The windows stared like eyes."],
			["plate_0263.jpg", "A howl went over the city, and then stopped."],
			["plate_0291.jpg", "On Primrose Hill, the great pit, full of their machines."],
			["plate_0297.jpg", "The fighting-machines stood silent. Crows circled them."],
			["plate_0275.jpg", "The Martians were dead, \"slain, after all man's devices had failed, by the humblest things that God, in his wisdom, has put upon this earth.\""],
			["plate_0303.jpg", "And the people came back to look. Coming soon: the finale, when every shield fails."],
		],
	},
]
