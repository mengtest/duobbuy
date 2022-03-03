local fundConst = {}

fundConst.errors = {
	[22] = FundError.itemClose,
	[23] = FundError.itemSoldOut,
	[24] = FundError.roundClose,
	[25] = FundError.addressEmpty,
	[26] = FundError.addressError,
}

fundConst.itemType = {
	GAME = 1,
	REAL = 2,
	GUN = 3,
}

-- 新手玩家，10000金币商品 ID
fundConst.newPlayerPrizeId = 39

return fundConst