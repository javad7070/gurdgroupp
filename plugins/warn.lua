local function doKeyboard_warn(user_id)
	local keyboard = {}
    keyboard.inline_keyboard = {
    	{
    		{text = _("ریست اخطارها"), callback_data = 'resetwarns:'..user_id},
    		{text = _("حذف اخطار"), callback_data = 'removewarn:'..user_id}
    	}
    }
    return keyboard
end

local function action(msg, blocks)
    
    --warns/mediawarn
    
    if msg.chat.type == 'private' then return end
    if not roles.is_admin(msg) then
    	if msg.cb then --show a pop up if a normal user tap on an inline button
    		api.answerCallbackQuery(msg.cb_id, _("شما یک مدیر نیستید"))
    	end
    	return
    end
    
    if blocks[1] == 'warnmax' then
    	local new, default, text, key
    	local hash = 'chat:'..msg.chat.id..':warnsettings'
    	if blocks[2] == 'media' then
    		new = blocks[3]
    		default = 2
    		key = 'mediamax'
			text = _(".حداکثر تعداد اخطارها برای رسانه نغییر کرد\n")
    	else
    		key = 'max'
    		new = blocks[2]
    		default = 3
			text = _(".حداکثر تعداد اخطارها نغییر کرد\n")
    	end
		local old = (db:hget(hash, key)) or default
		db:hset(hash, key, new)
		text = text .. _("*قدیمی*بود %d\n*جدید* در حداکثر است %d"):format(tonumber(old), tonumber(new))
        api.sendReply(msg, text, true)
        return
    end
    
    if blocks[1] == 'resetwarns' and msg.cb then
    	local user_id = blocks[2]
    	print(msg.chat.id, user_id)
    	db:hdel('chat:'..msg.chat.id..':warns', user_id)
		db:hdel('chat:'..msg.chat.id..':mediawarn', user_id)
		
		local text = _("اخطارها *تغییر کرد*\n(مدیر: %s)"):format(misc.getname_final(msg.from))
		api.editMessageText(msg.chat.id, msg.message_id, text, false, true)
		return
	end
	
	if blocks[1] == 'removewarn' and msg.cb then
    	local user_id = blocks[2]
		local num = db:hincrby('chat:'..msg.chat.id..':warns', user_id, -1) --add one warn
		local text, nmax, diff
		if tonumber(num) < 0 then
			text = _("تعداد هشدارهای این کاربر در حال حاضر")
			db:hincrby('chat:'..msg.chat.id..':warns', user_id, 1) --restore the previouvs number
		else
			nmax = (db:hget('chat:'..msg.chat.id..':warnsettings', 'max')) or 3 --get the max num of warnings
			diff = nmax - num
			text = _("*حذف اخطار* (%d/%d)"):format(tonumber(num), tonumber(nmax))
		end
		
		text = text .. _("\n(مدیر: %s)"):format(misc.getname_final(msg.from))
		api.editMessageText(msg.chat.id, msg.message_id, text, false, true)
		return
	end
    
    --do not reply when...
    if not msg.reply or roles.is_admin_cached(msg.reply) or msg.reply.from.id == bot.id then
	    return
	end
    
    if blocks[1] == 'warn' then
	    
	    local name = misc.getname_final(msg.reply.from)
		local hash = 'chat:'..msg.chat.id..':warns'
		local num = db:hincrby(hash, msg.reply.from.id, 1) --add one warn
		local nmax = (db:hget('chat:'..msg.chat.id..':warnsettings', 'max')) or 3 --get the max num of warnings
		local text, res, motivation
		num, nmax = tonumber(num), tonumber(nmax)
		
		if num >= nmax then
			local type = (db:hget('chat:'..msg.chat.id..':warnsettings', 'type')) or 'kick'
			--try to kick/ban
			if type == 'ban' then
				text = _("%s *مسدودشد*: بخاطر به حداکثر رسیدن اخطارها (%d/%d)"):format(name, num , nmax)
				res, motivation = api.banUser(msg.chat.id, msg.reply.from.id)
	    	else --kick
				text = _("%s *اخراج شد*: به خاطر به حداکثر رسیدن اخطارها (%d/%d)"):format(name, num , nmax)
		    	res, motivation = api.kickUser(msg.chat.id, msg.reply.from.id)
		    end
		    --if kick/ban fails, send the motivation
		    if not res then
		    	if not motivation then
		    		motivation = _(".من نمیتوانم این کاربر را اخراج کنم\n"
						.. "من یک مدیر نیستم")
		    	end
		    	text = motivation
		    else
		    	misc.saveBan(msg.reply.from.id, 'warn') --add ban
		    	db:hdel('chat:'..msg.chat.id..':warns', msg.reply.from.id) --if kick/ban works, remove the warns
		    	db:hdel('chat:'..msg.chat.id..':mediawarn', msg.reply.from.id)
		    end
			--if the user reached the max num of warns, kick and send message
		    api.sendReply(msg, text, true)
		else
			local diff = nmax - num
			text = _("%s *هشدار داده شده* (%d/%d)"):format(name, num, nmax)
			local keyboard = doKeyboard_warn(msg.reply.from.id)
			api.sendKeyboard(msg.chat.id, text, keyboard, true)
		end
    end
end

return {
	action = action,
	triggers = {
		config.cmd..'(warnmax) (%d%d?)$',
		config.cmd..'(warnmax) (media) (%d%d?)$',
		config.cmd..'(warn)$',
		config.cmd..'(warn) (.*)$',
		'^###cb:(resetwarns):(%d+)$',
		'^###cb:(removewarn):(%d+)$',
	}
}