#!/usr/bin/lua

-- Простой бот для тестирования
local config = require("config")
local telegram = require("modules.telegram_simple")  -- Используем простой модуль
local system = require("modules.system")
local vpn = require("modules.vpn")
local wake_pc = require("modules.wake_pc")
local speedTest = require("modules.speed_test")
local vlessManager = require("modules.config_manager.vless")
local domainsManager = require("modules.config_manager.domains")

-- Проверка, разрешен ли пользователь
local function isUserAllowed(user_id)
    if not user_id then return false end
    
    for _, allowed_id in ipairs(config.allowed_users) do
        if tonumber(user_id) == tonumber(allowed_id) then
            return true
        end
    end
    
    return false
end

-- Обработка команд от пользователя
-- Декодирование JSON данных из WebApp
local json = require("modules.json")

local function processCommand(message)
    -- Проверка корректности сообщения
    if not message or not message.chat or not message.from then
        print("[DEBUG] Некорректное сообщение, пропускаем")
        return
    end
    
    -- Обработка данных из Telegram Mini App
    if message.web_app_data then
        print("[DEBUG] Получены данные из WebApp: " .. message.web_app_data.data)
        
        local success, data = pcall(function() 
            return json.decode(message.web_app_data.data) 
        end)
        
        if success and data and data.command then
            -- Перенаправляем команду на обработку
            print("[DEBUG] Обработка команды из WebApp: " .. data.command)
            message.text = data.command
            
            -- Сохраняем дополнительные параметры
            message.params = data.params or {}
        else
            print("[DEBUG] Ошибка при обработке данных WebApp")
            telegram.send_message(message.chat.id, "❗ Ошибка при обработке данных из мини-приложения")
            return
        end
    end
    
    -- Проверка наличия текста сообщения после обработки WebApp
    if not message.text then
        print("[DEBUG] Отсутствует текст сообщения")
        return
    end
    
    local chat_id = message.chat.id
    local user_id = message.from.id
    local text = message.text
    
    print("[DEBUG] Обработка сообщения - Чат ID: " .. tostring(chat_id) .. 
          ", Пользователь ID: " .. tostring(user_id) .. 
          ", Текст: " .. tostring(text))
    
    -- Проверка доступа
    if not isUserAllowed(user_id) then
        print("[DEBUG] Отказ в доступе пользователю: " .. tostring(user_id))
        telegram.send_message(chat_id, "⛔ У вас нет доступа к этому боту.")
        return
    end
    
    -- Обработка команд
    if text == "/start" or text == "/help" then
        local help_text = "Команды управления роутером:\n" ..
                         "/reboot - перезагрузка роутера\n" ..
                         "/restart_network - перезапуск сети\n" ..
                         "/wake_pc - включить ПК\n" ..
                         "/vpn_start - запустить VPN\n" ..
                         "/vpn_stop - остановить VPN\n" ..
                         "/vpn_status - статус VPN\n" ..
                         "/speed_test - проверить скорость интернета\n\n" ..
                         
                         "Управление VPN конфигурациями:\n" ..
                         "/get_vless - получить текущий VLESS конфиг\n" ..
                         "/list_configs - список сохраненных конфигов\n" ..
                         "/save_vless имя конфиг - сохранить конфигурацию\n" ..
                         "/activate_vless имя - активировать конфигурацию\n\n" ..
                         
                         "Управление доменами:\n" ..
                         "/get_domains - получить список доменов\n" ..
                         "/add_domain домен - добавить домен\n" ..
                         "/remove_domain домен - удалить домен"
                         
        telegram.send_message(chat_id, help_text)
        
    elseif text == "/reboot" then
        telegram.send_message(chat_id, "🔄 Выполняется перезагрузка роутера...")
        system.reboot()
        
    elseif text == "/restart_network" then
        telegram.send_message(chat_id, "🔄 Выполняется перезапуск сетевого сервиса...")
        system.restartNetwork()
        telegram.send_message(chat_id, "✅ Сетевой сервис перезапущен")
        
    elseif text == "/wake_pc" then
        telegram.send_message(chat_id, "🖥️ Отправка WoL пакета...")
        wake_pc()
        telegram.send_message(chat_id, "✅ Запрос на запуск компьютера отправлен")
        
    elseif text == "/vpn_start" then
        telegram.send_message(chat_id, "🔄 Запуск VPN...")
        vpn.start()
        telegram.send_message(chat_id, "✅ VPN запущен")
        
    elseif text == "/vpn_stop" then
        telegram.send_message(chat_id, "🔄 Остановка VPN...")
        vpn.stop()
        telegram.send_message(chat_id, "✅ VPN остановлен")
        
    elseif text == "/vpn_status" then
        local status = vpn.status()
        telegram.send_message(chat_id, "📊 Статус VPN:\n" .. status)
        
    elseif text == "/speed_test" then
        telegram.send_message(chat_id, "🔄 Запуск проверки скорости интернета...")
        local result = speedTest.run()
        telegram.send_message(chat_id, result)
        
    -- Команды управления VPN конфигурациями
    elseif text == "/get_vless" then
        local current_config = vlessManager.getCurrentConfig()
        telegram.send_message(chat_id, "📋 Текущий VLESS конфиг:\n" .. current_config)
        
    elseif text == "/list_configs" then
        local configs = vlessManager.getAllConfigs()
        local response = "📋 Список сохраненных конфигураций:\n\n"
        
        local found = false
        for name, config_data in pairs(configs) do
            found = true
            local status = config_data.active and "✅ Активен" or "❌ Неактивен"
            response = response .. name .. " - " .. status .. "\n"
        end
        
        if not found then
            response = "❌ Нет сохраненных конфигураций"
        end
        
        telegram.send_message(chat_id, response)
        
    -- Команды управления доменами
    elseif text == "/get_domains" then
        local domains = domainsManager.getCurrentDomains()
        local response = "📋 Список доменов:\n\n"
        
        if #domains == 0 then
            response = "❌ Список доменов пуст"
        else
            for _, domain in ipairs(domains) do
                response = response .. "• " .. domain .. "\n"
            end
        end
        
        telegram.send_message(chat_id, response)
    
    elseif text:find("^/add_domain ") then
        local domain = text:match("^/add_domain (.+)$")
        if domain then
            local success = domainsManager.addDomain(domain)
            if success then
                telegram.send_message(chat_id, "✅ Домен '" .. domain .. "' добавлен")
            else
                telegram.send_message(chat_id, "❌ Домен '" .. domain .. "' уже существует в списке")
            end
        else
            telegram.send_message(chat_id, "❌ Неправильный формат. Используйте: /add_domain example.com")
        end
        
    elseif text:find("^/remove_domain ") then
        local domain = text:match("^/remove_domain (.+)$")
        if domain then
            local success = domainsManager.removeDomain(domain)
            if success then
                telegram.send_message(chat_id, "✅ Домен '" .. domain .. "' удален")
            else
                telegram.send_message(chat_id, "❌ Домен '" .. domain .. "' не найден в списке")
            end
        else
            telegram.send_message(chat_id, "❌ Неправильный формат. Используйте: /remove_domain example.com")
        end
        
    elseif text:find("^/save_vless ") then
        local name, vless_config = text:match("^/save_vless (%S+) (.+)$")
        if name and vless_config then
            local success = vlessManager.saveConfig(name, vless_config)
            if success then
                telegram.send_message(chat_id, "✅ Конфигурация '" .. name .. "' сохранена")
            else
                telegram.send_message(chat_id, "❌ Ошибка при сохранении конфигурации")
            end
        else
            telegram.send_message(chat_id, "❌ Неправильный формат. Используйте:\n/save_vless имя vless://...")
        end
        
    elseif text:find("^/activate_vless ") then
        local name = text:match("^/activate_vless (%S+)$")
        if name then
            local success = vlessManager.activateConfig(name)
            if success then
                telegram.send_message(chat_id, "✅ Конфигурация '" .. name .. "' активирована")
            else
                telegram.send_message(chat_id, "❌ Конфигурация '" .. name .. "' не найдена")
            end
        else
            telegram.send_message(chat_id, "❌ Неправильный формат. Используйте: /activate_vless имя")
        end
    
    else
        telegram.send_message(chat_id, "❓ Неизвестная команда. Напишите /help для получения списка команд.")
    end
end

-- Запуск бота
print("Router Bot (простая версия) запущен. Нажмите Ctrl+C для остановки.")
telegram.run(processCommand)
