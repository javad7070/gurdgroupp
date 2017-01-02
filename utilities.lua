-- utilities.lua
-- Functions shared among plugins.

local misc = {}
local roles = {}

function misc.get_word(s, i) -- get the indexed word in a string

	s = s or ''
	i = i or 1

	local t = {}
	for w in s:gmatch('%g+') do
		table.insert(t, w)
	end

	return t[i] or false

end

function string:input() -- Returns the string after the first space.
	if not self:find(' ') then
		return false
	end
	return self:sub(self:find(' ')+1)
end

function string:escape()
	if not self then return false end
	self = self:gsub('*', '\\*'):gsub('_', '\\_'):gsub('`', '\\`'):gsub('%]', '\\]'):gsub('%[', '\\[')
	return self
end

function string:escape_hard() -- Remove the markdown.
	self = self:gsub('*', ''):gsub('_', ''):gsub('`', ''):gsub('%[', ''):gsub('%]', '')
	return self
end

function roles.is_superadmin(user_id) --if real owner is true, the function will return true only if msg.from.id == config.admin.owner
	for i=1, #config.superadmins do
		if tonumber(user_id) == config.superadmins[i] then
			return true
		end
	end
	return false
end

function roles.bot_is_admin(chat_id)
	local status = api.getChatMember(chat_id, bot.id).result.status
	if not(status == 'administrator') then
		return false
	else
		return true
	end
end

function roles.is_admin(msg)
	local res = api.getChatMember(msg.chat.id, msg.from.id)
	if not res then
		return false, false
	end
	local status = res.result.status
	if status == 'creator' or status == 'administrator' then
		return true, true
	else
		return false, true
	end
end

function roles.is_admin_cached(msg)
	local hash = 'cache:chat:'..msg.chat.id..':admins'
	if not db:exists(hash) then
		misc.cache_adminlist(msg.chat.id, res)
	end
	return db:sismember(hash, msg.from.id)
end

function roles.is_admin2(chat_id, user_id)
	local res = api.getChatMember(chat_id, user_id)
	if not res then
		return false, false
	end
	local status = res.result.status
	if status == 'creator' or status == 'administrator' then
		return true, true
	else
		return false, true
	end
end

function roles.is_owner(msg)
	local status = api.getChatMember(msg.chat.id, msg.from.id).result.status
	if status == 'creator' then
		return true
	else
		return false
	end
end

function roles.is_owner2(chat_id, user_id)
	local status = api.getChatMember(chat_id, user_id).result.status
	if status == 'creator' then
		return true
	else
		return false
	end
end

function misc.cache_adminlist(chat_id)
	local res, code = api.getChatAdministrators(chat_id)
	if not res then
		return false, code
	end
	local hash = 'cache:chat:'..chat_id..':admins'
	for _, admin in pairs(res.result) do
		db:sadd(hash, admin.user.id)
	end
	db:expire(hash, config.bot_settings.cache_time.adminlist)
	return true
end

function misc.is_blocked_global(id)
	if db:sismember('bot:blocked', id) then
		return true
	else
		return false
	end
end

function string:trim() -- Trims whitespace from a string.
	local s = self:gsub('^%s*(.-)%s*$', '%1')
	return s
end

function load_data(filename) -- Loads a JSON file as a table.

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data) -- Saves a table to a JSON file.

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

function vardump(value)
  print(serpent.block(value, {comment=false}))
end

function vtext(value)
  return serpent.block(value, {comment=false})
end

function misc.deeplink_constructor(chat_id, what)
	return 'telegram.me/'..bot.username..'?start='..chat_id..':'..what
end

function misc.clone_table(t) --doing "table1 = table2" in lua = create a pointer to table2
  local new_t = {}
  local i, v = next(t, nil)
  while i do
    new_t[i] = v
    i, v = next(t, i)
  end
  return new_t
end

function misc.remove_duplicates(t)
	if type(t) ~= 'table' then
		return false, 'Table expected, got '..type(t)
	else
		local kv_table = {}
		for i, element in pairs(t) do
			if not kv_table[element] then
				kv_table[element] = true
			end
		end
		
		local k_table = {}
		for key, boolean in pairs(kv_table) do
			k_table[#k_table + 1] = key
		end
		
		return k_table
	end
end

function misc.get_date(timestamp)
	if not timestamp then
		timestamp = os.time()
	end
	return os.date('%d/%m/%y')
end

-- Resolves username. Returns ID of user if it was early stored in date base.
-- Argument username must begin with symbol @ (commercial 'at')
function misc.resolve_user(username)
	assert(username:byte(1) == string.byte('@'))

	local stored_id = db:hget('bot:usernames', username:lower())
	if not stored_id then return false end
	local user_obj = api.getChat(stored_id)
	if not user_obj then return stored_id end

	-- User could change his username. Update it
	db:hset('bot:usernames', username:lower(), user_obj.result.id)
	return user_obj.result.id
end

function misc.write_file(path, text, mode)
	if not mode then
		mode = "w"
	end
	file = io.open(path, mode)
	if not file then
		misc.create_folder('logs')
		file = io.open(path, mode)
		if not file then
			return false
		end
	end
	file:write(text)
	file:close()
	return true
end

function misc.save_br(code, text)
	text = os.date('[%A, %d %B %Y at %X]')..', code: ['..code..']\n'..text
	local path = "./msgs_errors.txt"
	local res = misc.write_file(path, text, "a")
end

function misc.get_media_type(msg)
	if msg.photo then
		return 'image'
	elseif msg.video then
		return 'video'
	elseif msg.audio then
		return 'audio'
	elseif msg.voice then
		return 'voice'
	elseif msg.document then
		if msg.document.mime_type == 'video/mp4' then
			return 'gif'
		else
			return 'file'
		end
	elseif msg.sticker then
		return 'sticker'
	elseif msg.contact then
		return 'contact'
	end
	return false
end

function misc.get_media_id(msg)
	if msg.photo then
		if msg.photo[3] then
			return msg.photo[3].file_id, 'photo'
		else
			if msg.photo[2] then
				return msg.photo[2].file_id, 'photo'
			else
				if msg.photo[1] then
					return msg.photo[1].file_id, 'photo'
				else
					return msg.photo.file_id, 'photo'
				end
			end
		end
	elseif msg.document then
		return msg.document.file_id
	elseif msg.video then
		return msg.video.file_id, 'video'
	elseif msg.audio then
		return msg.audio.file_id
	elseif msg.voice then
		return msg.voice.file_id, 'voice'
	elseif msg.sticker then
		return msg.sticker.file_id
	else
		return false, 'پیام یک file_id رسانه'
	end
end

function misc.migrate_chat_info(old, new, on_request)
	if not old or not new then
		return false
	end
	
	for hash_name, hash_content in pairs(config.chat_settings) do
		local old_t = db:hgetall('chat:'..old..':'..hash_name)
		if next(old_t) then
			for key, val in pairs(old_t) do
				db:hset('chat:'..new..':'..hash_name, key, val)
			end
		end
	end
	
	for _, hash_name in pairs(config.chat_custom_texts) do
		local old_t = db:hgetall('chat:'..old..':'..hash_name)
		if next(old_t) then
			for key, val in pairs(old_t) do
				db:hset('chat:'..new..':'..hash_name, key, val)
			end
		end
	end
	
	if on_request then
		api.sendReply(msg, 'باید انجام بشه')
	end
end

function string:replaceholders(msg) -- Returns the string after the first space.
	if msg.added then
		msg.from = msg.added
	end
	
	msg.from.first_name = msg.from.first_name:gsub('%%', '')
	
	self = self:gsub('$name', msg.from.first_name:escape())
	if msg.from.username then
		self = self:gsub('$username', '@'..msg.from.username:escape())
	else
		self = self:gsub('$username', '@-')
	end
	if msg.from.last_name then
		self = self:gsub('$surname', '@'..msg.from.last_name:escape())
	else
		self = self:gsub('$surname', '-')
	end
	self = self:gsub('$id', msg.from.id)
	self = self:gsub('$title', msg.chat.title:escape())
	self = self:gsub('$rules', misc.deeplink_constructor(msg.chat.id, 'rules'))
	return self
end

function misc.to_supergroup(msg)
	local old = msg.chat.id
	local new = msg.migrate_to_chat_id
	local done = misc.migrate_chat_info(old, new, false)
	if done then
		misc.remGroup(old, true, 'to supergroup')
		api.sendMessage(new, '(_اطلاع رسانی خدمات: مهاجرت از گروه اجرا_)', true)
	end
end

function div()
	print('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX')
	print('XXXXXXXXXXXXXXXXXX BREAK XXXXXXXXXXXXXXXXXXX')
	print('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX')
end

function misc.getname(msg)
    local name = msg.from.first_name
	if msg.from.username then name = name..' (@'..msg.from.username..')' end
    return name
end

function misc.getname_final(user)
	return misc.getname_link(user.first_name, user.username) or '`'..user.first_name:escape()..'`'
end

function misc.getname_id(msg)
    return msg.from.first_name..' ('..msg.from.id..')'
end

function misc.getname_link(name, username)
	if not name or not username then return false end
	username = username:gsub('@', '')
	return '['..name..'](https://telegram.me/'..username..')'
end

function misc.bash(str)
	local cmd = io.popen(str)
    local result = cmd:read('*all')
    cmd:close()
    return result
end

function misc.download_to_file(url, file_path)--https://github.com/yagop/telegram-bot/blob/master/bot/utils.lua
  --print("url to download: "..url)

  local respbody = {}
  local options = {
    url = url,
    sink = ltn12.sink.table(respbody),
    redirect = true
  }
  -- nil, code, headers, status
  local response = nil
    options.redirect = false
    response = {HTTPS.request(options)}
  local code = response[2]
  local headers = response[3]
  local status = response[4]
  if code ~= 200 then return false, code end

  print("ذخیره شده به: "..file_path)

  file = io.open(file_path, "w+")
  file:write(table.concat(respbody))
  file:close()
  return file_path, code
end

function misc.telegram_file_link(res)
	--res = table returned by getFile()
	return "https://api.telegram.org/file/bot"..config.bot_api_key.."/"..res.result.file_path
end

function misc.is_silentmode_on(chat_id)
	local hash = 'chat:'..chat_id..':settings'
	local res = db:hget(hash, 'Silent')
	if res and res == 'on' then
		return true
	else
		return false
	end
end

function misc.getRules(chat_id)
	local hash = 'chat:'..chat_id..':info'
	local rules = db:hget(hash, 'rules')
    if not rules then
        return _("*.هنوز قوانینی ثبت نشده است*")
    else
       	return rules
    end
end

function misc.getAdminlist(chat_id)
	local list, code = api.getChatAdministrators(chat_id)
	if not list then
		if code == 107 then
			return false, code
		else
			return false, false
		end
	end
	local creator = ''
	local adminlist = ''
	local count = 1
	for i,admin in pairs(list.result) do
		local name
		if admin.status == 'administrator' then
			name = admin.user.first_name
			if admin.user.username then
				if name:find('%]') or name:find('%[') then
					name = name:gsub('%]', ')'):gsub('%[', '(')
				end
				name = '['..name..'](https://telegram.me/'..admin.user.username..')'
			else
				name = name:escape()
			end
			adminlist = adminlist..'*'..count..'* - '..name..'\n'
			count = count + 1
		elseif admin.status == 'creator' then
			creator = admin.user.first_name
			if admin.user.username then
				if creator:find('%]') or creator:find('%[') then
					creator = creator:gsub('%]', ')'):gsub('%[', '(')
				end
				creator = '['..creator..'](https://telegram.me/'..admin.user.username..')'
			else
				creator = creator:escape()
			end
		end
	end
	if adminlist == '' then adminlist = '-' end
	if creator == '' then creator = '-' end
	return creator, adminlist
end

function misc.getExtraList(chat_id)
	local hash = 'chat:'..chat_id..':extra'
	local commands = db:hkeys(hash)
	local text = ''
	if commands[1] == nil then
		return _("دستورات تنظیم نشده است")
	else
	    for k,v in pairs(commands) do
	    	text = text..v..'\n'
	    end
	    return _("فهرست * دستورات سفارشی *:\n") .. text
	end
end

function misc.getSettings(chat_id)
    local hash = 'chat:'..chat_id..':settings'
        
    local message = _("تنظیمات فعلی * گروه *:\n\n")
			.. _("*زبان ها*: `%s`\n"):format(locale.language)
        
    --build the message
	local strings = {
		Welcome = _("پیام خوش آمد"),
		Extra = _("تگ"),
		Flood = _("ضداسپم"),
		Antibot = _("مسدود ربات ها"),
		Silent = _("حالت بی صدا"),
		Rules = _("قوانین"),
		Arab = _("عرب"),
		Rtl = _("راست نویس"),
	}
    for key, default in pairs(config.chat_settings['settings']) do
        
        local off_icon, on_icon = '🚫', '✅'
        if misc.is_info_message_key(key) then
        	off_icon, on_icon = '👤', '👥'
        end
        
        local db_val = db:hget(hash, key)
        if not db_val then db_val = default end
        
        if db_val == 'off' then
            message = message .. string.format('%s: %s\n', strings[key], off_icon)
        else
            message = message .. string.format('%s: %s\n', strings[key], on_icon)
        end
    end
    
    --build the char settings lines
    hash = 'chat:'..chat_id..':char'
    off_icon, on_icon = '🚫', '✅'
    for key, default in pairs(config.chat_settings['char']) do
    	db_val = db:hget(hash, key)
        if not db_val then db_val = default end
    	if db_val == 'off' then
            message = message .. string.format('%s: %s\n', strings[key], off_icon)
        else
            message = message .. string.format('%s: %s\n', strings[key], on_icon)
        end
    end
    	
    --build the "welcome" line
    hash = 'chat:'..chat_id..':welcome'
    local type = db:hget(hash, 'type')
    if type == 'media' then
		message = message .. _("*نوع خوش آمدید*: `گیف, استیکر`\n")
	elseif type == 'custom' then
		message = message .. _("*نوع خوش آمدید*: `پیام های سفارشی`\n")
	elseif type == 'no' then
		message = message .. _("*نوع خوش آمدید*: `پیام پیش فرض`\n")
	end
    
    local warnmax_std = (db:hget('chat:'..chat_id..':warnsettings', 'max')) or config.chat_settings['warnsettings']['max']
    local warnmax_media = (db:hget('chat:'..chat_id..':warnsettings', 'mediamax')) or config.chat_settings['warnsettings']['mediamax']
    
	return message .. _("اخطارها: *%s*\n"):format(warnmax_std)
				 .. _("اخطارها (`رسانه`): *%s*\n\n"):format(warnmax_media)
				 .. _("✅ = _فعال / مجاز_\n")
				 .. _("🚫 = _غیرفعال / غیرمجاز_\n")
				 .. _("👥 = _فرستاده شده در گروه (همیشه برای مدیران)_\n")
				 .. _("👤 = _فرستاده شده در خصوصی_")

end

function misc.changeSettingStatus(chat_id, field)
	local turned_off = {
		 welcome = _("پیام خوش آمد از هم اکنون نشان داده نمیشود"),
		 extra = _("دستورات تگ تنها برای ناظران در دسترس است"),
		 flood = _("ضد اسپم هم اکنون غیرفعال است"),
		 rules = _("`/rules` در خصوصی پاسخ داده خواهد شد (برای همه کاربران)"),
		 antibot = _("اگر کسی ربات اضافه کند اخراج نمیشود")
	}
	local turned_on = {
		 welcome = _("پیام خوش آمد از هم اکنون نشان داده میشود"),
		 extra = _("دستورات تگ برای همه در دسترس است"),
		 flood = _("ضد اسپم هم اکنون فعال است"),
		 rules = _("`/rules` در گروه پاسخ داده خواهد شد (برای همه)"),
		 antibot = _("اگر کسی ربات اضافه کند اخراج میشود")
	}

	local hash = 'chat:'..chat_id..':settings'
	local now = db:hget(hash, field)
	if now == 'on' then
		db:hset(hash, field, 'off')
		return turned_off[field:lower()]
	else
		db:hset(hash, field, 'on')
		return turned_on[field:lower()]
	end
end

function misc.changeFloodSettings(chat_id, screm)
	local hash = 'chat:'..chat_id..':flood'
	if type(screm) == 'string' then
		if screm == 'kick' then
			db:hset(hash, 'ActionFlood', 'ban')
        	return _("هم اکنون با اسپم مسدود میشوند")
        elseif screm == 'ban' then
        	db:hset(hash, 'ActionFlood', 'kick')
        	return _("هم اکنون با اسپم اخراج میشوند")
        end
    elseif type(screm) == 'number' then
    	local old = tonumber(db:hget(hash, 'MaxFlood')) or 5
    	local new
    	if screm > 0 then
    		new = db:hincrby(hash, 'MaxFlood', 1)
    		if new > 25 then
    			db:hincrby(hash, 'MaxFlood', -1)
    			return _("%d یک مقدار معتبر نیست!\n"):format(new)
					.. ("_میزان باید کمتر از26و بالای3باشد.اشتباه است_")
    		end
    	elseif screm < 0 then
    		new = db:hincrby(hash, 'MaxFlood', -1)
    		if new < 4 then
    			db:hincrby(hash, 'MaxFlood', 1)
    			return _("%d یک مقدار معتبر نیست!\n"):format(new)
					.. ("_میزان باید کمتر از26و بالای3باشد.اشتباه است_")
    		end
    	end
    	return string.format('%d → %d', old, new)
    end 	
end

function misc.changeMediaStatus(chat_id, media, new_status)
	local old_status = db:hget('chat:'..chat_id..':media', media)
	local new_status_icon
	if new_status == 'next' then
		if not old_status then
			new_status = 'ok'
			new_status_icon = '✅'
		elseif old_status == 'ok' then
			new_status = 'notok'
			new_status_icon = '❌'
		elseif old_status == 'notok' then
			new_status = 'ok'
			new_status_icon = '✅'
		end
	end
	db:hset('chat:'..chat_id..':media', media, new_status)
	return _("وضعیت جدید = %s"):format(new_status_icon), true
end

function misc.sendStartMe(msg, ln)
    local keyboard = {inline_keyboard = {{{text = _("من را ارستارت کن"), url = 'https://telegram.me/'..bot.username}}}}
	api.sendKeyboard(msg.chat.id, _("_لطفا به من یک پیام ارسال کنید_"), keyboard, true)
end

function misc.initGroup(chat_id)
	
	for set, setting in pairs(config.chat_settings) do
		local hash = 'chat:'..chat_id..':'..set
		for field, value in pairs(setting) do
			db:hset(hash, field, value)
		end
	end
	
	misc.cache_adminlist(chat_id, api.getChatAdministrators(chat_id)) --init admin cache
	
	--save group id
	db:sadd('bot:groupsid', chat_id)
	--remove the group id from the list of dead groups
	db:srem('bot:groupsid:removed', chat_id)
end

function misc.remGroup(chat_id, full, call)
	--remove group id
	db:srem('bot:groupsid', chat_id)
	--add to the removed groups list
	db:sadd('bot:groupsid:removed', chat_id)
	
	for set,field in pairs(config.chat_settings) do
		db:del('chat:'..chat_id..':'..set)
	end
	
	db:del('cache:chat:'..chat_id..':admins') --delete the cache
	db:hdel('bot:logchats', chat_id) --delete the associated log chat
	db:del('chat:'..chat_id..':pin') --delete the msg id of the (maybe) pinned message
	
	if full then
		for i, set in pairs(config.chat_custom_texts) do
			db:del('chat:'..chat_id..':'..set)
		end
		db:del('lang:'..chat_id)
	end
	
	local msg_text = '#حذف شده '..chat_id
	if full then
		msg_text = msg_text..'\nfull: true'
	else
		msg_text = msg_text..'\nfull: false'
	end
	if call then msg_text = msg_text..'\ncall: '..call end
	api.sendAdmin(msg_text)
end

function misc.getnames_complete(msg, blocks)
	local admin, kicked
	
	if msg.from.username then
		admin = misc.getname_link(msg.from.first_name, msg.from.username)
	else
		admin = '`'..msg.from.first_name:escape()..'`'
	end
	
	if msg.reply then
		if msg.reply.from.username then
			kicked = misc.getname_link(msg.reply.from.first_name, msg.reply.from.username)
		else
			kicked = '`'..msg.reply.from.first_name:escape()..'`'
		end
	elseif msg.text:match(config.cmd..'%w%w%w%w?%w?%s(@[%w_]+)%s?') then
		local username = msg.text:match('%s(@[%w_]+)')
		kicked = username:escape()
	elseif msg.mention_id then
		for _, entity in pairs(msg.entities) do
			if entity.user then
				kicked = '`'..entity.user.first_name:escape()..'`'
			end
		end
	elseif msg.text:match(config.cmd..'%w%w%w%w?%w?%s(%d+)') then
		local id = msg.text:match(config.cmd..'%w%w%w%w?%w?%s(%d+)')
		kicked = '`'..id..'`'
	end
	
	return admin, kicked
end

function misc.get_user_id(msg, blocks)
	--if no user id: returns false and the msg id of the translation for the problem
	if not msg.reply and not blocks[2] then
		return false, "_لطفا روی کاربر مورد نظر ریپلای کنید_"
	else
		if msg.reply then
			return msg.reply.from.id
		elseif msg.text:match(config.cmd..'%w%w%w%w?%w?%w?%s(@[%w_]+)%s?') then
			local username = msg.text:match('%s(@[%w_]+)')
			local id = misc.resolve_user(username)
			if not id then
				return false, "من هرگز این کاربر را مشاهده نکرده ام\n"
					.. ".اگر حس میکنید من او را مشاهده کرده ام یک پیام از او برای من فروارد کنید"
			else
				return id
			end
		elseif msg.mention_id then
			return msg.mention_id
		elseif msg.text:match(config.cmd..'%w%w%w%w?%w?%w?%s(%d+)') then
			local id = msg.text:match(config.cmd..'%w%w%w%w?%w?%w?%s(%d+)')
			return id
		else
			return false, "من هرگز این کاربر را مشاهده نکرده ام\n"
					.. ".اگر حس میکنید من او را مشاهده کرده ام یک پیام از او برای من فروارد کنید"
		end
	end
end

function misc.logEvent(event, msg, blocks, extra)
	local log_id = db:hget('bot:chatlogs', msg.chat.id)
	
	if not log_id then return end
	--if not is_loggable(msg.chat.id, event) then return end
	
	local text
	if event == 'ban' then
		local admin, banned = misc.getnames_complete(msg, blocks)
		local admin_id, banned_id = msg.from.id, misc.get_user_id(msg, blocks)
		if admin and banned and admin_id and banned_id then
			text = '#مسدود\n*مدیر*: '..admin..'  #'..admin_id..'\n*کاربر*: '..banned..'  #'..banned_id
			if extra.motivation then
				text = text..'\n\n> _'..extra.motivation:escape()..'_'
			end
		end
	end
	if event == 'kick' then
		local admin, kicked = misc.getnames_complete(msg, blocks)
		local admin_id, kicked_id = msg.from.id, misc.get_user_id(msg, blocks)
		if admin and kicked and admin_id and kicked_id then
			text = '#اخراج\n*مدیر*: '..admin..'  #'..admin_id..'\n*کاربر*: '..banned..'  #'..banned_id
			if extra.motivation then
				text = text..'\n\n> _'..extra.motivation:escape()..'_'
			end
		end
	end
	if event == 'join' then
		local member = misc.getname_link(msg.added.first_name, msg.added.username) or '`'..msg.added.first_name:escape()..'`'
		text = '#کاربرجدید\n'..member.. '  #'..msg.added.id
	end
	if event == 'warn' then
		local admin, warned = misc.getnames_complete(msg, blocks)
		local admin_id, warned_id = msg.from.id, misc.get_user_id(msg, blocks)
		if admin and warned and admin_id and warned_id then
			text = '#اخطار ('..extra.warns..'/'..extra.warnmax..') ('..type..')\n*مدیر*: '..admin..'  #'..admin_id..']\n*کاربر*: '..banned..'  #'..banned_id..']'
			if extra.motivation then
				text = text..'\n\n> _'..extra.motivation:escape()..'_'
			end
		end
	end
	if event == 'mediawarn' then
		local name = misc.getname_link(msg.from.first_name, msg.from.username) or '`'..msg.from.first_name:escape()..'`'
		text = '#اخطار رسانه ('..extra.warns..'/'..extra.warnmax..') '..extra.media..'\n'..name..'  #'..msg.from.id
		if extra.hammered then
			text = text..'\n*'..extra.hammered..'*'
		end
	end
	if event == 'flood' then
		local name = misc.getname_link(msg.from.first_name, msg.from.username) or '`'..msg.from.first_name:escape()..'`'
		text = '#اسپم\n'..name..'  #'..msg.from.id
		if extra.hammered then
			text = text..'\n*'..extra.hammered..'*'
		end
	end
	
	if text then
		api.sendMessage(log_id, text, true)
	end
end

function misc.getUserStatus(chat_id, user_id)
	local res = api.getChatMember(chat_id, user_id)
	if res then
		return res.result.status
	else
		return false
	end
end

function misc.saveBan(user_id, motivation)
	local hash = 'ban:'..user_id
	return db:hincrby(hash, motivation, 1)
end

function misc.is_info_message_key(key)
    if key == 'Extra' or key == 'Rules' then
        return true
    else
        return false
    end
end

function misc.table2keyboard(t)
	local keyboard = {inline_keyboard = {}}
    for i, line in pairs(t) do
        if type(line) ~= 'table' then return false, '.ساختار اشتباه است' end
        local new_line ={}
        for k,v in pairs(line) do
            if type(k) ~= 'string' then return false, '.ساختار اشتباه است' end
            local button = {}
            button.text = k
            button.callback_data = v
            table.insert(new_line, button)
        end
        table.insert(keyboard.inline_keyboard, new_line)
    end
    
    return keyboard
end

return misc, roles
