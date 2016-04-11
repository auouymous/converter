-- convert a stack of ingredient to a stack of result
-- convert a stack of result to a stack of ingredient, if reverse is true
-- {"ingredient", "result", reverse},
converter.recipes = {
	-- default
	{"default:stone", "default:stonebrick", true},
	{"default:sandstone", "default:sandstonebrick", true},
	{"default:desert_stone", "default:desert_stonebrick", true},

	-- ethereal
	{"default:snowblock", "ethereal:snowbrick", true},
	{"default:ice", "ethereal:icebrick", true},
}
