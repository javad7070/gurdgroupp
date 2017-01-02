local function do_keyboard_flood(chat_id)
    --no: enabled, yes: disabled
    local status = db:hget('chat:'..chat_id..':settings', 'Flood') or config.chat_settings['settings']['Flood'] --check (default: disabled)
    if status == 'on' then
        status = _("✅ | فعال")
    elseif status == 'off' then
        status = _("❌ | غیرفعال")
    end
    
    local hash = 'chat:'..chat_id..':flood'
    local action = (db:hget(hash, 'ActionFlood')) or config.chat_settings['flood']['ActionFlood']
    if action == 'kick' then
        action = _("⚡️ اخراج")
    else
        action = _("⛔ ️مسدود")
    end
    local num = (db:hget(hash, 'MaxFlood')) or config.chat_settings['flood']['MaxFlood']
    local keyboard = {
        inline_keyboard = {
            {
                {text = status, callback_data = 'flood:status:'..chat_id},
                {text = action, callback_data = 'flood:action:'..chat_id},
            },
            {
                {text = '➖', callback_data = 'flood:dim:'..chat_id},
                {text = num, callback_data = 'flood:alert:num'},
                {text = '➕', callback_data = 'flood:raise:'..chat_id},
            }
        }
    }
    
    local exceptions = {
        text = _("متن ها"),
        sticker = _("استیکر ها"),
        image = _("عکس ها"),
        gif = _("گیف ها"),
        video = _("ویدیو ها"),
    }
    local hash = 'chat:'..chat_id..':floodexceptions'
    for media, translation in pairs(exceptions) do
        --ignored by the antiflood-> yes, no
        local exc_status = (db:hget(hash, media)) or config.chat_settings['floodexceptions'][media]
        if exc_status == 'yes' then
            exc_status = '✅'
        else
            exc_status = '❌'
        end
        local line = {
            {text = translation, callback_data = 'flood:alert:voice'},
            {text = exc_status, callback_data = 'flood:exc:'..media..':'..chat_id},
        }
        table.insert(keyboard.inline_keyboard, line)
    end
    
    --back button
    table.insert(keyboard.inline_keyboard, {{text = '🔙', callback_data = 'config:back:'..chat_id}})
    
    return keyboard
end

local function action(msg, blocks)
	local header = _([[
.شما میتوانید تنظیمات اسپم گروه را از این بخش مدیریت کنید

*ردیف1*
• *خاموش/روشن*: 
*وضعیت فعلی ضد اسپم*
• *مسدود/اخراج*:
*چه عملی انجام شود وقتی کسی در گروه اسپم داد*

*ردیف2*
• _شما میتوانید با +و-زمان  ارسال اسپم رو کم و زیاد کنید_
• _حداکثر میزان ارسال پیام ها در 5ثانیه میباشد_
• _سقف تنظیم آن25و حداقل آن 4میباشد_

*ردیف3*
معرفی علامت ها:
• ✅: این علامت نشاندهنده نادیده گرفتن رسانه ها میشود
• ❌: این علامت نشاندهنده نادیده نگرفتن رسانه ها میشود
• *این بخش شامل همه رسانه ها به علاوه متن ها میشود*:نکته
]])

    
    if not msg.cb and msg.chat.type == 'private' then return end
    
    local chat_id = msg.target_id or msg.chat.id
    
    local text, keyboard
    
    if blocks[1] == 'antiflood' then
        if not roles.is_admin_cached(msg) then return end
        if blocks[2]:match('%d%d?') then
            if tonumber(blocks[2]) < 4 or tonumber(blocks[2]) > 25 then
				local text = _("`%s میزان باید کمتر از26و بالای3باشد.اشتباه است")
				api.sendReply(msg, text:format(blocks[1]), true)
			else
	    	    local new = tonumber(blocks[2])
	    	    local old = tonumber(db:hget('chat:'..msg.chat.id..':flood', 'MaxFlood')) or config.chat_settings['flood']['MaxFlood']
	    	    if new == old then
	            	api.sendReply(msg, _("حداکثر تعداد پیام در حال حاضر %d"):format(new), true)
	    	    else
	            	db:hset('chat:'..msg.chat.id..':flood', 'MaxFlood', new)
					local text = _("از_تعداد حدااکثر پیام ها در 5ثانیه تغییر میکند_  %d _به_  %d")
	            	api.sendReply(msg, text:format(old, new), true)
	    	    end
            end
            return
        end
    else
        if not msg.cb then return end --avaoid trolls
        
        if blocks[1] == 'config' then
            keyboard = do_keyboard_flood(chat_id)
            api.editMessageText(msg.chat.id, msg.message_id, header, keyboard, true)
            return
        end
        
        if blocks[1] == 'alert' then
            if blocks[2] == 'num' then
                text = _("⚖ برای افزایش روی+کلیک کنید.حسایت فعلی -")
            elseif blocks[2] == 'voice' then
                text = _("⚠️ لطفا روی دکمه های روبه رو کلیک کنید")
            end
            api.answerCallbackQuery(msg.cb_id, text)
            return
        end
        
        if blocks[1] == 'exc' then
            local media = blocks[2]
            local hash = 'chat:'..chat_id..':floodexceptions'
            local status = (db:hget(hash, media)) or 'no'
            if status == 'no' then
                db:hset(hash, media, 'yes')
                text = _("❎ [%s] توسط ضد اسپم نادیده گرفته خواهد شد"):format(media)
            else
                db:hset(hash, media, 'no')
                text = _("🚫 [%s] توسط ضد اسپم نادیده گرفته نخواهد شد"):format(media)
            end
        end
        
        local action
        if blocks[1] == 'action' or blocks[1] == 'dim' or blocks[1] == 'raise' then
            if blocks[1] == 'action' then
                action = (db:hget('chat:'..chat_id..':flood', 'ActionFlood')) or 'kick'
            elseif blocks[1] == 'dim' then
                action = -1
            elseif blocks[1] == 'raise' then
                action = 1
            end
            text = misc.changeFloodSettings(chat_id, action):escape_hard()
        end
        
        if blocks[1] == 'status' then
            local status = db:hget('chat:'..chat_id..':settings', 'Flood') or config.chat_settings['settings']['Flood']
            text = misc.changeSettingStatus(chat_id, 'Flood'):escape_hard()
        end
        
        keyboard = do_keyboard_flood(chat_id)
        api.editMessageText(msg.chat.id, msg.message_id, header, keyboard, true)
        api.answerCallbackQuery(msg.cb_id, text)
    end
end

return {
    action = action,
    triggers = {
        config.cmd..'(antiflood) (%d%d?)$',
        
        '^###cb:flood:(alert):(%w+)$',
        '^###cb:flood:(status):(-%d+)$',
        '^###cb:flood:(action):(-%d+)$',
        '^###cb:flood:(dim):(-%d+)$',
        '^###cb:flood:(raise):(-%d+)$',
        '^###cb:flood:(exc):(%a+):(-%d+)$',
        
        '^###cb:(config):antiflood:'
    }
}
