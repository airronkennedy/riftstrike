extends RefCounted
## Airron's Quest dialog (docs/STORY.md). Each node:
##   {"lines": [[speaker, text, cond?], ...], "choices": [{"t": text, "cond": "", "do": [actions], "next": id}],
##    "do": [actions run after the lines when there are no choices], "next": id}
## Speakers are StoryData.CAST ids. A line's optional third item is a condition (StoryData format).
## Actions: set:flag  clear:flag  recruit:id  loyal:id  battle:id  gold:N  item:id  heal  hurt:0.25  act:II
##   tip:id  toast:text  dungeon  exit_dungeon  ending  boss:id  sparks (shows the Lantern count)

const D := {
	# ------------------------------------------------------------------ Prologue
	"prologue": {"lines": [
		["vellin", "Ser Bramwell! Hold up! Halt! Please halt!"],
		["bramwell", "Vellin. If this is about the toast at the inn, it rhymed. Rhyming is legal."],
		["vellin", "It's not the toast, ser. It's the king. You're summoned to the castle. Now."],
		["vellin", "Something about the Kindling."],
		["bramwell", "The Kindling? That's not for another hundred years."],
		["vellin", "Three days, ser. It's in three days. Did nobody tell you?"],
		["bramwell", "I guard graves, Vellin. Nobody tells me anything. The graves certainly don't."],
		["vellin", "Castle's straight up the main road. Big gate. Can't miss it. Please don't stop at the inn."],
	], "do": ["set:s_prologue", "act:I", "tip:journal"]},
	"vellin_idle": {"lines": [
		["vellin", "North, ser! The castle! The king is a patient man, but not today.", "!s_king"],
		["vellin", "Off to the Wardfires? Mind the Danger meter out there. When it fills, something finds you.", "s_king&sparks<1"],
		["vellin", "Word is you've lit {sparks} of the four. The odds on you just got a lot shorter.", "sparks>=1&sparks<4"],
		["vellin", "All four sparks! I'll never doubt a barrow-knight again.", "sparks>=4"],
	]},
	"vellin_after": {"lines": [
		["vellin", "I saw the Matron fall from up on the wall. Ser... thank you.", "!s_ending"],
		["vellin", "The town's still singing your toast. The rhyming one.", "s_ending"],
	]},

	# ------------------------------------------------------------------ Act I: the king's event
	"king_early": {"lines": [["orlan", "Ser Bramwell? Vellin was meant to fetch you. Well, you found your own way. Come closer."]], "next": "king_audience"},
	"king_audience": {"lines": [
		["narr", "The throne room smells of old smoke. The coals of the Ember Throne have burned for nine kings. Tonight they barely glow."],
		["orlan", "Ser Bramwell Tunn, Knight of the Barrow Watch. Do you know why I sent for you?"],
		["bramwell", "If it's the toast at the inn, Majesty, I can explain. It rhymed."],
		["orlan", "It did rhyme. No. Three nights ago, all four Wardfires on Cinderreach went dark at once. Roots, Forge, Star and Tide."],
		["taren", "And their Wardens have not come home. Without their sparks the throne will not take the Kindling, and the Ash walks in."],
		["orlan", "Taren Unlit, my Lamplighter. He has tended these coals for thirty years. If he says it is grave, it is grave."],
		["orlan", "But a frightened town is worse than a dark one. So we shall make it a festival!"],
		["orlan", "I proclaim the Kindling Hunt! Whoever brings home all four sparks before Kindling Night will be named Hearth-Champion, and will light the throne before the whole town!"],
		["caldric", "Then it's settled. I'll have them by supper, Majesty."],
		["caldric", "Barrow Watch, was it? Do try not to get lost out there. The graves would miss you."],
		["narr", "Ser Caldric Morn, Knight of the Cinder Gate, sweeps out of the hall. His cape is very good."],
		["orlan", "Every champion needs a lantern. Here: the Kindling Lantern. It holds a spark, and it never burns the hand that carries it."],
		["orlan", "Now. How will you take my charge, Ser Bramwell?"],
	], "choices": [
		{"t": "Swear the Oath. For Emberhold.", "do": ["set:c1_oath", "item:warden_mail"], "next": "king_oath"},
		{"t": "Name my price. Heroes eat too.", "do": ["set:c1_price", "gold:200"], "next": "king_price"},
	]},
	"king_oath": {"lines": [
		["orlan", "Then kneel... and rise, Ser Bramwell, Sworn of the Kindling. Carry my Writ. The armory sends Warden Mail with it."],
		["narr", "You received Warden Mail (it's in your bag; equip it from Build). The guards stand a little straighter as you pass."],
		["taren", "An oath. How very old-fashioned."],
	], "next": "king_end"},
	"king_price": {"lines": [
		["orlan", "Ha! Honest, at least. Two hundred gold now, and not one coin more until the throne is lit."],
		["narr", "You received 200 gold."],
		["taren", "Coin-sworn. How... practical."],
	], "next": "king_end"},
	"king_end": {"lines": [
		["taren", "Your aunt Maera tends the throne's coals with me. Speak with her before you go. She knows the old Wardfire roads."],
		["orlan", "Go with the Ember, Bramwell. And if you find my Wardens... bring them home."],
	], "do": ["set:s_king"]},
	"king_idle": {"lines": [
		["orlan", "The coals dim by the hour. Find the Wardfires, Bramwell.", "sparks<1"],
		["orlan", "{sparks} sparks in the Lantern! I can feel the throne warming already.", "sparks>=1&sparks<4"],
		["orlan", "Your Writ still stands, Sworn of the Kindling.", "c1_oath&sparks<4"],
		["orlan", "And I haven't forgotten your price, champion. A king pays his debts.", "c1_price&sparks<4"],
	]},
	"king_return": {"lines": [
		["orlan", "Four sparks! Bramwell, you've done it! Roots, Forge, Star and Tide, all in one lantern!"],
		["narr", "Ser Caldric staggers into the hall, singed, muddy and empty-handed."],
		["caldric", "I... got lost."],
		["taren", "Majesty, the Kindling must be done tonight, at the plaza, before the whole town. The throne will not last another day."],
		["orlan", "Then tonight it is! Hearth-Champion, meet us at the plaza before the castle gate."],
		["selka", "Bramwell. A word. The reliquary you brought me... it names the one who fed the Ash. It names the Lamplighter. I've told the guard captain. Be ready.", "reliquary_given"],
		["narr", "Selka presses a black iron key into your hand: the Reliquary Key. 'It was inside. It opens something under the ruin.'", "reliquary_given"],
		["selka", "The reliquary! There's no time to read it now. Keep it close tonight.", "c2_keep&!reliquary_given"],
	], "do": ["set:s_return", "act:III"]},
	"king_after": {"lines": [
		["orlan", "The throne is going cold, Bramwell. Taren is in the Sunken Bastion with the Heart-Coal. Bring back the light."],
	]},
	"king_final": {"lines": [
		["orlan", "Hearth-Champion. Whatever you chose down there, you chose it for all of us. Emberhold remembers."],
	]},
	"selka_early": {"lines": [["selka", "The Great Hall. West is the Hall of Keepers, east the Gallery of Banners. The king is on the throne, to the north."]]},
	"selka_idle": {"lines": [
		["selka", "Selka Orrery, royal armillary-scribe. I chart the sky and, lately, the dark."],
		["selka", "The Wardfires sit at the four corners of the isle: Gloamwood in the west, Coalvein Cave in the north, Cliff Overlook in the east, the Drowned Steps on the south shore."],
		["selka", "Open your journal (the Quests button) and it will point you to the next one."],
	]},
	"selka_reliquary": {"lines": [
		["selka", "Is that... a cultists' reliquary? From the Gloamwood? Give it here. Carefully."],
		["selka", "These are names. Prayers, payments, a ledger of who fed the Ash. It will take me some time to read them all."],
		["selka", "Come back when the sparks are home. I'll have answers by then."],
	], "do": ["set:reliquary_given", "toast:Gave the Black Reliquary to Selka"]},
	"selka_plaza": {"lines": [["selka", "Stay close to the king tonight. I have a bad feeling about the stars.", "!reliquary_given"], ["selka", "The guards are ready. Watch his hands.", "reliquary_given"]]},
	"selka_after": {"lines": [["selka", "The Ember Throne was never a throne, Bramwell. It was a lid. Go."]]},
	"selka_end": {"lines": [["selka", "The stars are where they should be again. I checked twice."]]},
	"taren_idle": {"lines": [
		["taren", "The Ember remembers every hand that ever fed it. Hurry, Ser Bramwell.", "sparks<2"],
		["taren", "{sparks} sparks already? You are... efficient.", "sparks>=2"],
	]},
	"taren_plaza": {"lines": [["taren", "Tonight, Hearth-Champion, everything changes. Speak to the king when you're ready."]]},
	"caldric_castle": {"lines": [
		["caldric", "Still here, Barrow Watch? I'll have two sparks by sunset.", "sparks<1"],
		["caldric", "One spark is luck. Don't let it go to your head.", "sparks>=1"],
	]},
	"caldric_shore": {"lines": [
		["caldric", "Barrow Watch. This is fine. I meant to be stuck in the sand. It's... strategy."],
		["caldric", "Two sparks? You? I... well done. Don't tell anyone I said that."],
	]},
	"caldric_plaza": {"lines": [["caldric", "Tonight's your night, Bramwell. I suppose. Try not to trip on the stage."]]},
	"caldric_gate": {"lines": [["caldric", "I'll hold the gate. Nothing gets out of that Bastion while I stand. Go."]]},
	"caldric_end": {"lines": [["caldric", "To the Hearth-Champion! Your round, Barrow Watch. The rhyming kind."]]},

	# ------------------------------------------------------------------ Maera
	"maera_early": {"lines": [["maera", "Shouldn't you be at the castle? Vellin's been running up and down the road all morning."]]},
	"maera_intro": {"lines": [
		["maera", "There's my barrow-knight! The king summoned you? Sit. No, don't sit, you'll get soot on everything."],
		["maera", "Four Wardfires, four Wardens. When the fires died the Wardens went... strange. A dead man, a stubborn one, a clockwork one and a queen."],
		["maera", "Gloamwood is closest. Start there. Then the cave in the north, the cliffs in the east and the sea in the south."],
		["maera", "Out past the walls the Ash walks. Watch your Danger meter, and when you're hurt, rest at the inn. Ten gold. I've told them to give you the good pillow."],
		["maera", "Every Warden you bring back fights at your side. Line them up well. Hits that land together hit harder."],
		["maera", "Here, drink this. Ember tonic. Don't ask what's in it."],
		["narr", "Your party is fully healed. Maera slips 30 gold into your pocket when she thinks you aren't looking."],
	], "do": ["heal", "gold:30", "set:s_maera", "act:II", "tip:danger"]},
	"maera_idle": {"lines": [
		["maera", "Gloamwood first, dear. West of the road.", "!got_grieve"],
		["maera", "{sparks} sparks! Your uncle would have toasted all night.", "sparks>=1"],
		["maera", "Taren and I have fed those coals side by side for thirty years. He hasn't smiled once. I've stopped counting.", "sparks>=3"],
	], "do": ["heal"], "after": "Maera's tonic heals the party."},
	"maera_late": {"lines": [["maera", "Taren? Thirty years beside me and I never... Go. Bring that coal home. And come home yourself."]], "do": ["heal"]},
	"maera_end": {"lines": [["maera", "My barrow-knight, Hearth-Champion. Now sit. You may get soot on everything."]], "do": ["heal"]},

	# ------------------------------------------------------------------ Act II: Grieve, Wardfire of Roots
	"grieve_meet": {"lines": [
		["narr", "Under the old willow, the earth heaves. A hand in a rusted gauntlet pushes up through the roots."],
		["grieve", "...Again? That's three. Somebody owes me a very long nap."],
		["bramwell", "Easy! Bramwell, Barrow Watch. Usually I make sure people stay down."],
		["grieve", "Then you're bad at your job. Grieve. Warden of Roots. Twice buried and, as of tonight, thrice annoyed."],
		["grieve", "The cultists who buried me left their reliquary in the Wardfire. It's choking the flame. And it brought friends."],
		["narr", "Gloam moths pour out of the roots, and something with far too many joints crawls after them."],
		["grieve", "Well, barrow-knight? Shall we bury something together?"],
	], "do": ["recruit:grieve", "battle:fight_grieve"]},
	"grieve_retry": {"lines": [["grieve", "Still standing? Good. The leaper's still twitching. Let's finish it."]], "do": ["battle:fight_grieve"]},
	"grieve_after": {"lines": [
		["narr", "The leaper falls apart into ash. The Wardfire of Roots flickers, wrapped around a black iron reliquary."],
		["grieve", "There it is. The thing that buried me. It hums with their prayers. Names, maybe. Plans."],
		["grieve", "Burn it, and I'll sleep easy when the time comes. Or carry it to someone clever. Your choice, knight. I'll sulk either way."],
	], "choices": [
		{"t": "Burn it. You've earned your rest.", "do": ["set:c2_burn", "loyal:grieve", "item:gravebell"], "next": "grieve_burn"},
		{"t": "Keep it. Selka in the castle can read it.", "do": ["set:c2_keep"], "next": "grieve_keep"},
	]},
	"grieve_burn": {"lines": [
		["narr", "The reliquary goes into the flame. The Wardfire roars, green and gold, and the willow's leaves shiver."],
		["grieve", "...Huh. Lighter. Here, take this bell. It rang at both my funerals. Let it ring for something better."],
		["narr", "Grieve is loyal. You received the Gravebell (an amulet, in your bag)."],
	], "next": "grieve_spark"},
	"grieve_keep": {"lines": [
		["grieve", "Clever people. It's always clever people."],
		["narr", "Grieve says nothing for a long while. The black reliquary is cold and heavy in your pack. Selka, in the castle, might be able to read it."],
	], "next": "grieve_spark"},
	"grieve_spark": {"lines": [
		["narr", "You raise the Kindling Lantern. A green-gold spark leaps inside: the Wardfire of Roots."],
		["grieve", "I'll come. Someone has to keep you from getting buried."],
	], "do": ["set:got_grieve", "sparks", "tip:order"]},

	# ------------------------------------------------------------------ Halvard, Wardfire of the Forge
	"halvard_meet": {"lines": [
		["narr", "Hammer blows ring out of Coalvein Cave, slow and stubborn. An old man in rust-red plate stands at its mouth with an anvil on his shoulder."],
		["halvard", "If the king sent you, turn around. A crown took my barony, my mines and my name. It can't have my anvil."],
		["halvard", "...Wait. You're the coin-sworn one. Taverns talk. A sellsword, not a leash. Hm.", "c1_price"],
		["halvard", "Sworn knight, eh? I can smell the Writ on you from here.", "c1_oath"],
		["bramwell", "The Forge Wardfire's out, Halvard. Without it the throne goes cold, and the Ash doesn't care about crowns."],
		["halvard", "No. It doesn't. Brutes crawled up out of the deep and sat on my fire like hens. Big ones."],
		["halvard", "Fine. I'll fight beside you. If you fall, I'm going back to my anvil."],
	], "do": ["recruit:halvard", "battle:fight_halvard"]},
	"halvard_retry": {"lines": [["halvard", "Back for more? The brutes didn't go anywhere. Neither did I."]], "do": ["battle:fight_halvard"]},
	"halvard_after": {"lines": [
		["narr", "Deep in the cave, the Forge Wardfire roars back to life, white-hot."],
		["halvard", "Not bad for a hired blade. Take my pledge-hammer. It's never struck a crown. Yet.", "c1_price"],
		["narr", "Halvard is loyal. You received the Rust Baron's Pledge (a weapon, in your bag).", "c1_price"],
		["halvard", "You fight well, for a king's dog. I'll come. For the fire. Not for him.", "c1_oath"],
		["narr", "A white spark leaps into the Lantern: the Wardfire of the Forge."],
	], "do": ["loyal:halvard?c1_price", "item:rust_pledge?c1_price", "set:got_halvard", "sparks"]},

	# ------------------------------------------------------------------ Corvin, Wardfire of the Star
	"corvin_meet": {"lines": [
		["narr", "At the cliff edge a brass figure sits with its legs over the drop, rolling dice on the stone. A light pulses in its chest, slow and tired."],
		["corvin", "Snake eyes. Again. Do you know the odds of that eleven times in a row? I do. I worked them out on the way down."],
		["bramwell", "On the way down from where?"],
		["corvin", "Up there. Low orbit. I was a duelist on a ship that doesn't exist any more. Corvin Brass, at your service, and losing."],
		["corvin", "You're here for the Star Wardfire. Bad news: it's me. The fallen star they built that fire around is what keeps my gears turning."],
		["corvin", "You could take a spark from my heart. I'd live. Dimmer. Slower. Or you could crack open a Reliquary Engine on the strand. They carry stolen starlight."],
		["corvin", "They also carry very large hammers."],
	], "choices": [
		{"t": "I'll take the spark from your heart.", "do": ["set:c3_heart"], "next": "corvin_heart"},
		{"t": "Keep your heart. We hunt the Engine.", "do": ["set:c3_hunt", "recruit:corvin"], "next": "corvin_hunt"},
	]},
	"corvin_heart": {"lines": [
		["corvin", "...Right. Steady hands, please."],
		["narr", "You open the Lantern. A blue spark drifts out of Corvin's chest, and his light sinks to an ember."],
		["corvin", "Still ticking. I'll tag along anyway. Somebody has to keep score."],
	], "do": ["recruit:corvin", "set:got_corvin", "sparks"]},
	"corvin_hunt": {"lines": [["corvin", "Ha! I like you. Terrible odds. Let's go lose spectacularly."]], "do": ["battle:fight_engine"]},
	"corvin_retry": {"lines": [["corvin", "Round two? I've recalculated. Our odds are now merely bad."]], "do": ["battle:fight_engine"]},
	"corvin_hunt_after": {"lines": [
		["narr", "The Engine's core cracks open, and stolen starlight pours into the Lantern."],
		["corvin", "Look at that. My heart's still mine. Here, take the dice. They're loaded, but only in your favor."],
		["narr", "Corvin is loyal. You received the Loaded Dice (gloves, in your bag)."],
	], "do": ["loyal:corvin", "item:loaded_dice", "set:got_corvin", "sparks"]},

	# ------------------------------------------------------------------ Ilsabet, Wardfire of the Tide
	"ilsabet_meet": {"lines": [
		["narr", "At the Drowned Steps the tide has gone out much too far. A woman in a crown of wet pearls stands where the water ought to be."],
		["ilsabet", "Kneel or don't. I gave up insisting a century ago."],
		["ilsabet", "...You carry a king's Writ. An oath-keeper. How rare. I had a whole court of them, once.", "c1_oath"],
		["ilsabet", "I am Ilsabet, Queen of the Drowned Court. My court sleeps beneath this water. Slept. The Cardinal woke them."],
		["ilsabet", "The Drowned Cardinal. My own priest. He put out the Tide fire so the court would serve him instead."],
		["ilsabet", "Help me take back my throne, knight, and the Tide's spark is yours."],
	], "do": ["recruit:ilsabet", "battle:fight_cardinal"]},
	"ilsabet_retry": {"lines": [["ilsabet", "He's still down there, wearing my court like a cloak. Again, knight."]], "do": ["battle:fight_cardinal"]},
	"ilsabet_after": {"lines": [
		["narr", "The Cardinal sinks. The tide rushes back in, full of pale lights: the souls of the drowned court."],
		["ilsabet", "They're free... and lost. I can let the tide carry them home to rest."],
		["ilsabet", "Or you can bind them to the Tide fire. Bound, they would fight for the Lantern wherever you go next."],
	], "choices": [
		{"t": "Let the tide take them home.", "do": ["set:c4_rest", "loyal:ilsabet", "item:tideglass"], "next": "ilsabet_rest"},
		{"t": "Bind them. We'll need every blade.", "do": ["set:c4_bind"], "next": "ilsabet_bind"},
	]},
	"ilsabet_rest": {"lines": [
		["ilsabet", "Go gently, all of you."],
		["narr", "The lights sink into the sea one by one. Ilsabet watches until the last one is gone."],
		["ilsabet", "Take this pearl from my crown. A queen pays her debts. And I will follow you, knight. Gladly."],
		["narr", "Ilsabet is loyal. You received the Tideglass Shard (an amulet, in your bag)."],
	], "next": "ilsabet_spark"},
	"ilsabet_bind": {"lines": [
		["ilsabet", "...As you command."],
		["narr", "The pale lights coil into the Tide fire and turn to follow the Lantern. Ilsabet does not look at you."],
		["ilsabet", "They will fight for you now. So will I. Don't mistake it for anything more."],
	], "next": "ilsabet_spark"},
	"ilsabet_spark": {"lines": [["narr", "A sea-green spark leaps into the Lantern: the Wardfire of the Tide."]], "do": ["set:got_ilsabet", "sparks"]},

	# ------------------------------------------------------------------ Spots
	"forest_look": {"lines": [["narr", "Gloamwood Heart. The oldest tree on the isle hums with a low ember light, and the ground at its roots looks freshly turned."]]},
	"forest_after": {"lines": [["narr", "The Wardfire of Roots burns green and gold among the willow roots.", "c2_burn"], ["narr", "The Wardfire of Roots burns, but the place where the reliquary sat is still cold.", "c2_keep"]]},
	"cave_look": {"lines": [["narr", "Coalvein Cave. Warm air breathes out of the dark, along with the sound of a hammer."]]},
	"cave_after": {"lines": [["narr", "Down in the deep forge the Wardfire burns white-hot again."]]},
	"overlook_look": {"lines": [["narr", "Cliff Overlook. The whole of Cinderreach below, and nothing but sea beyond. Someone has been rolling dice on the cairn."]]},
	"overlook_after": {"lines": [["narr", "The star-scar on the cliff glows faintly blue."]]},
	"steps_look": {"lines": [["narr", "The Drowned Steps lead down into the sea. The water is too low, and the steps are too clean."]]},
	"steps_after": {"lines": [["narr", "The tide is back where it belongs, lapping over the steps.", "c4_rest"], ["narr", "Pale lights drift under the water, waiting for the Lantern.", "c4_bind"]]},
	"ruin_sealed": {"lines": [["narr", "The Sunken Bastion: a fallen keep. An old seal of hammered bronze covers the stair down. It's warm to the touch."]]},
	"ruin_after": {"lines": [["narr", "The Bastion's stair is quiet now. Nothing climbs it any more."]]},
	"shrine_pray": {"lines": [["narr", "Votive Shrine. You feel the danger in the air settle."]], "do": ["calm"]},

	# ------------------------------------------------------------------ Side quests
	"pell_idle": {"lines": [["pell", "The store buys anything you can carry. Mostly. Me, I only buy powder."]]},
	"pell_offer": {"lines": [
		["pell", "Bramwell! Disaster! My festival fireworks. Three crates. They fell off the cart on the way back from the Tarfen."],
		["pell", "One's in the north meadow, one by the east shore and one down on the south-west strand. Bring them back and I'll make the sky sing on Kindling Night."],
	], "do": ["set:sq_fire_on", "toast:New side quest: Pell's Lost Fireworks"]},
	"pell_wait": {"lines": [["pell", "Found my crates? Don't shake them. Please don't shake them."]]},
	"pell_turnin": {"lines": [
		["pell", "All three! Not even singed! You beautiful barrow-knight."],
		["pell", "Here's 120 gold, and on Kindling Night watch the sky. Green, white, blue and gold, one for each Wardfire."],
	], "do": ["gold:120", "set:sq_fire_done", "toast:Side quest complete: Pell's Lost Fireworks"]},
	"pell_after": {"lines": [["pell", "Best show I ever lit. Shame about the giant ash monster.", "sq_fire_done"], ["pell", "Next Kindling I'm packing the crates myself.", "!sq_fire_done"]]},
	"crate_1": {"lines": [["narr", "A crate stamped PELL - DO NOT DROP. You pick it up very carefully."]], "do": ["set:crate_1", "crates"]},
	"crate_2": {"lines": [["narr", "A crate stamped PELL - THIS SIDE UP. It is upside down. You fix that."]], "do": ["set:crate_2", "crates"]},
	"crate_3": {"lines": [["narr", "A crate stamped PELL - NO, REALLY. Something inside fizzes politely."]], "do": ["set:crate_3", "crates"]},
	"wenna_idle": {"lines": [["wenna", "Danger stirs once you leave the walls. Watch the ember meter, and come back to the inn when you're hurt."]]},
	"wenna_offer": {"lines": [
		["wenna", "Ser Bramwell, a moment. The bell at the Votive Shrine has rung by itself every night since the fires died. Something answers it."],
		["wenna", "Would you ring it once, properly, and quiet whatever comes? It's west of the King's Road, past the gate."],
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
	"bell_after": {"lines": [["narr", "The Knellbearer drops its bell and crumbles. The shrine falls silent."]], "do": ["set:bell_rung"]},
	"drosk_idle": {"lines": [
		["drosk", "Drosk Coinwright: odds, ends and mostly odds.", "!s_king"],
		["drosk", "Your bet's safe with me. Mostly safe. Safe-ish.", "sq_book_bet&!s_kindling"],
		["drosk", "Pleasure doing business, champion. Come back next Kindling.", "sq_book_paid"],
		["drosk", "The book's closed. You should've bet on yourself.", "!sq_book_bet&s_kindling"],
	]},
	"drosk_offer": {"lines": [
		["drosk", "The Kindling Hunt book is open! Ser Caldric's the favourite at 2 to 1. You... are 40 to 1."],
		["drosk", "Fancy a flutter on yourself? Fifty gold. I'll pay four to one. For the health of the house."],
	], "choices": [
		{"t": "Fifty gold on me.", "cond": "gold>=50", "do": ["gold:-50", "set:sq_book_bet", "toast:New side quest: Drosk's Book"], "next": "drosk_bet"},
		{"t": "Not today.", "next": ""},
	]},
	"drosk_bet": {"lines": [["drosk", "Ha! A champion with confidence. Collect after Kindling Night, if you're alive. No refunds for dead."]]},
	"drosk_payout": {"lines": [
		["drosk", "Hearth-Champion! You've ruined me. Two hundred gold, as promised. I'm moving to the mainland."],
	], "do": ["gold:200", "set:sq_book_paid", "toast:Side quest complete: Drosk's Book"]},
	"joryn_idle": {"lines": [["joryn", "Fresh from the stall! Well, fresh-ish."]]},
	"joryn_hunt": {"lines": [
		["joryn", "Ember buns! Kindling Hunt special! Caldric bought six and fell off his horse.", "sparks<2"],
		["joryn", "They're saying you've got {sparks} sparks. Have a bun. On the house. It's a bit stale.", "sparks>=2"],
	]},
	"joryn_after": {"lines": [["joryn", "The Lamplighter bought a bun from me every morning for thirty years. Paid in exact change. I should've known."]]},
	"joryn_end": {"lines": [["joryn", "Hearth-Champion buns! Same buns. New name. Double price."]]},

	# ------------------------------------------------------------------ Act III: Kindling Night (mini-boss)
	"kindling": {"lines": [
		["narr", "Night falls on Emberhold. There are lanterns on every sill, and the whole town has squeezed into the plaza."],
		["narr", "Pell's fireworks crack overhead: green, white, blue and gold. The crowd roars.", "sq_fire_done"],
		["orlan", "People of Emberhold! Tonight, the tenth Kindling! Ser Bramwell, Hearth-Champion, bring forth the sparks!"],
		["narr", "You open the Lantern. Four sparks rise into the night: Roots, Forge, Star and Tide."],
		["taren", "Allow me, Majesty. I have fed this flame for thirty years."],
		["bramwell", "Not one step closer, Taren. The reliquary from the Gloamwood. It had your name in it.", "reliquary_given"],
		["taren", "...Clever scribe. It hardly matters now.", "reliquary_given"],
		["narr", "Guards close in around the king, ready, just as Selka warned them.", "reliquary_given"],
		["taren", "Thirty years feeding a fire whose only purpose is to keep the old king asleep. No more."],
		["narr", "Taren closes his fist around the four sparks. Every brazier on the plaza goes black at once."],
		["narr", "Something huge drags itself up out of the ash in the square."],
		["taren", "Meet the Matron of Cinders. She's very motherly. Goodbye, Hearth-Champion."],
		["matron", "Hush now, little embers. Mother is here."],
	], "do": ["battle:miniboss_matron"]},
	"kindling_lose": {"lines": [
		["narr", "The Matron's heat drives you back, but the guards drag the party clear. She's still in the square, waiting."],
		["selka", "Regroup, Bramwell. Change your Attack Order, get stronger if you must. We'll hold her here. Talk to the king when you're ready."],
	], "do": ["heal"]},
	"matron_after": {"lines": [
		["narr", "The Matron collapses into a drift of cinders, and the braziers flicker back to life."],
		["narr", "Taren is gone. So is the Heart-Coal, the throne's last ember, torn from the castle while you fought."],
		["orlan", "He's taken the Heart-Coal into the Sunken Bastion. The old seal is broken. Without that coal the throne dies by dawn."],
		["selka", "The Bastion was built over something. The Ash Sovereign. The Ember Throne was never a throne, Majesty. It was a lid."],
		["caldric", "Ser Bramwell. I... was wrong about you. Let me hold the gate while you go down. Please."],
		["orlan", "Go, Hearth-Champion. The ruin east of the town. Bring back the light."],
	], "do": ["set:s_kindling", "boss:miniboss_matron", "act:IV"]},

	# ------------------------------------------------------------------ Act IV: the Sunken Bastion
	"bastion_enter": {"lines": [
		["narr", "The bronze seal lies cracked in two. Stairs, slick with ash, spiral down into the dark under the ruin."],
		["narr", "Caldric's torch burns at the top of the stair behind you."],
	], "choices": [
		{"t": "Descend into the Bastion.", "do": ["set:s_bastion", "dungeon"], "next": ""},
		{"t": "Not yet.", "next": ""},
	]},
	"f1_enter": {"lines": [
		["narr", "The Drowned Gate. Black water stands ankle deep across the hall. Something with a ledger and a scythe waits at the far door."],
		["narr", "The Reliquary Key turns in a side door you would never have seen. The guardian never even looks up.", "c2_keep&reliquary_given"],
	]},
	"f1_skip": {"lines": [["narr", "You slip through the side door with the Reliquary Key and leave the Drowned Gate's guardian behind."]], "do": ["set:bastion_f1"]},
	"f1_after": {"lines": [["narr", "The Tithe Collector drops its ledger. The way down to the Reliquary Halls is open."]]},
	"f2_enter": {"lines": [
		["narr", "The Reliquary Halls. Bells hang from every arch, and a Knellbearer paces among them."],
	]},
	"f2_bind": {"lines": [
		["narr", "The Lantern flares sea-green. The drowned court pours out of it, a cold tide of pale lights."],
		["narr", "They wash over the Knellbearer, and when the water drains away there's nothing left but a bell."],
		["ilsabet", "...They did that for you. Remember it."],
	], "do": ["set:bastion_f2", "boss:guardian_f2"]},
	"f2_after": {"lines": [["narr", "The last bell stops swinging. Below, something breathes."]]},
	"final_confront": {"lines": [
		["narr", "At the bottom of the Bastion stands a throne of black glass. On it sits something that used to be a man."],
		["taren", "You came. Of course you did. Heroes always come down the stairs."],
		["taren", "The Regnant promised me a fire that never needs feeding. All it wants in return is to be let out."],
		["bramwell", "Taren, that thing is using you."],
		["taren", "Everyone uses everyone, barrow-knight. Ask your Wardens."],
		["grieve", "Some of us chose to be here, Lamplighter.", "loyal_grieve"],
		["ilsabet", "He has a point, knight.", "c4_bind"],
		["corvin", "Odds are he's wrong. I'm rarely wrong about odds.", "loyal_corvin"],
		["narr", "The Unlit Regnant rises behind the throne, and Taren's shadow goes with it."],
		["regnant", "LITTLE LAMPLIGHTER. YOU BROUGHT ME GUESTS."],
	], "do": ["battle:boss_regnant"]},
	"regnant_after": {"lines": [
		["narr", "The Regnant shatters like black glass. Taren falls to his knees with the Heart-Coal glowing in his hands... and the floor splits open."],
		["narr", "Far below, something vast opens one grey eye: the Ash Sovereign."],
		["taren", "It's waking... I can't hold it... take the coal! Take it and run!"],
		["narr", "The dark reaches up out of the crack for Taren."],
	], "choices": [
		{"t": "Pull Taren out. (The dark will burn you.)", "do": ["set:c5_spare", "hurt:0.25"], "next": "taren_spare"},
		{"t": "Leave him to the dark.", "do": ["set:c5_leave"], "next": "taren_leave"},
	]},
	"taren_spare": {"lines": [
		["narr", "You grab his wrist. The dark burns like cold fire, but the party hauls him clear."],
		["taren", "Why...?"],
		["bramwell", "Because somebody has to tend the fire afterwards. Get behind us."],
	], "next": "sovereign_intro"},
	"taren_leave": {"lines": [["narr", "The dark closes over Taren without a sound. The Heart-Coal rolls to your feet."]], "next": "sovereign_intro"},
	"sovereign_intro": {"lines": [
		["narr", "The Ash Sovereign climbs out of the crack, crowned in the grey of every fire that ever went out."],
		["sovereign", "NINE KINGS. ONE LID. AND NOW... A BARROW-KNIGHT."],
		["halvard", "Swing first. Worry later.", "r_halvard"],
		["bramwell", "Everyone. Together. Now!"],
	], "do": ["battle:boss_sovereign"]},
	"sovereign_after": {"lines": [
		["narr", "The Sovereign comes apart like a burned-out log, and the Bastion goes quiet."],
		["narr", "The Heart-Coal is warm in your hand. Up above, the Ember Throne is going cold."],
		["narr", "You could return it to the throne, and keep the old lid for another hundred years. Or you could break it among the four Wardfires and trust the Wardens to stand their fires.", ""],
		["narr", "(The Wardens who stand by you: {loyal} of 4.)"],
	], "choices": [
		{"t": "Return the Heart-Coal to the Ember Throne.", "do": ["set:end_throne", "ending"], "next": ""},
		{"t": "Share it among the four Wardfires.", "do": ["set:end_hearth", "ending"], "next": ""},
	]},
	"lose_generic": {"lines": [
		["narr", "You were driven back. The party regroups, bruised but alive."],
		["narr", "Tip: win wild battles to level up, set your Attack Order in Build so hits land together, then try again."],
	], "do": ["heal"]},
	"lose_bastion": {"lines": [["narr", "The guardian drives you back up the stair. Caldric drags you the last few steps. Rest, regroup, and go down again."]], "do": ["heal"]},
	"lose_final": {"lines": [
		["narr", "The dark throws you back up the stair. Caldric catches you at the top."],
		["caldric", "Breathe. It's still down there. So is the coal. We go again when you're ready."],
	], "do": ["heal"]},
}

## Epilogue cards (shown in order by the ending screen). Each: [cond, title, text].
const EPILOGUE := [
	["end_throne", "The Tenth Kindling", "You set the Heart-Coal back in the Ember Throne. It catches, and the whole castle glows. Emberhold is safe for another hundred years, and the lid holds."],
	["end_hearth&loyal>=3", "A Hearth of Five", "You break the Heart-Coal into four and carry one piece to each Wardfire. The Wardens stand their fires again, and for the first time Emberhold doesn't need a lid. It has a hearth. The last spark you light in the plaza, for everyone."],
	["end_hearth&loyal<3", "A Guttering Hearth", "You break the Heart-Coal among the four Wardfires, but not every Warden will stand their fire. The flames burn unevenly. Emberhold is safe for now, though no one knows for how long."],
	["loyal_grieve", "Grieve", "Grieve tends the Wardfire of Roots by day and sleeps beneath the willow by night. Properly, this time. He says it's the best sleep he's had in two deaths."],
	["!loyal_grieve", "Grieve", "Grieve keeps the Wardfire of Roots, but he never quite forgives the reliquary. Some nights he sits by the willow and talks to no one."],
	["loyal_halvard", "Halvard", "Halvard reforges the Forge Wardfire's grate with his own hands, and refuses a barony when the king offers one. 'Keep it. I've got an anvil.'"],
	["!loyal_halvard", "Halvard", "Halvard goes back to his anvil, and to his grudge. The Forge burns hot. Its keeper burns hotter."],
	["loyal_corvin", "Corvin", "With his heart his own, Corvin teaches the town's children dice and orbital mechanics. They mostly learn dice."],
	["!loyal_corvin", "Corvin", "Corvin's light never comes back to full. He sits at the Overlook most nights, rolling dice at the sky, waiting for a ship."],
	["loyal_ilsabet", "Ilsabet", "Queen Ilsabet rules an empty court beneath the waves, and visits Emberhold on every festival. She brings pearls. She refuses to kneel."],
	["!loyal_ilsabet", "Ilsabet", "Ilsabet keeps the Tide fire with her bound court around her, and she doesn't come ashore again."],
	["c5_spare", "Taren", "Taren lives. He takes up the lamplighter's pole again, this time for every street lamp in Emberhold, and he never takes a coin for it."],
	["c5_leave", "Taren", "Taren is never seen again. On still nights, people say a lamp burns at the bottom of the Bastion's stair that nobody lit."],
	["sq_fire_done", "Pell", "Pell's Kindling fireworks become a tradition. Every year, green, white, blue and gold."],
	["", "Ser Caldric", "Caldric holds the Bastion gate for a year and a day, then asks to join the Barrow Watch. It's quieter there, he says. Bramwell doesn't tell him otherwise."],
	["", "Bramwell", "And Ser Bramwell Tunn, Hearth-Champion, goes back to the Ember Inn and gives a toast that is still talked about. It rhymes."],
]
