class_name Cast
extends RefCounted
## The characters of The War of the Worlds, as Wells describes them.
## "desc" and "line" are Wells' own words, checked against
## the-war-of-the-worlds.txt by tools/check_quotes.py. "role" is ours.
## Portraits: art/portraits/ (see art/portraits/CREDITS.md).

const PEOPLE := {
	"narrator": {
		"name": "The Narrator",
		"role": "A writer living at Woking. He tells the story.",
		"desc": "naked, save for my water-soaked trousers and socks, scalded, and my face and shoulders blackened by the smoke",
		"line": "They have done a foolish thing",
		"chapters": "Every chapter",
	},
	"wife": {
		"name": "His Wife",
		"role": "Taken to safety at Leatherhead. They are parted for the rest of the war.",
		"desc": "my wife white and tearless",
		"line": "They may come here",
		"chapters": "I. Horsell Common; VIII. Dead London",
	},
	"ogilvy": {
		"name": "Ogilvy",
		"role": "The well-known astronomer. The first to find the cylinder.",
		"desc": "He was immensely excited at the news",
		"line": "The chances against anything manlike on Mars are a million to one",
		"chapters": "Prologue; I. Horsell Common",
	},
	"stent": {
		"name": "Stent",
		"role": "The Astronomer Royal. He goes out to the pit to meet the Martians.",
		"desc": "a tall, fair-haired man that I afterwards learned was Stent, the Astronomer Royal",
		"line": "Keep back! Keep back!",
		"chapters": "I. Horsell Common",
	},
	"henderson": {
		"name": "Henderson",
		"role": "The London journalist. He wires the story to the papers.",
		"desc": "Henderson, the London journalist",
		"line": "Fallen meteorite! That's good.",
		"chapters": "I. Horsell Common",
	},
	"landlord": {
		"name": "The Landlord",
		"role": "Of the Spotted Dog. He lends the narrator his horse and dog cart.",
		"desc": "I knew the landlord had a horse and dog cart",
		"line": "I'm selling my bit of a pig.",
		"chapters": "I. Horsell Common",
	},
	"artilleryman": {
		"name": "The Artilleryman",
		"role": "The sole survivor of his gun. Our gunner.",
		"desc": "He was a driver in the artillery",
		"line": "Giants in armour, sir. Hundred feet high. Three legs and a body like 'luminium, with a mighty great head in a hood, sir.",
		"chapters": "I. Horsell Common; III. The Guns at Shepperton; VIII. Dead London",
	},
	"curate": {
		"name": "The Curate",
		"role": "Trapped with the narrator in the ruined house. His nerve breaks.",
		"desc": "His face was a fair weakness, his chin retreated, and his hair lay in crisp, almost flaxen curls on his low forehead; his eyes were rather large, pale blue, and blankly staring.",
		"line": "What do these things mean?",
		"chapters": "VI. The Ruined House",
	},
	"brother": {
		"name": "The Brother",
		"role": "A medical student in London. He flees the city with the Elphinstones.",
		"desc": "He was a medical student",
		"line": "We must go that way",
		"chapters": "IV. The Exodus; V. The Thunder Child",
	},
	"mrs_elphinstone": {
		"name": "Mrs. Elphinstone",
		"role": "A surgeon's wife, rescued on the road by the brother.",
		"desc": "a short woman dressed in white",
		"line": "What is this you are driving us into?",
		"chapters": "IV. The Exodus; V. The Thunder Child",
	},
	"miss_elphinstone": {
		"name": "Miss Elphinstone",
		"role": "Her sister-in-law. She fights off the thieves with a whip.",
		"desc": "astonishingly quiet and deliberate",
		"line": "",
		"chapters": "IV. The Exodus; V. The Thunder Child",
	},
	"martian": {
		"name": "The Martian",
		"role": "The invader, inside every fighting-machine.",
		"desc": "Those who have never seen a living Martian can scarcely imagine the strange horror of its appearance.",
		"line": "",
		"chapters": "Every chapter",
	},
}

const ORDER := ["narrator", "wife", "ogilvy", "stent", "henderson", "landlord", "artilleryman",
	"curate", "brother", "mrs_elphinstone", "miss_elphinstone", "martian"]


# Keep loaded portraits alive: a draw call only records the texture's RID, so
# a texture nobody holds would be freed before the frame is drawn.
static var _cache := {}


static func portrait(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load("res://art/portraits/%s.jpg" % id)
	return _cache[id]
