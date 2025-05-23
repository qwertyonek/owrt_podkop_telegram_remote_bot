-- Модуль для управления системными функциями роутера
local os = require("os")
local config = require("config")
local sendMessage = require("modules.send_message")

local system = {}

-- Функция для перезагрузки роутера
function system.reboot()
    sendMessage("Выполняется перезагрузка роутера...")
    os.execute(config.commands.reboot)
end

-- Функция для перезапуска сети
function system.restartNetwork()
    sendMessage("Выполняется перезапуск сетевого сервиса...")
    os.execute(config.commands.network_restart)
    sendMessage("Сетевой сервис перезапущен")
end

return system
