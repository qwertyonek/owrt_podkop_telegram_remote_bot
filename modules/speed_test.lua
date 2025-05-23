-- Модуль для проверки скорости интернета
local os = require("os")
local config = require("config")

local speedTest = {}

-- Функция для парсинга результатов speedtest
function speedTest.parseResults(result)
    -- Извлекаем важные данные регулярными выражениями
    local provider = result:match("ISP: ([^\n]+)")
    local ping = result:match("Idle Latency:%s+([%d%.]+%s+ms)")
    local download = result:match("Download:%s+([%d%.]+%s+Mbps)")
    local upload = result:match("Upload:%s+([%d%.]+%s+Mbps)")
    local packet_loss = result:match("Packet Loss:%s+([%d%.]+%%)")
    local result_url = result:match("Result URL: ([^\n]+)")
    local server = result:match("Server:%s+([^\n]+)")
    
    -- Если какие-то данные не удалось извлечь, используем заглушки
    provider = provider or "Неизвестно"
    ping = ping or "Не измерен"
    download = download or "Не измерено"
    upload = upload or "Не измерено"
    packet_loss = packet_loss or "Не измерено"
    result_url = result_url or ""
    server = server or "Неизвестно"
    
    -- Формируем красивый и компактный вывод
    local formatted_result = "\n⚡ Результаты теста скорости:\n"
    
    -- Сначала провайдер
    formatted_result = formatted_result .. "\nℹ️ Провайдер: " .. provider
    
    -- Потом скорости и пинг
    formatted_result = formatted_result .. "\n\n⬇️ Скачивание: " .. download
    formatted_result = formatted_result .. "\n⬆️ Загрузка: " .. upload
    formatted_result = formatted_result .. "\n⏱ Пинг: " .. ping
    
    -- Потери пакетов показываем, только если они есть
    if packet_loss and packet_loss ~= "0.0%" then
        formatted_result = formatted_result .. "\n⚠️ Потери пакетов: " .. packet_loss
    end
    
    -- Добавляем URL результата, если он есть
    if result_url and result_url ~= "" then
        formatted_result = formatted_result .. "\n\n➡️ Ссылка на результат: " .. result_url
    end
    
    return formatted_result
end

-- Функция для запуска теста скорости
function speedTest.run()
    -- Запускаем speedtest и получаем результат
    local handle = io.popen(config.speedtest_command)
    local result = handle:read("*a")
    handle:close()
    
    -- Парсим и форматируем результат
    local formatted_result = speedTest.parseResults(result)
    
    return formatted_result
end

return speedTest
