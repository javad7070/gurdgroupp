local function report(msg)
    local text = _('• *پیام گزارش شده توسط*: %s (`%d`)\n• *گروه*: %s'):format(misc.getname_final(msg.from), msg.from.id, msg.chat.title:escape())
    if msg.reply.sticker then
        text = text.._('\n• *استیکر ارسال شده توسط*: %s (`%d`)'):format(misc.getname_final(msg.reply.from), msg.reply.from.id)
    end
    if msg.chat.username then
        text = text.._('\n• [برو به پیام](%s)'):format('telegram.me/'..msg.chat.username..'/'..msg.message_id)
    end
    local description = msg.text:match('^@admin (.*)')
    if description then
        text = text.._('\n• *عنوان*: %s'):format(description:escape())
    end
    
    local res = api.getChatAdministrators(msg.chat.id)
    if not res then return false end
    
    local n = 0
    for i, admin in pairs(res.result) do
        local receive_reports = db:hget('user:'..admin.user.id..':settings', 'reports')
        if receive_reports and receive_reports == 'on' then
            local res_fwd = api.forwardMessage(admin.user.id, msg.chat.id, msg.reply.message_id)
            if res_fwd then
                api.sendMessage(admin.user.id, text, true, res_fwd.result.message_id)
                n = n + 1
            end
        end
    end 
    return n
end

local function action(msg, blocks)
    if msg.chat.type == 'private' or roles.is_admin_cached(msg) or not msg.reply then return end
    if roles.is_admin_cached(msg.reply) then return end
    local status = (db:hget('chat:'..msg.chat.id..':settings', 'Reports')) or config.chat_settings['settings']['Reports']
    if not status or status == 'off' then return end
    
    local n_sent = report(msg)
    if n_sent then
        api.sendReply(msg, _('_گزارش به %d مدیر(s)_'):format(n_sent), true)
    end
end

return {
    action = action,
    triggers = {
        '^@admin'
    }
}