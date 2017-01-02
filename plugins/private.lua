local function do_keybaord_credits()
	local keyboard = {}
    keyboard.inline_keyboard = {
    	{
    		{text = _("کانال"), url = 'https://telegram.me/'..config.channel:gsub('@', '')},
    		{text = _("ارتباط با مدیر"), url = 'https://telegram.me/javad7070'},
    		{text = _("امتیاز به ربات"), url = 'https://telegram.me/storebot?start='..bot.username},
		},
		{
			{text = _("👥 گروه ها"), callback_data = 'private:groups'}
		}
	}
	return keyboard
end

local function doKeyboard_strings()
	local keyboard = {
		inline_keyboard = {}
	}
	for lang, flag in pairs(config.available_languages) do
		local line = {{text = flag, callback_data = 'sendpo:'..lang}}
		table.insert(keyboard.inline_keyboard, line)
	end
	return keyboard
end

local action = function(msg, blocks)
    
    if msg.chat.type ~= 'private' then return end
    
	if blocks[1] == 'ping' then
		local res = api.sendMessage(msg.from.id, 'Pong!', true)
		--[[if res then
			api.editMessageText(msg.chat.id, res.result.message_id, 'Response time: '..(os.clock() - clocktime_last_update))
		end]]
	end
	if blocks[1] == 'echo' then
		local res, code = api.sendMessage(msg.chat.id, blocks[2], true)
		if not res then
			if code == 118 then
				api.sendMessage(msg.chat.id, _("_این متن طولانی است من نمیتوانم آن را ارسال کنم_"))
			else
				local message_text = _(".این مدل نشانه گذاری صحیح نیست\n"
						.. "اگر مشکلی دارید به مدیر ربات پیام بدید  "
						.. "[مدیر ربات](https://telegram.me/javad7070).")
				api.sendMessage(msg.chat.id, message_text, true)
			end
		end
	end
	if blocks[1] == 'about' then
		local keyboard = do_keybaord_credits()
		local text = 'گارد گروپ یک ربات ضد اسپم رایگان است که امکانات فوق العاده ای در اختیار کاربران تلگرامی میگذارد لطفا گارد گروپ رو به دوستان خود معرفی کنید'
		if msg.cb then
			api.editMessageText(msg.chat.id, msg.message_id, text, keyboard, true)
		else
			api.sendKeyboard(msg.chat.id, text, keyboard, true)
		end
	end
	if blocks[1] == 'groups' then
		if config.help_groups and next(config.help_groups) then
			keyboard = {inline_keyboard = {}}
			for group, link in pairs(config.help_groups) do
				if link then
					local line = {{text = group, url = link}}
					table.insert(keyboard.inline_keyboard, line)
				end
			end
			if next(keyboard.inline_keyboard) then
				if msg.cb then
					api.editMessageText(msg.chat.id, msg.message_id, _("انتخاب یک گروه:"), keyboard, true)
				else
					api.sendKeyboard(msg.chat.id, _("انتخاب یک گروه:"), keyboard, true)
				end
			end
		end
	end
	if blocks[1] == 'strings' then
		keyboard = doKeyboard_strings()
		
		api.sendKeyboard(msg.chat.id, _("*زبان خود را انتخاب کنید:*"), keyboard, true)
	end
	if blocks[1] == 'sendpo' then
		local lang = blocks[2]
		local instr_url = 'telegram.me/antispamer'
		local path = 'locales/'..lang..'.po'
		local button = {inline_keyboard = {{{text = _("دستورالعمل ها"), url = instr_url}}}}
		api.editMessageText(msg.chat.id, msg.message_id, _("درحال ارسال `%s.po` فایل..."):format(lang), button, true)
		api.sendDocument(msg.chat.id, path)
	end
end

return {
	action = action,
	triggers = {
		config.cmd..'(ping)$',
		config.cmd..'(strings)$',
		config.cmd..'(strings) (%a%a)$',
		config.cmd..'(echo) (.*)$',
		config.cmd..'(about)$',
		config.cmd..'(groups)$',
		'^/start (groups)$',
		
		'^###cb:fromhelp:(about)$',
		'^###cb:private:(groups)$',
		'^###cb:(sendpo):(.*)$',
	}
}