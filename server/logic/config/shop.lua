--[[
	合并shop_gold, shop_gun配置
]]
local shops = {}
require("functions")
local roleConst = require("role.role_const")

package.loaded["config.shop_gold"] = nil
package.loaded["config.shop_gun"] = nil
package.loaded["config.shop_gift"] = nil
package.loaded["config.shop_bag"] = nil
package.loaded["config.shop_vip"] = nil

local shopGold = require("config.shop_gold")
local shopGun = require("config.shop_gun")
local shopGift = require("config.shop_gift")
local shopBag = require("config.shop_bag")
local shopVip = require("config.shop_vip")

for _,v in pairs(shopGold) do
	v.goodsAwardType = roleConst.SHOP_MATERIAL
end
for _,v in pairs(shopGun) do
	v.goodsAwardType = roleConst.SHOP_GUN
end
for _,v in pairs(shopGift) do
	v.goodsAwardType = roleConst.SHOP_GIFT
end
for _,v in pairs(shopBag) do
	v.goodsAwardType = roleConst.SHOP_BAG
end
for _,v in pairs(shopVip) do
	v.goodsAwardType = roleConst.SHOP_MATERIAL
end

table.merge(shops, shopGold)
table.merge(shops, shopGun)
table.merge(shops, shopGift)
table.merge(shops, shopBag)
table.merge(shops, shopVip)

return shops