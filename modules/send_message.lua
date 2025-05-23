-- Модуль для отправки сообщений
-- Этот модуль предназначен для отправки сообщений пользователю
-- и может быть расширен для поддержки различных мессенджеров

local function sendMessage(message)
    -- Здесь будет реализация отправки сообщений через Telegram
    -- В базовой версии просто выводим сообщение в консоль
    print("[ROUTER_BOT]: " .. message)
    
    -- В будущем, когда будет добавлена интеграция с Telegram:
    -- local telegram = require("modules.telegram")
    -- telegram.send(message)
end

return sendMessage
