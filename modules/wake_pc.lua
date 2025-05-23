-- Модуль для включения ПК через Wake-on-LAN
local os = require("os")
local config = require("config")
local sendMessage = require("modules.send_message")

local function wakeComputer()
    local interface = config.wake_interface
    local command = "etherwake -i " .. interface .. " " .. config.computer_mac
    os.execute(command)
    sendMessage("Запрос на запуск компьютера отправлен")
end

return wakeComputer
