local function getFloodSettings_text(chat_id)
    local status = db:hget('chat:'..chat_id..':settings', 'Flood') or 'yes' --check (default: disabled)
    if status == 'no' then
        status = _("✅ | فعال")
    elseif status == 'yes' then
        status = _("❌ | غیرفعال")
    end
    local hash = 'chat:'..chat_id..':flood'
    local action = (db:hget(hash, 'ActionFlood')) or 'kick'
    if action == 'kick' then
        action = _("⚡️اخراج")
    else
        action = _("⛔مسدود")
    end
    local num = (db:hget(hash, 'MaxFlood')) or 5
    local exceptions = {
        text = _("متن ها"),
        sticker = _("استیکرها"),
        image = _("عکس ها"),
        gif = _("گیف ها"),
        video = _("ویدیو ها"),
    }
    hash = 'chat:'..chat_id..':floodexceptions'
    local list_exc = ''
    for media, translation in pairs(exceptions) do
        --ignored by the antiflood-> yes, no
        local exc_status = (db:hget(hash, media)) or 'no'
        if exc_status == 'yes' then
            exc_status = '✅'
        else
            exc_status = '❌'
        end
        list_exc = list_exc..'• `'..translation..'`: '..exc_status..'\n'
    end
    return _("- *وضعیت*: `%s`\n"):format(status)
			.. _("- *زمانی که یک کاربر اسپم دهد*:اکشن `%s`\n"):format(action)
			.. _("- *اجازه برای هر5ثانیه *:تعدا پیام ها: `%d`\n"):format(num)
			.. _("- *رسانه ها نادیده گرفته شود*:\n%s"):format(list_exc)
end

local function doKeyboard_dashboard(chat_id)
    local keyboard = {}
    keyboard.inline_keyboard = {
	    {
            {text = _("تنظیمات"), callback_data = 'dashboard:settings:'..chat_id},
            {text = _("مدیران"), callback_data = 'dashboard:adminlist:'..chat_id}
		},
	    {
		    {text = _("قوانین"), callback_data = 'dashboard:rules:'..chat_id},
		    {text = _("دستورات تگ"), callback_data = 'dashboard:extra:'..chat_id}
        },
	    {
	   	    {text = _("تنظیمات اسپم"), callback_data = 'dashboard:flood:'..chat_id},
	   	    {text = _("تنظیمات رسانه"), callback_data = 'dashboard:media:'..chat_id}
	    },
    }
    
    return keyboard
end

local action = function(msg, blocks)
    
    --get the interested chat id
    local chat_id = msg.target_id or msg.chat.id
    
    local keyboard = {}
    
    if not(msg.chat.type == 'private') and not msg.cb then
        keyboard = doKeyboard_dashboard(chat_id)
        --everyone can use this
        local res = api.sendKeyboard(msg.from.id, _("حرکت این ارسال برای دیدن * تمام اطلاعات * در مورد این گروه"), keyboard, true)
        if not misc.is_silentmode_on(msg.chat.id) then --send the responde in the group only if the silent mode is off
            if res then
                api.sendMessage(msg.chat.id, _("_من یک پیام به خصوصی شما ارسال کردم_"), true)
            else
                misc.sendStartMe(msg, msg.ln)
            end
        end
	    return
    end
    if msg.cb then
        local request = blocks[2]
        local text
        keyboard = doKeyboard_dashboard(chat_id)
        if request == 'settings' then
            text = misc.getSettings(chat_id)
        end
        if request == 'rules' then
            text = misc.getRules(chat_id)
        end
        if request == 'adminlist' then
            local creator, admins = misc.getAdminlist(chat_id)
            if not creator then
                -- creator is false, admins is the error code
                text = _("من نمیتوانم شما مدیر نیستید.\n*فقط یک مدیر میتواند لیست مدیران را ببیند*")
            else
                text = _("*سازنده*:\n%s\n\n*مدیران*:\n%s"):format(creator, admins)
            end
        end
        if request == 'extra' then
            text = misc.getExtraList(chat_id)
        end
        if request == 'flood' then
            text = getFloodSettings_text(chat_id)
        end
        if request == 'media' then
            text = _("*تنظیمات فعلی رسانه*:\n\n")
            for media, default_status in pairs(config.chat_settings['media']) do
                local status = (db:hget('chat:'..chat_id..':media', media)) or default_status
                if status == 'ok' then
                    status = '✅'
                else
                    status = '🔐 '
                end
                text = text..'`'..media..'` ≡ '..status..'\n'
            end
        end
        api.editMessageText(msg.chat.id, msg.message_id, text, keyboard, true)
        api.answerCallbackQuery(msg.cb_id, 'ℹ️ Group ► '..request)
        return
    end
end

return {
	action = action,
	triggers = {
		config.cmd..'(dashboard)$',
		'^###cb:(dashboard):(%a+):(-%d+)',
	}
}
