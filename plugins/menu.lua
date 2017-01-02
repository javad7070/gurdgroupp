local function changeWarnSettings(chat_id, action)
    local current = tonumber(db:hget('chat:'..chat_id..':warnsettings', 'max')) or 3
    local new_val
    if action == 1 then
        if current > 12 then
            return _("مقدار جدید بیش از حد بالا است ( > 12)")
        else
            new_val = db:hincrby('chat:'..chat_id..':warnsettings', 'max', 1)
            return current..'->'..new_val
        end
    elseif action == -1 then
        if current < 2 then
            return _("مقدار جدید خیلی کم است ( < 1)")
        else
            new_val = db:hincrby('chat:'..chat_id..':warnsettings', 'max', -1)
            return current..'->'..new_val
        end
    elseif action == 'status' then
        local status = (db:hget('chat:'..chat_id..':warnsettings', 'type')) or 'kick'
        if status == 'kick' then
            db:hset('chat:'..chat_id..':warnsettings', 'type', 'ban')
            return _("اقدام جدید در حداکثر تعداد دریافت هشدار می دهد:*مسدودیت *")
        elseif status == 'ban' then
            db:hset('chat:'..chat_id..':warnsettings', 'type', 'kick')
            return _("اقدام جدید در حداکثر تعداد دریافت هشدار می دهد: * اخراج *")
        end
    end
end

local function changeCharSettings(chat_id, field)
	local chars = {
		arab_kick = _("فرستندگان پیام های عرب اخراج خواهد شد"),
		arab_ban = _("فرستندگان پیام های عربی مسدود خواهد شد"),
		arab_allow = _("زبان عرب اجازه داده شود"),
		rtl_kick = _("شخصیت های راست نویس اخراج خواهند شد"),
		rtl_ban = _("شخصیت های راست نویس مسدود خواهند شد"),
		rtl_allow = _("به راست نویسان اجازه داده شود"),
	}

    local hash = 'chat:'..chat_id..':char'
    local status = db:hget(hash, field)
    local text
    if status == 'allowed' then
        db:hset(hash, field, 'kick')
        text = chars[field:lower()..'_kick']
    elseif status == 'kick' then
        db:hset(hash, field, 'ban')
        text = chars[field:lower()..'_ban']
    elseif status == 'ban' then
        db:hset(hash, field, 'allowed')
        text = chars[field:lower()..'_allow']
    else
        db:hset(hash, field, 'allowed')
        text = chars[field:lower()..'_allow']
    end

    return text
end

local function usersettings_table(settings, chat_id)
    local return_table = {}
    local icon_off, icon_on = '👤', '👥'
    for field, default in pairs(settings) do
        if field == 'Extra' or field == 'Rules' then
            local status = (db:hget('chat:'..chat_id..':settings', field)) or default
            if status == 'off' then
                return_table[field] = icon_off
            elseif status == 'on' then
                return_table[field] = icon_on
            end
        end
    end
    
    return return_table
end

local function adminsettings_table(settings, chat_id)
    local return_table = {}
    local icon_off, icon_on = '🚫', '✅'
    for field, default in pairs(settings) do
        if field ~= 'Extra' and field ~= 'Rules' then
            local status = (db:hget('chat:'..chat_id..':settings', field)) or default
            if status == 'off' then
                return_table[field] = icon_off
            elseif status == 'on' then
                return_table[field] = icon_on
            end
        end
    end
    
    return return_table
end

local function charsettings_table(settings, chat_id)
    local return_table = {}
    local icon_allow, icon_not_allow = '✅', '🔐'
    for field, default in pairs(settings) do
        local status = (db:hget('chat:'..chat_id..':char', field)) or default
        if status == 'kick' or status == 'ban' then
            return_table[field] = icon_not_allow..' '..status
        elseif status == 'allowed' then
            return_table[field] = icon_allow
        end
    end
    
    return return_table
end

local function insert_settings_section(keyboard, settings_section, chat_id)
	local strings = {
		Welcome = _("پیام خوش آمد"),
		Extra = _("تگ"),
		Flood = _("ضد اسپم"),
		Silent = _("حالت بی صدا"),
		Rules = _("قوانین"),
		Arab = _("عرب"),
		Rtl = _("راست نویس"),
		Antibot = _("اخراج ربات ها")
	}

    for key, icon in pairs(settings_section) do
        local current = {
            {text = strings[key] or key, callback_data = 'menu:alert:settings'},
            {text = icon, callback_data = 'menu:'..key..':'..chat_id}
        }
        table.insert(keyboard.inline_keyboard, current)
    end
    
    return keyboard
end

local function doKeyboard_menu(chat_id)
    local keyboard = {inline_keyboard = {}}
    
    local settings_section = adminsettings_table(config.chat_settings['settings'], chat_id)
    keyboad = insert_settings_section(keyboard, settings_section, chat_id)
    
    settings_section = usersettings_table(config.chat_settings['settings'], chat_id)
    keyboad = insert_settings_section(keyboard, settings_section, chat_id)
    
    settings_section = charsettings_table(config.chat_settings['char'], chat_id)
    keyboad = insert_settings_section(keyboard, settings_section, chat_id)
    
    --warn
    local max = (db:hget('chat:'..chat_id..':warnsettings', 'max')) or config.chat_settings['warnsettings']['max']
    local action = (db:hget('chat:'..chat_id..':warnsettings', 'type')) or config.chat_settings['warnsettings']['type']
	if action == 'kick' then
		action = _("📍%d🔨️اخراج"):format(tonumber(max))
	else
		action = _("📍%d🔨️مسدود"):format(tonumber(max))
	end
    local warn = {
		{text = '➖', callback_data = 'menu:DimWarn:'..chat_id},
		{text = action, callback_data = 'menu:ActionWarn:'..chat_id},
		{text = '➕', callback_data = 'menu:RaiseWarn:'..chat_id},
    }
    table.insert(keyboard.inline_keyboard, {{text = _("اخطارها 👇🏼"), callback_data = 'menu:alert:warns:'}})
    table.insert(keyboard.inline_keyboard, warn)
    
    --back button
    table.insert(keyboard.inline_keyboard, {{text = '🔙', callback_data = 'config:back:'..chat_id}})
    
    return keyboard
end

local action = function(msg, blocks)
	local menu_first = _([[
:مدیریت تنظیمات این گروه

*تگ*:
• 👥: .این علامت نشان دهنده آن است که ربات در گروه به آن ها پاسخ میدهد
• 👤: .این علامت نشان دهنده آن است که ربات پاسخ آن را در خصوصی مدیران یا کاربران عادی ارسال میکند

*حالت بی صدا*:
اگر فعال باشد:
.ربات یک پیام تایید به گروه ارسال میکند
برای فعال سازی دستور
/config
یا
/dashboard
.را درگروه ارسال کنید سپس ربات یک پیام به خصوصی شما میدهد
]])

    --get the interested chat id
    local chat_id = msg.target_id
    
    local keyboard, text
    
    if blocks[1] == 'config' then
        keyboard = doKeyboard_menu(chat_id)
        api.editMessageText(msg.chat.id, msg.message_id, menu_first, keyboard, true)
    else
	    if blocks[2] == 'alert' then
	        if blocks[3] == 'settings' then
                text = _("⚠️ لطفا روی دکمه های روبه رو کلیک کنید")
            elseif blocks[3] == 'warns' then
                text = _("⚠️ ردیف زیر برای تغییر تنظیمات هشدار استفاده میشود!")
            end
            api.answerCallbackQuery(msg.cb_id, text)
            return
        end
        if blocks[2] == 'DimWarn' or blocks[2] == 'RaiseWarn' or blocks[2] == 'ActionWarn' then
            if blocks[2] == 'DimWarn' then
                text = changeWarnSettings(chat_id, -1)
            elseif blocks[2] == 'RaiseWarn' then
                text = changeWarnSettings(chat_id, 1)
            elseif blocks[2] == 'ActionWarn' then
                text = changeWarnSettings(chat_id, 'status')
            end
        elseif blocks[2] == 'Rtl' or blocks[2] == 'Arab' then
            text = changeCharSettings(chat_id, blocks[2])
        else
            text = misc.changeSettingStatus(chat_id, blocks[2])
        end
        keyboard = doKeyboard_menu(chat_id)
        api.editMessageText(msg.chat.id, msg.message_id, menu_first, keyboard, true)
        if text then api.answerCallbackQuery(msg.cb_id, '⚙ '..text) end --workaround to avoid to send an error to users who are using an old inline keyboard
    end
end

return {
	action = action,
	triggers = {
	    '^###cb:(menu):(alert):(settings)',
    	'^###cb:(menu):(alert):(warns)',
    	
    	'^###cb:(menu):(.*):',
    	
    	'^###cb:(config):menu:(-%d+)$'
	}
}
