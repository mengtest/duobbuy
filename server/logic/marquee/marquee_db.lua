local marqueeDb = {}

--获取所有缓存跑马灯信息
function marqueeDb.getmarqueeInfos(db)
	local marqueeInfos = {}
	local infos = db.Marquee:find()
	while infos:hasNext() do
		local r = infos:next()
		marqueeInfos[r.id] = {
			startTime = r.startTime,
			priority = r.priority,
			times = r.times,
			id = r.id,
			timeInterval = r.timeInterval,
			content = r.content,
			endTime = r.endTime,
		}
	end
	
	return marqueeInfos
end

--获取单个跑马灯消息
function marqueeDb.getMarqueeInfo(db,marqueeId)
	return db.Marquee:find({id = marqueeId})
end

--设置跑马灯消息
function marqueeDb.setMarqueeInfo(db,marqueeInfo)
	db.Marquee:update(
		{ ["id"] = marqueeInfo.id},
        { ["$set"] = marqueeInfo}
	)
end

--增加新跑马灯消息
function marqueeDb.addMarqueeInfo(db,marqueeInfo)
	db.Marquee:insert(marqueeInfo)
end


--删除跑马灯
function marqueeDb.delMarqueeInfo(db,marqueeId)
	local doc = {
		query = {id = marqueeId},
		remove = true,
	}
	db.Marquee:findAndModify(doc)
end

-- 判断跑马灯消息是否存在
function marqueeDb.judgeMarqueeExist(db,marqueeId)
	local ret = db.Marquee:findOne({id = marqueeId})

	return ret and ret._id
end

return marqueeDb