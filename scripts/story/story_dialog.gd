extends RefCounted
## Airron's Quest dialog (docs/STORY.md). Each node:
##   {"lines": [[speaker, text, cond?], ...], "choices": [{"t": text, "cond": "", "do": [actions], "next": id}],
##    "do": [actions run after the lines when there are no choices], "next": id}
## Speakers are StoryData.CAST ids. A line's optional third item is a condition (StoryData format).
## Actions: set:flag  clear:flag  recruit:id  loyal:id  battle:id  gold:N  item:id  heal  hurt:0.25  rally:0.5
##   act:II  tip:id  lesson:id  toast:text  dungeon  exit_dungeon  ending  boss:id  sparks (shows the Lantern count)
##   Any action can end in "?cond" to run only when the condition holds, e.g. "loyal:halvard?c1_price".
## Voices: Vellin over-polite and flustered · Orlan a showman with fear underneath · Taren soft, precise, two meanings
## in everything · Caldric vain, slowly won over · Maera bossy and fond · Selka exact, talks in stars · Grieve deadpan
## and dead · Halvard short sentences, hates crowns · Corvin counts odds, loves losing · Ilsabet a queen, never kneels.

const D := {
	# ------------------------------------------------------------------ Prologue
	"prologue": {"lines": [
		["vellin", "Ser Bramwell! Ser! Halt! Please! Sorry. Halt, please, ser."],
		["bramwell", "Vellin. If this is about the toast at the inn, it rhymed. Rhyming is legal."],
		["vellin", "It's not the toast, ser! Well, it's a little bit the toast. Mostly it's the king. You're summoned. Now."],
		["vellin", "All four Wardfires went dark last night. At once. The castle's been shouting since dawn."],
		["bramwell", "The Wardfires don't go out, Vellin. They've burned since before the walls."],
		["vellin", "That's what I said! Then the captain said a word I won't repeat, ser. And the Kindling is in three days."],
		["bramwell", "I guard graves. Nobody tells me anything. The graves certainly don't."],
		["vellin", "Castle's straight up the main road, ser. Big gate. Can't miss it. Please don't stop at the inn."],
	], "do": ["set:s_prologue", "act:I", "tip:journal"]},
	"vellin_idle": {"lines": [
		["vellin", "North, ser! Up the main road! The king is a patient man, but not today.", "!s_king"],
		["vellin", "Mind the Danger meter out there, ser. When it fills, something finds you. Usually something with teeth.", "s_king&sparks<1"],
		["vellin", "{sparks} of the four, ser! The lads on the wall have started saluting your house.", "sparks>=1&sparks<4"],
		["vellin", "All four sparks! I'll never doubt the Barrow Watch again, ser. Not out loud.", "sparks>=4"],
	]},
	"vellin_after": {"lines": [
		["vellin", "I saw the Matron fall from up on the wall, ser. I may have cried. Professionally.", "!s_ending"],
		["vellin", "The whole town knows your toast now, ser. The rhyming one. The children do the actions.", "s_ending"],
	]},

	# ------------------------------------------------------------------ Act I: the king's event
	"king_early": {"lines": [["orlan", "Ser Bramwell! Vellin was meant to fetch you. Never mind. Heroes find their own way. Come closer."]], "next": "king_audience"},
	"king_audience": {"lines": [
		["narr", "The throne room smells of old smoke. The coals of the Ember Throne have burned for nine kings. This morning they barely glow."],
		["orlan", "Ser Bramwell Tunn, Knight of the Barrow Watch! Do you know why I sent for you?"],
		["bramwell", "If it's the toast at the inn, Majesty, I can explain. It rhymed."],
		["orlan", "It did rhyme. Beautifully. No. Last night all four Wardfires on Cinderreach went dark. Roots, Forge, Star and Tide."],
		["taren", "Their Wardens have not come home, Majesty. Without the four sparks the throne cannot take the Kindling. And without the Kindling, the Ash walks in."],
		["orlan", "Taren Unlit, my Lamplighter. Thirty years he's tended these coals. When Taren says grave, I order a bigger shovel."],
		["orlan", "But a frightened town is worse than a dark one. So we shall make it a festival!"],
		["orlan", "I proclaim the Kindling Hunt! Whoever brings home all four sparks before Kindling Night will be named Hearth-Champion, and light the throne before the whole town!"],
		["caldric", "Then it's settled. I'll have them by supper, Majesty. Possibly before."],
		["caldric", "Barrow Watch, wasn't it? Do try not to get lost out there. The graves would miss you."],
		["narr", "Ser Caldric Morn, Knight of the Cinder Gate, sweeps out of the hall. His cape is very good."],
		["orlan", "Every champion needs a lantern. The Kindling Lantern. It holds a spark, and never burns the hand that carries it."],
		["orlan", "So, Ser Bramwell. How will you take my charge?"],
	], "choices": [
		{"t": "Swear the Oath. For Emberhold.", "do": ["set:c1_oath", "item:warden_mail"], "next": "king_oath"},
		{"t": "Name my price. Heroes eat too.", "do": ["set:c1_price", "gold:200"], "next": "king_price"},
	]},
	"king_oath": {"lines": [
		["orlan", "Then kneel... and rise, Ser Bramwell, Sworn of the Kindling. Carry my Writ. The armory sends Warden Mail with it."],
		["narr", "You received Warden Mail (in your bag; equip it from Build). The guards stand a little straighter as you pass."],
		["taren", "An oath. How very old-fashioned. Oaths are like candles, Ser Bramwell. Lovely, until someone needs the wax."],
	], "next": "king_end"},
	"king_price": {"lines": [
		["orlan", "Ha! Honest, at least. Two hundred gold now, and not one coin more until the throne is lit."],
		["narr", "You received 200 gold."],
		["taren", "Coin-sworn. How practical. Coin, at least, never asks what it's for."],
	], "next": "king_end"},
	"king_end": {"lines": [
		["taren", "Your aunt Maera tends the throne's coals with me. Speak with her before you go. She knows the old Wardfire roads."],
		["orlan", "Go with the Ember, Bramwell. And if you find my Wardens..."],
		["orlan", "...bring them home. Please. I am the ninth king to sit on this throne. I would very much like there to be a tenth."],
	], "do": ["set:s_king"]},
	"king_idle": {"lines": [
		["orlan", "The coals dim by the hour, Bramwell. I keep my hands on them so no one sees them shake.", "sparks<1"],
		["orlan", "{sparks} sparks in the Lantern! I can feel the throne warming. Or I'm sitting closer.", "sparks>=1&sparks<4"],
		["orlan", "Your Writ still stands, Sworn of the Kindling.", "c1_oath&sparks<4"],
		["orlan", "And I haven't forgotten your price, champion. A king pays his debts. Eventually.", "c1_price&sparks<4"],
	]},
	"king_return": {"lines": [
		["orlan", "Four sparks! Bramwell, you've done it! Roots, Forge, Star and Tide, all in one lantern!"],
		["narr", "Ser Caldric staggers into the hall, singed, muddy and empty-handed."],
		["caldric", "I... got lost. Also a goat chased me. It was a large goat."],
		["taren", "Majesty, it must be tonight. The plaza, the whole town, the sparks into the throne. It cannot last another day."],
		["orlan", "Then tonight it is! Hearth-Champion, meet us on the plaza before the castle gate. Bring your appetite. Joryn's baking."],
		["selka", "Bramwell. A word. The reliquary you brought me names the one who fed the Ash. It names the Lamplighter. I've told the guard captain. Be ready.", "reliquary_given"],
		["narr", "Selka presses a black iron key into your hand: the Reliquary Key. 'It was inside. It opens something under the old ruin.'", "reliquary_given"],
		["selka", "That reliquary in your pack. There's no time to read it now. Keep it close tonight. I don't like how quiet the stars are.", "c2_keep&!reliquary_given"],
		["narr", "As the court bustles out, Taren lingers by the throne. He rests a hand on the dying coals, the way you'd touch a sleeping animal.", "!reliquary_given"],
	], "do": ["set:s_return", "act:III", "lesson:boss"]},
	"king_after": {"lines": [
		["orlan", "The throne is going cold, Bramwell. Taren is in the Sunken Bastion with the Heart-Coal. Bring back the light. Bring back yourself."],
	]},
	"king_final": {"lines": [
		["orlan", "Hearth-Champion. Whatever you chose down there, you chose it for all of us. Emberhold remembers. So does the inn, unfortunately."],
	]},
	"selka_early": {"lines": [["selka", "The Great Hall. West, the Hall of Keepers. East, the Gallery of Banners. North, the throne. You're expected. Hurry."]]},
	"selka_idle": {"lines": [
		["selka", "Selka Orrery, royal armillary-scribe. I chart the stars. Lately they've been charting us."],
		["selka", "The Wardfires sit at the isle's four corners: Gloamwood to the west, Coalvein Cave in the north-east hills, Cliff Overlook on the east coast, the Drowned Steps on the south shore."],
		["selka", "Your journal (the Quests button, or J) always points to the next one. I checked twice."],
	]},
	"selka_reliquary": {"lines": [
		["selka", "Is that a cultist reliquary? From the Gloamwood? Give it here. Slowly. It's warmer than iron has any right to be."],
		["selka", "Names. Payments. A ledger of everyone who fed the Ash. This will take time. Some of these names I know."],
		["selka", "Bring the sparks home. I'll have answers by then. I hope they're the wrong ones."],
	], "do": ["set:reliquary_given", "toast:Gave the Black Reliquary to Selka"]},
	"selka_plaza": {"lines": [["selka", "Stay close to the king tonight. The stars are wrong. They've been wrong for three nights.", "!reliquary_given"], ["selka", "The guards are ready. Watch his hands, Bramwell. Not his face. His hands.", "reliquary_given"]]},
	"selka_after": {"lines": [["selka", "The Ember Throne was never a throne, Bramwell. It was a lid. Nine kings sat on it. Go."]]},
	"selka_end": {"lines": [["selka", "The stars are back where they belong. I checked twice. Then a third time, for fun."]]},
	"taren_idle": {"lines": [
		["taren", "The Ember remembers every hand that ever fed it, Ser Bramwell. Every one. Hurry.", "sparks<2"],
		["taren", "{sparks} sparks already? You are... efficient. The throne will be so grateful.", "sparks>=2"],
	]},
	"taren_plaza": {"lines": [["taren", "Tonight, Hearth-Champion, everything changes. Speak to the king when you're ready. I've been ready for thirty years."]]},
	"caldric_castle": {"lines": [
		["caldric", "Still here, Barrow Watch? I'll have two sparks by sunset. Three by supper. I eat late.", "sparks<1"],
		["caldric", "One spark is luck, Barrow Watch. Two is... also luck. Very persistent luck.", "sparks>=1"],
	]},
	"caldric_shore": {"lines": [
		["caldric", "Barrow Watch. This is fine. I meant to be stuck in the sand. It's strategy. Sand strategy."],
		["caldric", "{sparks} sparks? You? I... well done. If you tell anyone I said that I'll deny it under oath."],
	]},
	"caldric_plaza": {"lines": [["caldric", "Tonight's your night, Bramwell. I suppose. Try not to trip on the stage. I'll be watching. Supportively. Mostly."]]},
	"caldric_gate": {"lines": [["caldric", "I hold the gate. Nothing climbs out of that Bastion while I stand. Go, Bramwell. And... come back up."]]},
	"caldric_end": {"lines": [["caldric", "To the Hearth-Champion! Your round, Barrow Watch. Rhymes optional. Please no rhymes."]]},

	# ------------------------------------------------------------------ Maera (end of Act I)
	"maera_early": {"lines": [["maera", "Shouldn't you be at the castle? Vellin's run up and down that road so often he's worn a groove."]]},
	"maera_intro": {"lines": [
		["maera", "There's my barrow-knight! Summoned by the king? Sit. No, don't sit, you'll get soot on everything."],
		["maera", "Four Wardfires, four Wardens. When the fires died the Wardens went strange. A dead man, a stubborn one, a clockwork one and a queen."],
		["maera", "Gloamwood is closest, out the gate and west. Then the cave in the north-east hills, the cliffs on the east coast, and the sea down south."],
		["maera", "Out past the walls the Ash walks. Watch your Danger meter. When you're hurt, rest at the inn. Ten gold. I've told them to give you the good pillow."],
		["maera", "And Bram. Listen to me. I've fed those fires forty years. Fires that old don't go out."],
		["maera", "They're put out."],
		["maera", "Drink this. Ember tonic. Don't ask what's in it, and don't tell the king I said that."],
		["narr", "Your party is fully healed. Maera slips 30 gold into your pocket when she thinks you aren't looking."],
	], "do": ["heal", "gold:30", "set:s_maera", "act:II", "tip:danger"]},
	"maera_idle": {"lines": [
		["maera", "Gloamwood first, dear. Out the gate, then west along the road.", "!got_grieve"],
		["maera", "{sparks} sparks! Your uncle would've toasted all night. He'd have rhymed too. Badly.", "sparks>=1"],
		["maera", "Taren and I have fed those coals side by side for thirty years. He hasn't smiled once. Lately he hums.", "sparks>=3"],
	], "do": ["heal"], "after": "Maera's tonic heals the party."},
	"maera_late": {"lines": [["maera", "Taren? Thirty years beside me and I never... Go. Bring that coal home. And come home yourself, or I'll come down there."]], "do": ["heal"]},
	"maera_end": {"lines": [["maera", "My barrow-knight, Hearth-Champion. Now sit. Yes, now you may get soot on everything."]], "do": ["heal"]},

	# ------------------------------------------------------------------ Act II: Grieve, Wardfire of Roots
	"grieve_meet": {"lines": [
		["narr", "Under the old willow, the earth heaves. A hand in a rusted gauntlet pushes up through the roots."],
		["grieve", "...Again? That's three. Somebody owes me a very long nap."],
		["bramwell", "Easy! Bramwell, Barrow Watch. Usually my job is making sure people stay down."],
		["grieve", "Then you're bad at it. Grieve. Warden of Roots. Twice buried, and as of tonight, thrice annoyed."],
		["grieve", "Cultists buried me under my own fire and left a reliquary in it. It's choking the flame. And it brought friends."],
		["narr", "Gloam moths pour out of the roots, and something with far too many joints crawls after them."],
		["grieve", "Before we start. You hit first, I hit right behind you. Same target. Hits that land together spark. I learned that at my first funeral."],
		["grieve", "Well, barrow-knight? Shall we bury something together?"],
	], "do": ["recruit:grieve", "lesson:order", "lesson:spark", "battle:fight_grieve"]},
	"grieve_retry": {"lines": [["grieve", "Still breathing? Lucky. One of us should be. The leaper's still twitching. Same target, same moment. Again."]], "do": ["battle:fight_grieve"]},
	"grieve_after": {"lines": [
		["narr", "The leaper falls apart into ash. The Wardfire of Roots flickers back, wrapped around a black iron reliquary."],
		["grieve", "There it is. The thing that buried me. It hums with their prayers. Names, maybe. Plans."],
		["grieve", "Burn it, and I'll finally sleep easy when my time comes. Or carry it to someone clever. Your choice. I'll sulk either way."],
	], "choices": [
		{"t": "Burn it. You've earned your rest.", "do": ["set:c2_burn", "loyal:grieve", "item:gravebell"], "next": "grieve_burn"},
		{"t": "Keep it. Selka in the castle can read it.", "do": ["set:c2_keep"], "next": "grieve_keep"},
	]},
	"grieve_burn": {"lines": [
		["narr", "The reliquary goes into the flame. The Wardfire roars, green and gold, and the willow's leaves shiver."],
		["grieve", "...Huh. Lighter. Here. This bell rang at both my funerals. Let it ring for something better."],
		["narr", "Grieve is loyal. You received the Gravebell (an amulet, in your bag)."],
	], "next": "grieve_spark"},
	"grieve_keep": {"lines": [
		["grieve", "Clever people. It's always clever people. Clever people dug my first grave."],
		["narr", "The black reliquary is cold and heavy in your pack. Selka, the scribe in the castle, might be able to read it."],
	], "next": "grieve_spark"},
	"grieve_spark": {"lines": [
		["narr", "You raise the Kindling Lantern. A green-gold spark leaps inside: the Wardfire of Roots. One of four."],
		["grieve", "I'll come. Someone has to keep you from getting buried. Next is the old baron in the cave. He'll hate you. He hates everyone. Bring something to hit."],
	], "do": ["set:got_grieve", "sparks", "tip:order", "set:adeyo_on", "toast:New side quest: The Star-Reader"]},

	# ------------------------------------------------------------------ Halvard, Wardfire of the Forge
	"halvard_meet": {"lines": [
		["narr", "Hammer blows ring out of Coalvein Cave, slow and stubborn. An old man in rust-red plate stands at its mouth, an anvil on his shoulder."],
		["halvard", "King sent you? Turn around. A crown took my barony. My mines. My name. It doesn't get my anvil."],
		["halvard", "...Wait. Coin-sworn, are you? Taverns talk. A sellsword. Not a leash. Hm.", "c1_price"],
		["halvard", "Sworn knight. I can smell the Writ on you. Smells like ink and somebody else's war.", "c1_oath"],
		["grieve", "Halvard. Still cheerful, I see.", "r_grieve"],
		["halvard", "Grieve. Still dead, I see.", "r_grieve"],
		["bramwell", "The Forge Wardfire's out, Halvard. Without it the throne goes cold, and the Ash doesn't care about crowns."],
		["halvard", "No. It doesn't. Brutes came up out of the deep and sat on my fire like hens. Big hens."],
		["halvard", "Fine. I'll fight. You fall, I go back to my anvil. Line up behind the big one. Me. I'm the big one."],
	], "do": ["recruit:halvard", "battle:fight_halvard"]},
	"halvard_retry": {"lines": [["halvard", "Back. Good. The brutes didn't go anywhere. Neither did I. Check your Attack Order. Then hit harder."]], "do": ["battle:fight_halvard"]},
	"halvard_after": {"lines": [
		["narr", "Deep in the cave, the Forge Wardfire roars back to life, white-hot."],
		["halvard", "Not bad for a hired blade. Take my pledge-hammer. Never struck a crown. Yet.", "c1_price"],
		["narr", "Halvard is loyal. You received the Rust Baron's Pledge (a weapon, in your bag).", "c1_price"],
		["halvard", "You fight well. For a king's dog. I'll come. For the fire. Not for him.", "c1_oath"],
		["narr", "A white spark leaps into the Lantern: the Wardfire of the Forge."],
		["halvard", "Brass fool on the east cliffs owes me forty crowns. Find him. He's the Star Warden. Don't play dice with him."],
	], "do": ["loyal:halvard?c1_price", "item:rust_pledge?c1_price", "set:got_halvard", "sparks"]},

	# ------------------------------------------------------------------ Corvin, Wardfire of the Star
	"corvin_meet": {"lines": [
		["narr", "At the cliff edge a brass figure sits with its legs over the drop, rolling dice on the stone. A light pulses in its chest, slow and tired."],
		["corvin", "Snake eyes. Eleven times running. The odds of that are one in three hundred and sixty-two billion. I worked it out on the way down."],
		["bramwell", "On the way down from where?"],
		["corvin", "Up there. Low orbit. I was a duelist on a ship that doesn't exist any more. Corvin Brass. At your service, and losing."],
		["corvin", "Halvard sent you? Tell him the forty crowns are in a very safe place. The sea.", "r_halvard"],
		["corvin", "Bad news: the Star Wardfire is me. They built it around the fallen star that keeps my gears turning."],
		["corvin", "You could take a spark from my heart. I'd live. Dimmer. Slower. Or crack open a Reliquary Engine on the strand. They carry stolen starlight."],
		["corvin", "They also carry very large hammers. I'd put us at sixty-forty. Against."],
	], "choices": [
		{"t": "I'll take the spark from your heart.", "do": ["set:c3_heart"], "next": "corvin_heart"},
		{"t": "Keep your heart. We hunt the Engine.", "do": ["set:c3_hunt", "recruit:corvin"], "next": "corvin_hunt"},
	]},
	"corvin_heart": {"lines": [
		["corvin", "...Right. Steady hands, please. I'm told I tickle."],
		["narr", "You open the Lantern. A blue spark drifts out of Corvin's chest, and his light sinks to an ember."],
		["corvin", "Still ticking. Slower, but ticking. I'll tag along anyway. Somebody has to keep score."],
		["corvin", "Last one's the Tide queen, down on the south shore. Odds she makes you kneel: high. Odds you'll enjoy it: low."],
	], "do": ["recruit:corvin", "set:got_corvin", "sparks"]},
	"corvin_hunt": {"lines": [["corvin", "Ha! I like you. Terrible odds. Let's go lose spectacularly."]], "do": ["battle:fight_engine"]},
	"corvin_retry": {"lines": [["corvin", "Round two? I've recalculated. Our odds are now merely bad. Bad is an improvement."]], "do": ["battle:fight_engine"]},
	"corvin_hunt_after": {"lines": [
		["narr", "The Engine's core cracks open, and stolen starlight pours into the Lantern."],
		["corvin", "Look at that. My heart's still mine. Take the dice. They're loaded, but only in your favor. I checked. Eleven times."],
		["narr", "Corvin is loyal. You received the Loaded Dice (gloves, in your bag)."],
		["corvin", "Last one's the Tide queen, down on the south shore. Odds she makes you kneel: high. Odds you'll enjoy it: low."],
	], "do": ["loyal:corvin", "item:loaded_dice", "set:got_corvin", "sparks"]},

	# ------------------------------------------------------------------ Ilsabet, Wardfire of the Tide
	"ilsabet_meet": {"lines": [
		["narr", "At the Drowned Steps the tide has gone out much too far. A woman in a crown of wet pearls stands where the sea ought to be."],
		["ilsabet", "Kneel or don't. I stopped insisting a century ago. I have not stopped noticing."],
		["ilsabet", "You carry a king's Writ. An oath-keeper. How rare. I had a whole court of those, once.", "c1_oath"],
		["ilsabet", "A sellsword. At least you're honest about the price. My court never was.", "c1_price"],
		["ilsabet", "I am Ilsabet, Queen of the Drowned Court. My court slept beneath this water. Slept. The Cardinal woke them."],
		["ilsabet", "My own priest. He put out the Tide fire so my dead would serve him instead. He's down there now, wearing them like a cloak."],
		["ilsabet", "Help me take back my throne, knight, and the Tide's spark is yours. Fail, and you may keep my court company."],
	], "do": ["recruit:ilsabet", "battle:fight_cardinal"]},
	"ilsabet_retry": {"lines": [["ilsabet", "He still wears my court like a cloak. I will not ask a third time, knight. Well. I will. Grudgingly."]], "do": ["battle:fight_cardinal"]},
	"ilsabet_after": {"lines": [
		["narr", "The Cardinal sinks. The tide rushes back in, full of pale lights: the souls of the drowned court."],
		["ilsabet", "As he sank he laughed, knight. 'The Lamplighter will be so pleased.' I don't know any Lamplighter. Do you?"],
		["ilsabet", "My court is free, and lost. I can let the tide carry them home to rest."],
		["ilsabet", "Or you can bind them to the Tide fire. Bound, they would fight for the Lantern wherever you go next."],
	], "choices": [
		{"t": "Let the tide take them home.", "do": ["set:c4_rest", "loyal:ilsabet", "item:tideglass"], "next": "ilsabet_rest"},
		{"t": "Bind them. We'll need every blade.", "do": ["set:c4_bind"], "next": "ilsabet_bind"},
	]},
	"ilsabet_rest": {"lines": [
		["ilsabet", "Go gently, all of you. Go home."],
		["narr", "The lights sink into the sea one by one. Ilsabet watches until the last one is gone."],
		["ilsabet", "Take this pearl from my crown. A queen pays her debts. And I will follow you, knight. Gladly. Don't make me regret the word."],
		["narr", "Ilsabet is loyal. You received the Tideglass Shard (an amulet, in your bag)."],
	], "next": "ilsabet_spark"},
	"ilsabet_bind": {"lines": [
		["ilsabet", "...As you command."],
		["narr", "The pale lights coil into the Tide fire and turn to follow the Lantern. Ilsabet does not look at you."],
		["ilsabet", "They will fight for you now. So will I. Don't mistake it for anything more."],
	], "next": "ilsabet_spark"},
	"ilsabet_spark": {"lines": [["narr", "A sea-green spark leaps into the Lantern: the Wardfire of the Tide."]], "do": ["set:got_ilsabet", "sparks"]},

	# End of Act II: plays by itself the moment the fourth spark is in the Lantern (Story._finish).
	"four_sparks": {"lines": [
		["narr", "Four sparks circle inside the Lantern: green, white, blue and sea-green. It's warm enough to feel through your gauntlet."],
		["narr", "Then it tugs. Gently, like a dog on a lead. North. Toward Emberhold. Toward the throne."],
		["grieve", "Fires that old don't die, barrow-knight. Somebody put them out. Somebody with a key to the throne room.", "r_grieve"],
		["ilsabet", "'The Lamplighter will be pleased.' I keep hearing it. Whoever that is, I would like a word. With a sword.", "r_ilsabet"],
		["corvin", "Odds someone at the castle wanted this to happen? I'd stop betting against it.", "r_corvin"],
		["halvard", "Crowns. Always crowns.", "r_halvard"],
		["bramwell", "Home, then. The king's waiting. And I'd like to see who's happy to see us."],
	], "do": ["tip:home"]},

	# ------------------------------------------------------------------ Adeyo, the Star-Reader (Ember Inn; docs/CLASSES.md)
	"adeyo_early": {"lines": [
		["adeyo", "A party of one? Sweet. The stars don't read solos, love. They get shy."],
		["adeyo", "Come back when someone else is willing to share your luck. Then we'll talk about who you could be."],
	]},
	"adeyo_intro": {"lines": [
		["narr", "In the candle-lit corner of the Ember Inn a woman in star-stitched blue is reading the ceiling as if it were a letter."],
		["adeyo", "Ah. The Hearth-Champion, and a dead man who walks like he's late for his own funeral. Sit."],
		["grieve", "I'm not late. I'm early. For the second one.", "r_grieve"],
		["adeyo", "Adeyo. I read stars. Not your fortune: your calling. Warrior, Mage, Cleric, the lot. Ten of them, written over every head."],
		["adeyo", "Change one, and the old one waits for you, every lesson kept. The sky is a very patient bookkeeper."],
		["adeyo", "One thing the stars won't change: who you are. Each of you carries a move that's yours alone. I can only make it shine brighter in the right coat."],
		["bramwell", "And the price?"],
		["adeyo", "The stars are free. The candles are two copper, and I'm not counting. Much."],
	], "choices": [
		{"t": "Read our stars.", "do": ["set:met_adeyo", "divine"], "next": ""},
		{"t": "Another time.", "do": ["set:met_adeyo"], "next": "adeyo_later"},
	]},
	"adeyo_later": {"lines": [["adeyo", "The stars will keep. They're good at that. It's practically all they do."]]},
	"adeyo_idle": {"lines": [
		["adeyo", "{party} keepers, {party} skies. Whose calling shall we turn over tonight?"],
	], "choices": [
		{"t": "Read our stars.", "do": ["divine"], "next": ""},
		{"t": "What's new up there?", "next": "adeyo_news"},
		{"t": "Not tonight.", "next": ""},
	]},
	"adeyo_news": {"lines": [
		["adeyo", "The Warlock's star is still dark. Something on Kindling Night will light it. Or burn it. One of those.", "!s_kindling"],
		["adeyo", "The Warlock's star is lit. Ash teaches, if you let it. Bad teacher. Very thorough.", "s_kindling"],
		["adeyo", "And the Bard's star hums when the shrine bell is quiet. Ask Sister Wenna about that bell.", "!sq_bell_done&!s_return"],
		["adeyo", "The Bard's star is singing. Badly. They always do at first.", "sq_bell_done|s_return"],
	]},

	# ------------------------------------------------------------------ Spots
	"forest_look": {"lines": [["narr", "Gloamwood Heart. The oldest tree on the isle hums with a low ember light, and the ground at its roots looks freshly turned."]]},
	"forest_after": {"lines": [["narr", "The Wardfire of Roots burns green and gold among the willow roots.", "c2_burn"], ["narr", "The Wardfire of Roots burns, but the place where the reliquary sat is still cold.", "c2_keep"]]},
	"cave_look": {"lines": [["narr", "Coalvein Cave. Warm air breathes out of the dark, along with the sound of a hammer and some very old swearing."]]},
	"cave_after": {"lines": [["narr", "Down in the deep forge the Wardfire burns white-hot again."]]},
	"overlook_look": {"lines": [["narr", "Cliff Overlook. All of Cinderreach below, and nothing but sea beyond. Someone has been rolling dice on the cairn. Badly."]]},
	"overlook_after": {"lines": [["narr", "The star-scar on the cliff glows faintly blue."]]},
	"steps_look": {"lines": [["narr", "The Drowned Steps lead down into the sea. The water is too low, and the steps are much too clean."]]},
	"steps_after": {"lines": [["narr", "The tide is back where it belongs, lapping over the steps.", "c4_rest"], ["narr", "Pale lights drift under the water, waiting for the Lantern.", "c4_bind"]]},
	"ruin_sealed": {"lines": [["narr", "The Sunken Bastion: a fallen keep. An old seal of hammered bronze covers the stair down. It's warm to the touch, and it's humming."]]},
	"ruin_after": {"lines": [["narr", "The Bastion's stair is quiet now. Nothing climbs it any more."]]},
	"shrine_pray": {"lines": [["narr", "Votive Shrine. You light a candle. The danger in the air settles, for a while."]], "do": ["calm"]},

	# ------------------------------------------------------------------ Side quests
	"pell_idle": {"lines": [["pell", "The store buys anything you can carry. Mostly. Me, I only buy powder. And eyebrows. I keep losing eyebrows."]]},
	"pell_offer": {"lines": [
		["pell", "Bramwell! Disaster! My Kindling fireworks! Three crates! They fell off the cart on the way back from the Tarfen!"],
		["pell", "One's in the north meadow, one by the east shore, one down on the south-west strand. Bring them back and I'll make the sky sing on Kindling Night."],
		["pell", "Don't shake them. Don't drop them. Don't let them get warm. Or cold. Or look at them funny."],
	], "do": ["set:sq_fire_on", "toast:New side quest: Pell's Lost Fireworks"]},
	"pell_wait": {"lines": [["pell", "Found my crates? Don't shake them. Please don't shake them. Are you shaking them right now?"]]},
	"pell_turnin": {"lines": [
		["pell", "All three! Not even singed! You beautiful barrow-knight!"],
		["pell", "Here's 120 gold. And on Kindling Night, watch the sky. Green, white, blue and gold. One for each Wardfire."],
	], "do": ["gold:120", "set:sq_fire_done", "toast:Side quest complete: Pell's Lost Fireworks"]},
	"pell_after": {"lines": [["pell", "Best show I ever lit. Shame about the giant ash monster. Bit of a scene-stealer.", "sq_fire_done"], ["pell", "Next Kindling I'm packing the crates myself. In a bigger cart. With walls.", "!sq_fire_done"]]},
	"crate_1": {"lines": [["narr", "A crate stamped PELL - DO NOT DROP. You pick it up very carefully."]], "do": ["set:crate_1", "crates"]},
	"crate_2": {"lines": [["narr", "A crate stamped PELL - THIS SIDE UP. It is upside down. You fix that."]], "do": ["set:crate_2", "crates"]},
	"crate_3": {"lines": [["narr", "A crate stamped PELL - NO, REALLY. Something inside fizzes politely."]], "do": ["set:crate_3", "crates"]},
	"wenna_idle": {"lines": [["wenna", "Danger stirs once you leave the walls. Watch the ember meter, and come back to the inn when you're hurt."]]},
	"wenna_offer": {"lines": [
		["wenna", "Ser Bramwell, a moment. The bell at the Votive Shrine has rung by itself every night since the fires died. Something answers it."],
		["wenna", "Would you ring it once, properly, and quiet whatever comes? The shrine is at the west end of the road, before the forest."],
	], "do": ["set:sq_bell_on", "toast:New side quest: The Quiet Bell"]},
	"wenna_wait": {"lines": [["wenna", "Every bell I ring is for someone who didn't come home. Please, quiet that one."]]},
	"wenna_turnin": {"lines": [
		["wenna", "It's quiet. I heard it stop from here. Thank you."],
		["wenna", "Take this pendant. And come to me whenever you're hurt. The Quiet Bell doesn't charge."],
	], "do": ["item:brook_pendant", "set:sq_bell_done", "heal", "toast:Side quest complete: The Quiet Bell"]},
	"wenna_heal": {"lines": [["wenna", "Be still a moment. There."], ["narr", "Wenna's blessing restores your party."]], "do": ["heal"]},
	"shrine_bell": {"lines": [
		["narr", "You take the bell rope and pull. The note hangs in the air, much too long."],
		["narr", "Something heavy answers from the trees, ringing a bell of its own."],
	], "do": ["battle:fight_bell"]},
	"bell_after": {"lines": [["narr", "The Knellbearer drops its bell and crumbles. The shrine falls silent. Sister Wenna will want to know."]], "do": ["set:bell_rung"]},
	"drosk_idle": {"lines": [
		["drosk", "Drosk Coinwright. Odds, ends, and mostly odds.", "!s_king"],
		["drosk", "Your bet's safe with me. Mostly safe. Safe-ish. It's in a box.", "sq_book_bet&!s_kindling"],
		["drosk", "Pleasure doing business, champion. Come back next Kindling. Bring a worse hero.", "sq_book_paid"],
		["drosk", "Book's closed. You should've bet on yourself. I did. Quietly.", "!sq_book_bet&s_kindling"],
	]},
	"drosk_offer": {"lines": [
		["drosk", "The Kindling Hunt book is open! Ser Caldric's the favourite at two to one. You... are forty to one."],
		["drosk", "Fancy a flutter on yourself? Fifty gold. I'll pay four to one. For the health of the house."],
	], "choices": [
		{"t": "Fifty gold on me.", "cond": "gold>=50", "do": ["gold:-50", "set:sq_book_bet", "toast:New side quest: Drosk's Book"], "next": "drosk_bet"},
		{"t": "Not today.", "next": ""},
	]},
	"drosk_bet": {"lines": [["drosk", "Ha! A champion with confidence. Collect after Kindling Night, if you're alive. No refunds for the dead."]]},
	"drosk_payout": {"lines": [
		["drosk", "Hearth-Champion! You've ruined me. Two hundred gold, as promised. I'm moving to the mainland. Possibly under a new name."],
	], "do": ["gold:200", "set:sq_book_paid", "toast:Side quest complete: Drosk's Book"]},
	"joryn_idle": {"lines": [["joryn", "Fresh from the stall! Well. Fresh-ish. Fresh-adjacent."]]},
	"joryn_hunt": {"lines": [
		["joryn", "Ember buns! Kindling Hunt special! Caldric bought six and fell off his horse.", "sparks<2"],
		["joryn", "They're saying you've got {sparks} sparks. Have a bun. On the house. It's a bit stale. It's a lot stale.", "sparks>=2"],
	]},
	"joryn_after": {"lines": [["joryn", "The Lamplighter bought a bun from me every morning for thirty years. Exact change. Every day. I should've known."]]},
	"joryn_end": {"lines": [["joryn", "Hearth-Champion buns! Same buns. New name. Double price."]]},

	# ------------------------------------------------------------------ Act III: Kindling Night (mini-boss)
	"kindling": {"lines": [
		["narr", "Night falls on Emberhold. There are lanterns on every sill, and the whole town has squeezed into the plaza."],
		["narr", "Pell's fireworks crack overhead: green, white, blue and gold. The crowd roars. Somewhere, Pell loses an eyebrow.", "sq_fire_done"],
		["orlan", "People of Emberhold! Tonight, the tenth Kindling! Ser Bramwell, Hearth-Champion, bring forth the sparks!"],
		["narr", "You open the Lantern. Four sparks rise into the night: Roots, Forge, Star and Tide."],
		["taren", "Allow me, Majesty. I have fed this flame for thirty years. Let me feed it one last time."],
		["bramwell", "Not one step closer, Taren. The reliquary from the Gloamwood. It had your name in it.", "reliquary_given"],
		["taren", "...Clever scribe. It hardly matters now.", "reliquary_given"],
		["narr", "Guards close in around the king, just as Selka warned them.", "reliquary_given"],
		["taren", "Thirty years feeding a fire whose only purpose is to keep something asleep. Something old. Something that promised me a fire that never needs feeding."],
		["narr", "Taren closes his fist around the four sparks. Every brazier on the plaza goes black at once."],
		["narr", "Something huge drags itself up out of the ash in the square."],
		["taren", "Meet the Matron of Cinders. She's very motherly. Goodbye, Hearth-Champion."],
		["matron", "Hush now, little embers. Mother is here. Mother will tuck you in."],
	], "do": ["battle:miniboss_matron"]},
	"kindling_lose": {"lines": [
		["narr", "The Matron's heat drives you back, but the guards drag the party clear. She's still in the square, humming a lullaby."],
		["selka", "Regroup, Bramwell. Change your Attack Order, get stronger if you must. We'll hold her here. Talk to the king when you're ready."],
	], "do": ["heal"]},
	"matron_after": {"lines": [
		["narr", "The Matron collapses into a drift of cinders, and the braziers flicker back to life."],
		["narr", "Taren is gone. So is the Heart-Coal, the throne's last ember, torn from the castle while you fought."],
		["orlan", "He's taken the Heart-Coal into the Sunken Bastion. The old seal is broken. Without that coal the throne dies by dawn."],
		["selka", "The Bastion was built over something. The Ash Sovereign. The Ember Throne was never a throne, Majesty. It was a lid."],
		["orlan", "...Nine kings. Nine kings sat on a lid, and called it a throne."],
		["caldric", "Ser Bramwell. I was wrong about you. I'm wrong about a lot. Let me hold the gate while you go down. Please."],
		["orlan", "Go, Hearth-Champion. The ruin east of the town. Bring back the light, before the dawn takes it."],
	], "do": ["set:s_kindling", "boss:miniboss_matron", "act:IV", "lesson:final"]},

	# ------------------------------------------------------------------ Act IV: the Sunken Bastion
	"bastion_enter": {"lines": [
		["narr", "The bronze seal lies cracked in two. Stairs, slick with ash, spiral down into the dark under the ruin."],
		["narr", "Caldric's torch burns at the top of the stair. He gives you a nod that's trying very hard to be casual."],
		["halvard", "Down. Good. I hate stairs going up.", "r_halvard"],
	], "choices": [
		{"t": "Descend into the Bastion.", "do": ["set:s_bastion", "dungeon"], "next": ""},
		{"t": "Not yet.", "next": ""},
	]},
	"f1_enter": {"lines": [
		["narr", "The Drowned Gate. Black water stands ankle deep across the hall. Something with a ledger and a scythe waits at the far door."],
		["corvin", "It's taking notes. I hate it when they take notes.", "r_corvin"],
	]},
	"f1_skip": {"lines": [
		["narr", "The Reliquary Key turns in a side door you would never have seen. You slip past the Drowned Gate's guardian. It never even looks up from its ledger."],
		["grieve", "Clever people. Fine. Sometimes it's clever people.", "r_grieve"],
	], "do": ["set:bastion_f1"]},
	"f1_after": {"lines": [["narr", "The Tithe Collector drops its ledger. Every page is a name. The way down to the Reliquary Halls is open."]]},
	"f2_enter": {"lines": [
		["narr", "The Reliquary Halls. Bells hang from every arch, and a Knellbearer paces among them."],
		["ilsabet", "My court would have cleared this hall for us. I let them rest. I would do it again.", "c4_rest"],
	]},
	"f2_bind": {"lines": [
		["narr", "The Lantern flares sea-green. The drowned court pours out of it, a cold tide of pale lights."],
		["narr", "They wash over the Knellbearer, and when the water drains away there's nothing left but a bell."],
		["ilsabet", "...They did that for you. Remember it."],
	], "do": ["set:bastion_f2", "boss:guardian_f2"]},
	"f2_after": {"lines": [["narr", "The last bell stops swinging. Below, something breathes. Slowly. Like a sleeper about to wake."]]},
	"final_confront": {"lines": [
		["narr", "At the bottom of the Bastion stands a throne of black glass. On it sits something that used to be a man."],
		["taren", "You came. Of course you did. Heroes always come down the stairs."],
		["taren", "The Regnant promised me a fire that never needs feeding. All it wants in return is to be let out."],
		["bramwell", "Taren, it's using you."],
		["taren", "Everyone uses everyone, barrow-knight. Ask your Wardens."],
		["grieve", "Some of us chose to be here, Lamplighter.", "loyal_grieve"],
		["ilsabet", "He has a point, knight. I didn't choose. You chose for me.", "c4_bind"],
		["corvin", "Odds are he's wrong. I'm rarely wrong about odds. I'm often wrong about everything else.", "loyal_corvin"],
		["halvard", "Talks like a king. I hate him already.", "r_halvard"],
		["narr", "The Unlit Regnant rises behind the throne, and Taren's shadow goes with it."],
		["regnant", "LITTLE LAMPLIGHTER. YOU BROUGHT ME GUESTS."],
	], "do": ["battle:boss_regnant"]},
	"regnant_after": {"lines": [
		["narr", "The Regnant shatters like black glass. Taren falls to his knees with the Heart-Coal glowing in his hands... and the floor splits open."],
		["narr", "Far below, something vast opens one grey eye: the Ash Sovereign."],
		["taren", "It's waking... I can't hold it... take the coal! Take it and run!"],
		["narr", "The dark reaches up out of the crack for Taren."],
	], "choices": [
		{"t": "Pull Taren out. (The dark will burn you.)", "do": ["set:c5_spare"], "next": "taren_spare"},
		{"t": "Leave him to the dark.", "do": ["set:c5_leave"], "next": "taren_leave"},
	]},
	"taren_spare": {"lines": [
		["narr", "You grab his wrist. The dark burns like cold fire, but the party hauls him clear."],
		["taren", "Why...?"],
		["bramwell", "Because somebody has to tend the fire afterwards. Get behind us."],
	], "next": "sovereign_intro"},
	"taren_leave": {"lines": [["narr", "The dark closes over Taren without a sound. The Heart-Coal rolls to your feet, still warm."]], "next": "sovereign_intro"},
	"sovereign_intro": {"lines": [
		["narr", "The Lantern flares. Four sparks burn against the dark, and your wounds close over. Most of them."],
		["narr", "The dark-burn on your arm doesn't close. The Lantern can't mend what the Sovereign touched.", "c5_spare"],
		["narr", "The Ash Sovereign climbs out of the crack, crowned in the grey of every fire that ever went out."],
		["sovereign", "NINE KINGS. ONE LID. AND NOW... A BARROW-KNIGHT."],
		["halvard", "Swing first. Worry later.", "r_halvard"],
		["bramwell", "Everyone. Together. Same target, same moment. Now!"],
	], "do": ["rally:1.0", "hurt:0.05?c5_spare", "battle:boss_sovereign"]},
	"sovereign_after": {"lines": [
		["narr", "The Sovereign comes apart like a burned-out log, and the Bastion goes quiet."],
		["narr", "The Heart-Coal is warm in your hand. Up above, the Ember Throne is going cold, and the dawn is coming."],
		["narr", "You could return it to the throne and keep the old lid for another hundred years. Or break it among the four Wardfires, and trust the Wardens to stand their fires."],
		["narr", "(The Wardens who stand by you: {loyal} of 4.)"],
	], "choices": [
		{"t": "Return the Heart-Coal to the Ember Throne.", "do": ["set:end_throne", "ending"], "next": ""},
		{"t": "Share it among the four Wardfires.", "do": ["set:end_hearth", "ending"], "next": ""},
	]},
	"lose_generic": {"lines": [
		["narr", "You were driven back. The party regroups, bruised but alive."],
		["narr", "Tip: win a few wild battles to level up, and set your Attack Order in Menu > Build so hits land together and spark. Then talk to them again."],
	], "do": ["heal"]},
	"lose_bastion": {"lines": [["narr", "The guardian drives you back up the stair. Caldric drags you the last few steps. Rest, regroup, and go down again."]], "do": ["heal"]},
	"lose_final": {"lines": [
		["narr", "The dark throws you back up the stair. Caldric catches you at the top."],
		["caldric", "Breathe. It's still down there. So is the coal. We go again when you're ready. You go. I hold the torch."],
	], "do": ["heal"]},
}

## Ambient chatter in Emberhold: what townsfolk say as you walk past (floating barks) and when you talk to them.
## Keyed by NPC id (StoryData NPCS / BASE). Each line: [cond, text]. The first lines whose cond holds are used,
## so every act reads differently. Act conditions: I "!s_maera", II "s_maera&!s_return", III "s_return&!s_kindling",
## IV "s_kindling&!s_ending", Epilogue "s_ending".
const CHATTER := {
	"liris": [
		["!s_maera", "All four Wardfires? At once? My gran says it's an omen. My gran says everything's an omen."],
		["s_maera&!s_return&sparks<2", "Ser Caldric rode out at dawn. Then rode back for his other cape. Then rode out again."],
		["got_grieve&!met_adeyo", "There's a star-reader in our back room. She paid in advance. Mum's never been so suspicious."],
		["s_maera&!s_return&sparks>=2", "{sparks} sparks! The inn's started a song about you. It doesn't rhyme. They tried."],
		["s_return&!s_kindling", "Kindling Night! I've been saving this dress for a hundred years. Well. My gran has."],
		["s_kindling&!s_ending", "The Lamplighter? He lit our street every night for thirty years. I used to wave."],
		["s_ending", "Hearth-Champion! Can I touch the Lantern? Just once? I won't tell my gran."],
	],
	"tovik": [
		["!s_maera", "Forge is cold. First time in my life. Feels like the town's holding its breath."],
		["s_maera&!s_return&!got_halvard", "Old Halvard up in Coalvein? Taught my master. Threw a hammer at the king's tax man. Missed. On purpose, he says."],
		["s_maera&!s_return&got_halvard", "You brought Halvard down from the hills? Alive? And he came? Saints."],
		["s_return&!s_kindling", "Forge is hot again. I'm making horseshoes for the parade. Lucky ones."],
		["s_kindling&!s_ending", "Whatever's down that Bastion, ser, I made your gate bolts. They'll hold. Probably."],
		["s_ending", "Smith's guild wants a statue of you. I said bronze. Halvard said rust. We compromised on rust."],
	],
	"ismer": [
		["!s_maera", "Nine Kindlings in the chronicle, and never once did all four fires fail. I'm writing this down. Shakily."],
		["s_maera&!s_return", "The first Lamplighter swore an oath to 'keep the old king sleeping.' Odd phrase. I've always wondered which king."],
		["s_return&!s_kindling", "Tonight's the tenth Kindling. Every one before it ended with a feast. I've brought a large spoon."],
		["s_kindling&!s_ending", "A lid. The throne was a lid. Nine kings, and none of them read the footnotes."],
		["s_ending", "Chapter ten: the Barrow-Knight. I've left a space for the toast. Please make it shorter this time."],
	],
	"twen": [
		["!s_maera", "Cows won't go near the east ruin. Never would. Now the sheep won't either. Sheep go anywhere."],
		["s_maera&!s_return", "Saw lights on the Drowned Steps last night. Pale ones. Under the water. I'm not drinking any more. Starting now."],
		["s_return&!s_kindling", "Kindling Night! Brought my best goat for the parade. Ser Caldric's met her. He won't say."],
		["s_kindling&!s_ending", "That ruin's been humming all night. The goat's hiding in the chapel."],
		["s_ending", "Sheep are back to grazing by the ruin. Goat's still in the chapel. She likes it there."],
	],
	"joryn": [
		["!s_maera", "Ember buns! Half price! On account of the end of the world!"],
		["s_maera&!s_return", "Kindling Hunt buns! Caldric bought six for luck. Fell off his horse. I don't think they're lucky."],
		["s_return&!s_kindling", "Baking all day for tonight! Taren ordered three dozen. Paid in exact change. Every coin."],
		["s_kindling&!s_ending", "Can't sell a bun with that thing humming under the town. I'm eating them myself. For morale."],
		["s_ending", "Hearth-Champion buns! Same buns, new name, double price!"],
	],
	"vellin": [
		["!s_prologue", "Ser Bramwell! Over here, ser! Please!"],
		["s_prologue&!s_king", "North, ser! The castle!"],
		["s_king&!s_return", "Safe roads, ser! Mind the Danger meter!"],
		["s_return&!s_kindling", "Kindling Night, ser! I polished my helmet. Twice."],
		["s_kindling&!s_ending", "Nothing gets past this gate, ser. Except you. Obviously."],
		["s_ending", "Hearth-Champion! Ser! Sir! Ser!"],
	],
	"drosk": [
		["!s_kindling&!sq_book_bet", "Kindling Hunt book's open! Caldric two to one! Long shots welcome!"],
		["!s_kindling&sq_book_bet", "Look who's backing themselves! Odds are shortening, champion!"],
		["s_kindling&!s_ending", "New book: will the town still be here at dawn? I'm taking 'yes' at evens. Bravely."],
		["s_ending", "Never again. Never again. ...Next Kindling, though."],
	],
}

## Epilogue cards (shown in order by the ending screen). Each: [cond, title, text].
const EPILOGUE := [
	["end_throne", "The Tenth Kindling", "You set the Heart-Coal back in the Ember Throne. It catches, and the whole castle glows. Emberhold is safe for another hundred years, and the lid holds. King Orlan never sits on it again."],
	["end_hearth&loyal>=3", "A Hearth of Five", "You break the Heart-Coal into four and carry one piece to each Wardfire. The Wardens stand their fires again, and for the first time Emberhold doesn't need a lid. It has a hearth. The last spark you light in the plaza, for everyone."],
	["end_hearth&loyal<3", "A Guttering Hearth", "You break the Heart-Coal among the four Wardfires, but not every Warden will stand their fire. The flames burn unevenly. Emberhold is safe for now, though no one knows for how long."],
	["loyal_grieve", "Grieve", "Grieve tends the Wardfire of Roots by day and sleeps beneath the willow by night. Properly, this time. He says it's the best sleep he's had in two deaths."],
	["!loyal_grieve", "Grieve", "Grieve keeps the Wardfire of Roots, but he never quite forgives the reliquary. Some nights he sits by the willow and talks to no one."],
	["loyal_halvard", "Halvard", "Halvard reforges the Forge Wardfire's grate with his own hands, and refuses a barony when the king offers one. 'Keep it. I've got an anvil.'"],
	["!loyal_halvard", "Halvard", "Halvard goes back to his anvil, and to his grudge. The Forge burns hot. Its keeper burns hotter."],
	["loyal_corvin", "Corvin", "With his heart his own, Corvin teaches the town's children dice and orbital mechanics. They mostly learn dice. He still owes Halvard forty crowns."],
	["!loyal_corvin", "Corvin", "Corvin's light never comes back to full. He sits at the Overlook most nights, rolling dice at the sky, waiting for a ship."],
	["loyal_ilsabet", "Ilsabet", "Queen Ilsabet rules an empty court beneath the waves, and visits Emberhold on every festival. She brings pearls. She refuses to kneel."],
	["!loyal_ilsabet", "Ilsabet", "Ilsabet keeps the Tide fire with her bound court around her, and she doesn't come ashore again."],
	["c5_spare", "Taren", "Taren lives. He takes up the lamplighter's pole again, this time for every street lamp in Emberhold, and he never takes a coin for it. Joryn still makes him pay for buns."],
	["c5_leave", "Taren", "Taren is never seen again. On still nights, people say a lamp burns at the bottom of the Bastion's stair that nobody lit."],
	["sq_fire_done", "Pell", "Pell's Kindling fireworks become a tradition. Every year, green, white, blue and gold. His eyebrows never fully recover."],
	["", "Ser Caldric", "Caldric holds the Bastion gate for a year and a day, then asks to join the Barrow Watch. It's quieter there, he says. Bramwell doesn't tell him otherwise."],
	["", "Bramwell", "And Ser Bramwell Tunn, Hearth-Champion, goes back to the Ember Inn and gives a toast that is still talked about. It rhymes."],
]
