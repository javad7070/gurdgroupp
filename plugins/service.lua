local function action(msg, blocks)
	
	if not msg.service then return end
	
	if blocks[1] == 'botadded' then
		
		if misc.is_blocked_global(msg.adder.id) then
			api.sendMessage(msg.chat.id, '_You (user ID: '..msg.adder.id..') در لیست مسدود هستند_', true)
			api.leaveChat(msg.chat.id)
			return
		end
		if msg.chat.type == 'group' then
			api.sendMessage(msg.chat.id, '_متاسفم من فقط در سوپر گروه ها کار میکنم_', true)
			api.leaveChat(msg.chat.id)
			return
		end
		if config.bot_settings.admin_mode and not roles.is_superadmin(msg.adder.id) then
			api.sendMessage(msg.chat.id, '_مدیریت: تنها مدیر گروه میتواند من را در گروه اضافه کند_', true)
			api.leaveChat(msg.chat.id)
			return
		end
		
		misc.initGroup(msg.chat.id)
	end
	if blocks[1] == 'botremoved' then
		misc.remGroup(msg.chat.id, nil, 'bot removed')
	end
	if blocks[1] == 'removed' then
		if msg.remover and msg.removed then
			if msg.remover.id ~= msg.removed.id and msg.remover.id ~= bot.id then
				if msg.chat.type == 'supergroup' then
					misc.saveBan(msg.removed.id, 'ban')
				end
			end
		end
	end
end

return {
	action = action,
	triggers = {
		'^###(botadded)',
		'^###(botremoved)',
		'^###(removed)'
	}
}
