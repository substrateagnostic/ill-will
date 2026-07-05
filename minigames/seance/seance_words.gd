class_name SeanceWords
extends RefCounted
## THE SÉANCE word deck. Each entry: the secret word the spirit is trying
## to spell, plus the Executor's clue — dry, immaculate, lethal. The clue is
## PUBLIC (all four hear it); the word itself is known only to the Executor
## and to the Charlatan. 5–7 letters, common enough to be guessable from the
## clue via hangman-style letter commits, estate-flavored throughout.
##
## Letter frequency note for bots: honest bots weight their blind guesses by
## LETTER_WEIGHT below (roughly English frequency), so their wrong guesses
## look like plausible human wrong guesses (E before Q), per the brief's
## "plausible letters with seeded noise".

const WORDS: Array = [
	{"word": "CANDLE", "clue": "Six letters. It weeps wax so that you may see."},
	{"word": "MIRROR", "clue": "Six letters. It shows you everything except yourself."},
	{"word": "COFFIN", "clue": "Six letters. The last bed you will ever need."},
	{"word": "POISON", "clue": "Six letters. The butler's seasoning of last resort."},
	{"word": "SHADOW", "clue": "Six letters. Your most loyal follower."},
	{"word": "WINTER", "clue": "Six letters. The season that buries the garden."},
	{"word": "LETTER", "clue": "Six letters. Sealed, it says nothing. Opened, far too much."},
	{"word": "SPIRIT", "clue": "Six letters. Present company included."},
	{"word": "BUTLER", "clue": "Six letters. He knows where everything is buried."},
	{"word": "ESTATE", "clue": "Six letters. You are standing in it. It is standing over you."},
	{"word": "DAGGER", "clue": "Six letters. The pen's more persuasive cousin."},
	{"word": "VELVET", "clue": "Six letters. The curtain's flesh."},
	{"word": "GRAVE", "clue": "Five letters. The estate's most permanent guest room."},
	{"word": "GHOST", "clue": "Five letters. A tenant who refuses to pay rent."},
	{"word": "CLOCK", "clue": "Five letters. It counts what you cannot keep."},
	{"word": "RAVEN", "clue": "Five letters. The garden's best-dressed mourner."},
	{"word": "WIDOW", "clue": "Five letters. The dress code is black."},
	{"word": "CURSE", "clue": "Five letters. A gift that keeps taking."},
	{"word": "CRYPT", "clue": "Five letters. Cold storage for the family line."},
	{"word": "WALTZ", "clue": "Five letters. A three-count argument between two people."},
	{"word": "PIANO", "clue": "Five letters. Eighty-eight teeth and it still will not bite."},
	{"word": "STORM", "clue": "Five letters. The sky settling a grudge."},
	{"word": "EMBER", "clue": "Five letters. The fire's last will."},
	{"word": "LANTERN", "clue": "Seven letters. A cage for a small, obedient flame."},
	{"word": "THEATER", "clue": "Seven letters. Where lies are applauded."},
	{"word": "FUNERAL", "clue": "Seven letters. The one party thrown in your honor that you must not attend."},
	{"word": "LOCKET", "clue": "Six letters. A face you loved, kept under lock."},
	{"word": "ORCHARD", "clue": "Seven letters. Where the family tree drops its fruit."},
]

## Rough English letter plausibility for honest-bot blind guesses.
const LETTER_WEIGHT: Dictionary = {
	"E": 12.0, "T": 9.0, "A": 8.2, "O": 7.5, "I": 7.0, "N": 6.7, "S": 6.3,
	"H": 6.1, "R": 6.0, "D": 4.3, "L": 4.0, "C": 2.8, "U": 2.8, "M": 2.4,
	"W": 2.4, "F": 2.2, "G": 2.0, "Y": 2.0, "P": 1.9, "B": 1.5, "V": 1.0,
	"K": 0.8, "J": 0.15, "X": 0.15, "Q": 0.1, "Z": 0.07,
}

## Seeded pick. Consumes exactly one rng call so match setup stays
## deterministic per rng_seed regardless of deck size changes mid-branch.
static func pick(rng: RandomNumberGenerator) -> Dictionary:
	return WORDS[rng.randi_range(0, WORDS.size() - 1)]
