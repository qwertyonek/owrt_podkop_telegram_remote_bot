-- Модуль для управления VPN (podkop)
local os = require("os")
local config = require("config")
local sendMessage = require("modules.send_message")

local vpn = {}

-- Функция для запуска VPN
function vpn.start()
    sendMessage("Запуск VPN...")
    os.execute(config.commands.vpn_start)
    sendMessage("VPN запущен")
end

-- Функция для остановки VPN
function vpn.stop()
    sendMessage("Остановка VPN...")
    os.execute(config.commands.vpn_stop)
    sendMessage("VPN остановлен")
end

-- Функция для проверки статуса VPN
function vpn.status()
    local handle = io.popen(config.commands.vpn_status)
    local result = handle:read("*a")
    handle:close()
    sendMessage("Статус VPN: " .. result)
    return result
end

return vpn
