local function action(msg, blocks)
    if blocks[1] == 'pin' then
		if roles.is_admin_cached(msg) then
		    if not blocks[2] then
		        local pin_id = db:get('chat:'..msg.chat.id..':pin')
		        if pin_id then
		            api.sendMessage(msg.chat.id, _('آخرین پیام های تولید شده ^'), true, pin_id)
		        end
		        return
		    end
			local res, code = api.sendMessage(msg.chat.id, blocks[2]:gsub('$rules', misc.deeplink_constructor(msg.chat.id, 'rules')), true)
			if not res then
				if code == 118 then
				    api.sendMessage(msg.chat.id, _("_این متن طولانی است من نمیتوانم آن را ارسال کنم_"))
			    else
					api.sendMessage(msg.chat.id, _(".این مدل نشانه گذاری صحیح نیست\n"
						.. "اگر مشکلی دارید به مدیر ربات پیام بدید "
						.. "[مدیر ربات](https://telegram.me/javad7070)."), true)
		    	end
	    	else
	    		db:set('chat:'..msg.chat.id..':pin', res.result.message_id)
	    		api.sendMessage(msg.chat.id, _("_/editpin پیام پین شده ثبت شد.شما میتوانید با ارسال دستور بالا پیام پین شده را ویرایش کنید بدون اینکه متن جدیدی برای پین ارسال کنید_"), true, res.result.message_id)
	    	end
    	end
	end
	if blocks[1] == 'editpin' then
		if roles.is_admin_cached(msg) then
			local pin_id = db:get('chat:'..msg.chat.id..':pin')
			if not pin_id then
				api.sendReply(msg, _("متن خو را ارسال کنید `/pinشما هیچ پیام پین شده ای ندارید با ارسال دستور`"), true)
			else
				local res, code = api.editMessageText(msg.chat.id, pin_id, blocks[2]:gsub('$rules', misc.deeplink_constructor(msg.chat.id, 'rules')), nil, true)
				if not res then
					if code == 118 then
				    	api.sendMessage(msg.chat.id, _("_این متن طولانی است من نمیتوانم آن را ارسال کنم_"))
				    elseif code == 116 then
				    	api.sendMessage(msg.chat.id, _("_این پیش نمایش پیامی هست که من فرستادم من هنوز میتونم اونو ویرایش کنم_"), true)
				    elseif code == 111 then
				    	api.sendMessage(msg.chat.id, _("_متن اصلاح شده نیست_"), true)
			    	else
						api.sendMessage(msg.chat.id, _(".این مدل نشانه گذاری صحیح نیست\n"
							.. "اگر مشکلی دارید به مدیر ربات پیام بدید"
							.. "[مدیر ربات](https://telegram.me/javad7070)."), true)
		    		end
		    	else
		    		db:set('chat:'..msg.chat.id..':pin', res.result.message_id)
	    			api.sendMessage(msg.chat.id, _("پیام با موفقیت ویرایش شد"), nil, pin_id)
	    		end
	    	end
    	end
    end
end

return {
    action = action,
    triggers = {
        config.cmd..'(pin)$',
        config.cmd..'(pin) (.*)$',
		config.cmd..'(editpin) (.*)$',
	}
}
