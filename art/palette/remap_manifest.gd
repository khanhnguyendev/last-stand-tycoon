class_name RemapManifest
extends RefCounted
## Which source atlas feeds which remapped atlas (D-188). overrides: lowercase source hex -> Palette name.
## tools/palette_remap.gd writes every `out`. Per-asset variants: the Barbarian apron (Task 7b); the guard swaps and the six
## muted traveler atlases (Task 8) are rule-based entries ("guard_swap", "tone"), expanded into hex overrides by `_build()`.

## The Barbarian atlas has two identical vertical blue gradients (x 0..127 = the torso, x 128..255 = the sleeves, rows
## 256..511), so no colour override can tell them apart. Both sets name the same 142 source hexes: the default atlas
## turns the gradient into cloth_blue (the sleeves), the apron variant into apron_white. hero_visual.tscn puts the apron
## material on Barbarian_Body only (S4 Task 7b, D-191).
## The platformer coin's rim and emboss hexes (orange, source ff9f38..d07c57) would land on skin_mid (pink); they go to
## gold_dark so a stack of coins reads gold (S4 Task 10 review). Only coin-gold.glb uses this atlas.
const COIN_RIM_TO_GOLD := {
	"ff9f38": "gold", "ff9832": "gold", "ffa139": "gold", "e48c63": "gold", "ea9168": "gold",
	"e08861": "gold", "dc855e": "gold", "d07c57": "gold",
}

## The Restaurant Bits fridge body is a teal-green gradient (source r < 0x50, g > 0x70, g >= b; 180 hexes) that remapped to a
## grass-like green on the grass (S4 Task 11). It is used by fridge_A only (the counter, stove, menu, pan and knife sample
## no hex in this set), so the whole atlas maps it to ice_blue and the Freezer reads as a freezer (ART_BIBLE §2).
const FRIDGE_TEAL_TO_ICE := {
	"09716b": "ice_blue", "09716c": "ice_blue", "09726c": "ice_blue", "0a736d": "ice_blue", "0a746d": "ice_blue",
	"0a746e": "ice_blue", "0b756e": "ice_blue", "0b766e": "ice_blue", "0b776f": "ice_blue", "0c776f": "ice_blue",
	"0c786f": "ice_blue", "0c7870": "ice_blue", "0c7970": "ice_blue", "0d7970": "ice_blue", "0d7a71": "ice_blue",
	"0d7b71": "ice_blue", "0e7b72": "ice_blue", "0e7c72": "ice_blue", "0e7d72": "ice_blue", "0e7d73": "ice_blue",
	"0f7e73": "ice_blue", "0f7f74": "ice_blue", "107f74": "ice_blue", "108074": "ice_blue", "108175": "ice_blue",
	"118175": "ice_blue", "118275": "ice_blue", "118276": "ice_blue", "118376": "ice_blue", "128476": "ice_blue",
	"128477": "ice_blue", "128577": "ice_blue", "138678": "ice_blue", "138778": "ice_blue", "138779": "ice_blue",
	"148879": "ice_blue", "148979": "ice_blue", "14897a": "ice_blue", "158a7a": "ice_blue", "158b7a": "ice_blue",
	"158b7b": "ice_blue", "158c7b": "ice_blue", "168c7b": "ice_blue", "168d7c": "ice_blue", "178e7c": "ice_blue",
	"178e7d": "ice_blue", "178f7d": "ice_blue", "18907e": "ice_blue", "18917e": "ice_blue", "18927e": "ice_blue",
	"19927f": "ice_blue", "19937f": "ice_blue", "199480": "ice_blue", "1a9480": "ice_blue", "1a9580": "ice_blue",
	"1a9581": "ice_blue", "1a9681": "ice_blue", "1b9681": "ice_blue", "1b9782": "ice_blue", "1b9882": "ice_blue",
	"1c9883": "ice_blue", "1c9983": "ice_blue", "1c9a83": "ice_blue", "1c9a84": "ice_blue", "1d9b84": "ice_blue",
	"1d9c84": "ice_blue", "1e9c85": "ice_blue", "1e9d85": "ice_blue", "1e9e86": "ice_blue", "1f9e86": "ice_blue",
	"1f9f86": "ice_blue", "1f9f87": "ice_blue", "1fa087": "ice_blue", "20a187": "ice_blue", "20a188": "ice_blue",
	"20a288": "ice_blue", "21a389": "ice_blue", "21a489": "ice_blue", "22a58a": "ice_blue", "22a68a": "ice_blue",
	"22a68b": "ice_blue", "23a78b": "ice_blue", "23a88b": "ice_blue", "23a88c": "ice_blue", "23a98c": "ice_blue",
	"24a98c": "ice_blue", "24aa8d": "ice_blue", "24ab8d": "ice_blue", "25ab8e": "ice_blue", "25ac8e": "ice_blue",
	"26ad8e": "ice_blue", "26ad8f": "ice_blue", "26ae8f": "ice_blue", "26af8f": "ice_blue", "27af90": "ice_blue",
	"27b090": "ice_blue", "27b191": "ice_blue", "28b191": "ice_blue", "28b291": "ice_blue", "28b292": "ice_blue",
	"28b392": "ice_blue", "29b392": "ice_blue", "29b493": "ice_blue", "29b593": "ice_blue", "2ab594": "ice_blue",
	"2ab694": "ice_blue", "2ab794": "ice_blue", "2bb895": "ice_blue", "2bb995": "ice_blue", "2bb996": "ice_blue",
	"2cba96": "ice_blue", "2cbb97": "ice_blue", "2dbb97": "ice_blue", "2dbc97": "ice_blue", "2dbc98": "ice_blue",
	"2dbd98": "ice_blue", "2ebe98": "ice_blue", "2ebe99": "ice_blue", "2ebf99": "ice_blue", "2fc099": "ice_blue",
	"2fc09a": "ice_blue", "2fc19a": "ice_blue", "30c29b": "ice_blue", "30c39b": "ice_blue", "30c39c": "ice_blue",
	"31c49c": "ice_blue", "31c59c": "ice_blue", "31c59d": "ice_blue", "31c69d": "ice_blue", "32c69d": "ice_blue",
	"32c79e": "ice_blue", "32c89e": "ice_blue", "33c89e": "ice_blue", "33c99f": "ice_blue", "34ca9f": "ice_blue",
	"34caa0": "ice_blue", "34cba0": "ice_blue", "34cca0": "ice_blue", "35cca1": "ice_blue", "35cda1": "ice_blue",
	"35cea2": "ice_blue", "36cea2": "ice_blue", "36cfa2": "ice_blue", "36cfa3": "ice_blue", "36d0a3": "ice_blue",
	"37d0a3": "ice_blue", "37d1a4": "ice_blue", "37d2a4": "ice_blue", "38d3a4": "ice_blue", "38d3a5": "ice_blue",
	"38d4a5": "ice_blue", "39d5a6": "ice_blue", "39d6a6": "ice_blue", "39d6a7": "ice_blue", "3ad7a7": "ice_blue",
	"3ad8a8": "ice_blue", "3bd9a8": "ice_blue", "3bd9a9": "ice_blue", "3bdaa9": "ice_blue", "3cdba9": "ice_blue",
	"3cdcaa": "ice_blue", "3dddaa": "ice_blue", "3dddab": "ice_blue", "3ddeab": "ice_blue", "3edfac": "ice_blue",
	"3ee0ac": "ice_blue", "3ee0ad": "ice_blue", "3fe1ad": "ice_blue", "3fe2ad": "ice_blue", "3fe2ae": "ice_blue",
	"3fe3ae": "ice_blue", "40e3ae": "ice_blue", "40e4ae": "ice_blue", "40e4af": "ice_blue", "40e5af": "ice_blue",
	"41e5af": "ice_blue", "41e6b0": "ice_blue", "41e7b0": "ice_blue", "42e7b1": "ice_blue", "42e8b1": "ice_blue",
}

## The Fantasy Town roof-flat swatches (teal gradient, used by no other piece in assets/) read as water from the game
## camera; the diner roof becomes grey gravel. The parapet, walls and awning keep their colours (S4 Task 11 review).
const ROOF_TO_STONE := {"45a087": "stone", "61c3ae": "stone", "56b59e": "stone"}

## The city-kit awning samples a green gradient (every source hex that remapped to grass or grass_dark, plus the six flat
## stripe shades): g >= 0xa4 goes to diner_cream, the rest to diner_teal, so it reads as a striped awning. Only
## detail-awning-wide uses this atlas.
const AWNING_STRIPES := {
	"198268": "diner_teal", "1a8268": "diner_teal", "1a8368": "diner_teal", "1b8469": "diner_teal",
	"1c8569": "diner_teal", "1c856a": "diner_teal", "1d866a": "diner_teal", "1e866a": "diner_teal",
	"1e876a": "diner_teal", "1f886b": "diner_teal", "20896b": "diner_teal", "218a6c": "diner_teal",
	"228a6c": "diner_teal", "228b6c": "diner_teal", "238c6d": "diner_teal", "248d6d": "diner_teal",
	"258e6e": "diner_teal", "268f6e": "diner_teal", "27906e": "diner_teal", "27906f": "diner_teal",
	"28916f": "diner_teal", "299270": "diner_teal", "2a9370": "diner_teal", "2b9470": "diner_teal",
	"2b9471": "diner_teal", "2c9571": "diner_teal", "2d9671": "diner_teal", "2d9672": "diner_teal",
	"2e9772": "diner_teal", "2e9872": "diner_teal", "2f9873": "diner_teal", "309973": "diner_teal",
	"319a73": "diner_teal", "319a74": "diner_teal", "329b74": "diner_teal", "329c74": "diner_teal",
	"339c75": "diner_teal", "349d75": "diner_teal", "359e75": "diner_teal", "359e76": "diner_teal",
	"369f76": "diner_teal", "36a076": "diner_teal", "37a076": "diner_teal", "37a177": "diner_teal",
	"38a177": "diner_teal", "39a277": "diner_teal", "39a278": "diner_teal", "3aa378": "diner_teal",
	"3aa478": "diner_cream", "3ba478": "diner_cream", "3ba579": "diner_cream", "3ca579": "diner_cream",
	"3da679": "diner_cream", "3ea77a": "diner_cream", "3ea87a": "diner_cream", "3fa87a": "diner_cream",
	"3fa97b": "diner_cream", "40a97b": "diner_cream", "40aa7b": "diner_cream", "41aa7b": "diner_cream",
	"42ab7c": "diner_cream", "42ac7c": "diner_cream", "43ac7c": "diner_cream", "43ad7c": "diner_cream",
	"44ad7d": "diner_cream", "44ae7d": "diner_cream", "45ae7d": "diner_cream", "45af7e": "diner_cream",
	"46b07e": "diner_cream", "47b07e": "diner_cream", "47b17e": "diner_cream", "48b17f": "diner_cream",
	"48b27f": "diner_cream", "49b27f": "diner_cream", "49b37f": "diner_cream", "4ab480": "diner_cream",
	"4bb480": "diner_cream", "4bb580": "diner_cream", "4cb581": "diner_cream", "4cb681": "diner_cream",
	"4db681": "diner_cream", "4db781": "diner_cream", "4eb882": "diner_cream", "4fb982": "diner_cream",
	"50b982": "diner_cream", "50ba83": "diner_cream", "51ba83": "diner_cream", "51bb83": "diner_cream",
	"52bc84": "diner_cream", "53bd84": "diner_cream", "54bd84": "diner_cream", "54be85": "diner_cream",
	"55be85": "diner_cream", "55bf85": "diner_cream", "56c086": "diner_cream", "57c186": "diner_cream",
	"58c287": "diner_cream", "59c287": "diner_cream", "59c387": "diner_cream", "5ac487": "diner_cream",
	"5ac488": "diner_cream", "5bc588": "diner_cream", "5cc689": "diner_cream", "5dc689": "diner_cream",
	"5dc789": "diner_cream", "5ec889": "diner_cream", "5ec88a": "diner_cream", "5fc98a": "diner_cream",
	"60ca8a": "diner_cream", "60ca8b": "diner_cream", "61cb8b": "diner_cream", "c7e1fc": "diner_cream",
	"c8e1fc": "diner_cream", "c9e2fc": "diner_cream", "c9e3fd": "diner_cream", "cae3fd": "diner_cream",
	"d7d7e6": "diner_cream", "d8d8e6": "diner_cream", "d9d9e7": "diner_cream", "dadae7": "diner_cream",
	"dadae8": "diner_cream", "dbdbe8": "diner_cream", "dcdce9": "diner_cream", "dddde9": "diner_cream",
	"ddddea": "diner_cream", "dedeea": "diner_cream", "dfdfeb": "diner_cream", "e0e0eb": "diner_cream",
	"e1e1ec": "diner_cream", "e2e2ec": "diner_cream", "e2e2ed": "diner_cream", "e3e3ed": "diner_cream",
	"e4e4ee": "diner_cream", "e5e5ee": "diner_cream", "f8d7af": "diner_cream", "f8d7b0": "diner_cream",
	"f8d8b1": "diner_cream", "f9d8b1": "diner_cream", "f9d8b2": "diner_cream", "f9d9b3": "diner_cream",
	"f9d9b4": "diner_cream", "f9dab5": "diner_cream", "f9dab6": "diner_cream", "fadbb6": "diner_cream",
	"fadbb7": "diner_cream", "fadbb8": "diner_cream", "fadcb8": "diner_cream", "fadcb9": "diner_cream",
	"fadcba": "diner_cream", "faddba": "diner_cream", "faddbb": "diner_cream", "fbddbb": "diner_cream",
	"fbdebc": "diner_cream", "fbdebd": "diner_cream", "fbdfbd": "diner_cream", "fbdfbe": "diner_cream",
	"fbdfbf": "diner_cream", "fbe0bf": "diner_cream", "fce0c0": "diner_cream", "fce0c1": "diner_cream",
	"fce1c1": "diner_cream", "fce1c2": "diner_cream", "fce2c3": "diner_cream", "fce2c4": "diner_cream",
	"fde3c5": "diner_cream", "fde3c6": "diner_cream", "fde4c6": "diner_cream", "fde4c7": "diner_cream",
}

const BARBARIAN_BLUE_TO_CLOTH := {
	"354e5a": "cloth_blue", "354e5b": "cloth_blue", "364f5b": "cloth_blue", "364f5c": "cloth_blue", "36505c": "cloth_blue",
	"37505d": "cloth_blue", "37515d": "cloth_blue", "37515e": "cloth_blue", "38515e": "cloth_blue", "38525f": "cloth_blue",
	"385260": "cloth_blue", "395260": "cloth_blue", "395360": "cloth_blue", "395361": "cloth_blue", "3a5462": "cloth_blue",
	"3a5463": "cloth_blue", "3a5563": "cloth_blue", "3b5564": "cloth_blue", "3b5664": "cloth_blue", "3b5665": "cloth_blue",
	"3c5665": "cloth_blue", "3c5766": "cloth_blue", "3d5767": "cloth_blue", "3d5867": "cloth_blue", "3d5868": "cloth_blue",
	"3d5968": "cloth_blue", "3e5969": "cloth_blue", "3e5a6a": "cloth_blue", "3f5a6a": "cloth_blue", "3f5a6b": "cloth_blue",
	"3f5b6b": "cloth_blue", "405b6c": "cloth_blue", "405c6c": "cloth_blue", "405c6d": "cloth_blue", "415d6e": "cloth_blue",
	"415d6f": "cloth_blue", "415e6f": "cloth_blue", "425e6f": "cloth_blue", "425e70": "cloth_blue", "425f71": "cloth_blue",
	"435f71": "cloth_blue", "435f72": "cloth_blue", "436072": "cloth_blue", "446073": "cloth_blue", "446173": "cloth_blue",
	"446174": "cloth_blue", "456274": "cloth_blue", "456275": "cloth_blue", "456276": "cloth_blue", "466376": "cloth_blue",
	"466377": "cloth_blue", "466477": "cloth_blue", "476478": "cloth_blue", "476578": "cloth_blue", "476579": "cloth_blue",
	"486579": "cloth_blue", "48667a": "cloth_blue", "48667b": "cloth_blue", "49667b": "cloth_blue", "49677b": "cloth_blue",
	"49677c": "cloth_blue", "4a687d": "cloth_blue", "4a687e": "cloth_blue", "4a697e": "cloth_blue", "4b697f": "cloth_blue",
	"4b6a7f": "cloth_blue", "4b6a80": "cloth_blue", "4c6a80": "cloth_blue", "4c6b81": "cloth_blue", "4d6b82": "cloth_blue",
	"4d6c82": "cloth_blue", "4d6c83": "cloth_blue", "4d6d83": "cloth_blue", "4e6d84": "cloth_blue", "4e6e85": "cloth_blue",
	"4f6e85": "cloth_blue", "4f6e86": "cloth_blue", "4f6f86": "cloth_blue", "506f87": "cloth_blue", "507087": "cloth_blue",
	"507088": "cloth_blue", "517189": "cloth_blue", "51718a": "cloth_blue", "51728a": "cloth_blue", "52728a": "cloth_blue",
	"52728b": "cloth_blue", "52738c": "cloth_blue", "53738c": "cloth_blue", "53738d": "cloth_blue", "53748d": "cloth_blue",
	"54748e": "cloth_blue", "54758e": "cloth_blue", "54758f": "cloth_blue", "55768f": "cloth_blue", "557690": "cloth_blue",
	"557691": "cloth_blue", "567791": "cloth_blue", "567792": "cloth_blue", "567892": "cloth_blue", "577893": "cloth_blue",
	"577993": "cloth_blue", "577994": "cloth_blue", "587994": "cloth_blue", "587a95": "cloth_blue", "587a96": "cloth_blue",
	"597a96": "cloth_blue", "597b96": "cloth_blue", "597b97": "cloth_blue", "5a7c98": "cloth_blue", "5a7c99": "cloth_blue",
	"5a7d99": "cloth_blue", "5b7d9a": "cloth_blue", "5b7e9a": "cloth_blue", "5b7e9b": "cloth_blue", "5c7e9b": "cloth_blue",
	"5c7f9c": "cloth_blue", "5d7f9d": "cloth_blue", "5d809d": "cloth_blue", "5d809e": "cloth_blue", "5d819e": "cloth_blue",
	"5e819f": "cloth_blue", "5e82a0": "cloth_blue", "5f82a0": "cloth_blue", "5f82a1": "cloth_blue", "5f83a1": "cloth_blue",
	"6083a2": "cloth_blue", "6084a2": "cloth_blue", "6084a3": "cloth_blue", "6185a4": "cloth_blue", "6185a5": "cloth_blue",
	"6186a5": "cloth_blue", "6286a5": "cloth_blue", "6286a6": "cloth_blue", "6287a7": "cloth_blue", "6387a7": "cloth_blue",
	"6387a8": "cloth_blue", "6388a8": "cloth_blue", "6488a9": "cloth_blue", "6489a9": "cloth_blue", "6489aa": "cloth_blue",
	"658aaa": "cloth_blue", "658aab": "cloth_blue",
}

const BARBARIAN_BLUE_TO_APRON := {
	"354e5a": "apron_white", "354e5b": "apron_white", "364f5b": "apron_white", "364f5c": "apron_white", "36505c": "apron_white",
	"37505d": "apron_white", "37515d": "apron_white", "37515e": "apron_white", "38515e": "apron_white", "38525f": "apron_white",
	"385260": "apron_white", "395260": "apron_white", "395360": "apron_white", "395361": "apron_white", "3a5462": "apron_white",
	"3a5463": "apron_white", "3a5563": "apron_white", "3b5564": "apron_white", "3b5664": "apron_white", "3b5665": "apron_white",
	"3c5665": "apron_white", "3c5766": "apron_white", "3d5767": "apron_white", "3d5867": "apron_white", "3d5868": "apron_white",
	"3d5968": "apron_white", "3e5969": "apron_white", "3e5a6a": "apron_white", "3f5a6a": "apron_white", "3f5a6b": "apron_white",
	"3f5b6b": "apron_white", "405b6c": "apron_white", "405c6c": "apron_white", "405c6d": "apron_white", "415d6e": "apron_white",
	"415d6f": "apron_white", "415e6f": "apron_white", "425e6f": "apron_white", "425e70": "apron_white", "425f71": "apron_white",
	"435f71": "apron_white", "435f72": "apron_white", "436072": "apron_white", "446073": "apron_white", "446173": "apron_white",
	"446174": "apron_white", "456274": "apron_white", "456275": "apron_white", "456276": "apron_white", "466376": "apron_white",
	"466377": "apron_white", "466477": "apron_white", "476478": "apron_white", "476578": "apron_white", "476579": "apron_white",
	"486579": "apron_white", "48667a": "apron_white", "48667b": "apron_white", "49667b": "apron_white", "49677b": "apron_white",
	"49677c": "apron_white", "4a687d": "apron_white", "4a687e": "apron_white", "4a697e": "apron_white", "4b697f": "apron_white",
	"4b6a7f": "apron_white", "4b6a80": "apron_white", "4c6a80": "apron_white", "4c6b81": "apron_white", "4d6b82": "apron_white",
	"4d6c82": "apron_white", "4d6c83": "apron_white", "4d6d83": "apron_white", "4e6d84": "apron_white", "4e6e85": "apron_white",
	"4f6e85": "apron_white", "4f6e86": "apron_white", "4f6f86": "apron_white", "506f87": "apron_white", "507087": "apron_white",
	"507088": "apron_white", "517189": "apron_white", "51718a": "apron_white", "51728a": "apron_white", "52728a": "apron_white",
	"52728b": "apron_white", "52738c": "apron_white", "53738c": "apron_white", "53738d": "apron_white", "53748d": "apron_white",
	"54748e": "apron_white", "54758e": "apron_white", "54758f": "apron_white", "55768f": "apron_white", "557690": "apron_white",
	"557691": "apron_white", "567791": "apron_white", "567792": "apron_white", "567892": "apron_white", "577893": "apron_white",
	"577993": "apron_white", "577994": "apron_white", "587994": "apron_white", "587a95": "apron_white", "587a96": "apron_white",
	"597a96": "apron_white", "597b96": "apron_white", "597b97": "apron_white", "5a7c98": "apron_white", "5a7c99": "apron_white",
	"5a7d99": "apron_white", "5b7d9a": "apron_white", "5b7e9a": "apron_white", "5b7e9b": "apron_white", "5c7e9b": "apron_white",
	"5c7f9c": "apron_white", "5d7f9d": "apron_white", "5d809d": "apron_white", "5d809e": "apron_white", "5d819e": "apron_white",
	"5e819f": "apron_white", "5e82a0": "apron_white", "5f82a0": "apron_white", "5f82a1": "apron_white", "5f83a1": "apron_white",
	"6083a2": "apron_white", "6084a2": "apron_white", "6084a3": "apron_white", "6185a4": "apron_white", "6185a5": "apron_white",
	"6186a5": "apron_white", "6286a5": "apron_white", "6286a6": "apron_white", "6287a7": "apron_white", "6387a7": "apron_white",
	"6387a8": "apron_white", "6388a8": "apron_white", "6488a9": "apron_white", "6489a9": "apron_white", "6489aa": "apron_white",
	"658aaa": "apron_white", "658aab": "apron_white",
}

## S4 Task 12 fence variants (castle atlas, used by the fence sources only) and the rubble variant (fantasy-town atlas,
## fence-broken only). "swap" moves every swatch whose default palette name is a key to the value, like GUARD_SWAPS.
## The fence pieces sample skin_light / diner_cream (the wall face), skin_mid (its shade) and wood (the darkest bands).
const FENCE_WOOD_SWAP := {"skin_light": "wood", "diner_cream": "wood", "skin_mid": "wood_dark", "wood": "wood_dark"}
const FENCE_STONE_SWAP := {"skin_light": "stone", "diner_cream": "stone", "skin_mid": "steel_dark", "wood": "ink_soft"}
const RUBBLE_WOOD_SWAP := {"skin_mid": "wood", "dirt_dark": "wood_dark", "gold_dark": "wood_dark", "steel": "wood"}

const BASE_ENTRIES: Array[Dictionary] = [
	{"src": "res://assets/kenney-tower-defense/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-tower-defense__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-castle/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-castle__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-fantasy-town/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-fantasy-town__colormap.png", "overrides": ROOF_TO_STONE},
	{"src": "res://assets/kenney-castle/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-castle__wood.png", "overrides": {}, "swap": FENCE_WOOD_SWAP},
	{"src": "res://assets/kenney-castle/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-castle__stone.png", "overrides": {}, "swap": FENCE_STONE_SWAP},
	{"src": "res://assets/kenney-fantasy-town/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-fantasy-town__rubble.png", "overrides": {}, "swap": RUBBLE_WOOD_SWAP},
	{"src": "res://assets/kenney-city-commercial/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-city-commercial__colormap.png", "overrides": AWNING_STRIPES},
	{"src": "res://assets/kenney-food/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-food__colormap.png", "overrides": {}},
	{"src": "res://assets/kenney-platformer/Textures/colormap.png", "out": "res://art/palette/atlas/kenney-platformer__colormap.png", "overrides": COIN_RIM_TO_GOLD},
	{"src": "res://assets/kaykit-adventurers/Textures/barbarian_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__barbarian_texture.png", "overrides": BARBARIAN_BLUE_TO_CLOTH},
	{"src": "res://assets/kaykit-adventurers/Textures/barbarian_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__barbarian_apron.png", "overrides": BARBARIAN_BLUE_TO_APRON},
	{"src": "res://assets/kaykit-adventurers/Textures/knight_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__knight_texture.png", "overrides": {}, "guard_swap": true},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__rogue_texture.png", "overrides": {}, "guard_swap": true},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__mage_texture.png", "overrides": {}},
	{"src": "res://assets/kaykit-restaurant/Assets/gltf/restaurantbits_texture.png", "out": "res://art/palette/atlas/kaykit-restaurant__restaurantbits_texture.png", "overrides": FRIDGE_TEAL_TO_ICE},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_grey.png", "overrides": {}, "tone": "traveler_grey"},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_beige.png", "overrides": {}, "tone": "traveler_beige"},
	{"src": "res://assets/kaykit-adventurers/Textures/rogue_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_rogue_brown.png", "overrides": {}, "tone": "traveler_brown"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_grey.png", "overrides": {}, "tone": "traveler_grey"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_beige.png", "overrides": {}, "tone": "traveler_beige"},
	{"src": "res://assets/kaykit-adventurers/Textures/mage_texture.png", "out": "res://art/palette/atlas/kaykit-adventurers__traveler_mage_brown.png", "overrides": {}, "tone": "traveler_brown"},
]

## R2 / D-191: the hero and rewards own apron_white, warm_white, gold and gold_dark; travelers own traveler_*.
## A guard atlas moves every swatch whose nearest palette colour is a key here to the value.
const GUARD_SWAPS := {
	"apron_white": "steel", "warm_white": "steel", "gold": "steel_dark", "gold_dark": "steel_dark",
	"traveler_grey": "steel_dark", "traveler_beige": "steel", "traveler_brown": "wood_dark",
}
## Swatches a traveler keeps as skin. skin_dark is left out: on these atlases it is the gloves and boots (leather), not skin.
const SKIN_KEEP: Array[String] = ["skin_light", "skin_mid"]
const IMAGE_SIZE := 512  # tools/palette_remap.gd resizes the 1024 KayKit atlases to this

## Every entry with its hex overrides expanded. Built when this script loads (only tools/palette_remap.gd loads it).
static var _default_names := {}
static var ENTRIES: Array[Dictionary] = _build()

static func _build() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in BASE_ENTRIES:
		var d := e.duplicate()
		var ov: Dictionary = d.overrides.duplicate()
		if d.get("guard_swap", false):
			for hex in default_names(d.src):
				var n: String = default_names(d.src)[hex]
				if GUARD_SWAPS.has(n):
					ov[hex] = GUARD_SWAPS[n]
		elif d.has("swap"):
			for hex in default_names(d.src):
				var sn: String = default_names(d.src)[hex]
				if d.swap.has(sn):
					ov[hex] = d.swap[sn]
		elif d.has("tone"):
			# Every non-skin swatch goes to the one traveler colour; skin swatches keep their (nearest) skin tones.
			for hex in default_names(d.src):
				if not SKIN_KEEP.has(default_names(d.src)[hex]):
					ov[hex] = d.tone
		d.overrides = ov
		d.erase("guard_swap")
		d.erase("tone")
		d.erase("swap")
		out.append(d)
	return out

## The palette the tool maps atlases with (ART_BIBLE R4): enemy_* entries are replaced by a far-away sentinel, so
## nearest() never picks them. Shared by the tool and default_names() so they can't drift.
static func atlas_colors() -> PackedColorArray:
	var pal = load("res://art/palette/palette.gd")
	var colors: PackedColorArray = pal.colors()
	for n in pal.NAMES:
		if String(n).begins_with("enemy_"):
			colors[pal.index_of(n)] = Color(10, 10, 10)
	return colors

## lowercase source hex (after the tool's resize) -> the palette name the tool maps it to by default (no enemy_*, R4).
static func default_names(src: String) -> Dictionary:
	if _default_names.has(src):
		return _default_names[src]
	var pal = load("res://art/palette/palette.gd")
	var pm = load("res://core/palette_math.gd")
	var colors := atlas_colors()
	var img := Image.load_from_file(ProjectSettings.globalize_path(src))
	if img.get_width() > IMAGE_SIZE or img.get_height() > IMAGE_SIZE:
		img.resize(mini(img.get_width(), IMAGE_SIZE), mini(img.get_height(), IMAGE_SIZE), Image.INTERPOLATE_NEAREST)
	var names := {}
	for y in img.get_height():
		for x in img.get_width():
			var hex := img.get_pixel(x, y).to_html(false)
			if not names.has(hex):
				names[hex] = String(pal.NAMES[pm.nearest(Color(hex), colors)])
	_default_names[src] = names
	return names
