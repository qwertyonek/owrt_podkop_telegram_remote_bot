-- Модуль для работы с Telegram Bot API
local http = require("socket.http")
local ltn12 = require("ltn12")
local config = require("config")
local sendMessage = require("modules.send_message")

-- Простой JSON парсер для OpenWRT
local json = {}

-- Очень простая функция кодирования JSON
function json.encode(data)
    local function escapeStr(s)
        return string.gsub(s, "[\"\\\/\b\f\n\r\t]", {
            ["\""] = "\\\"", ["\\"] = "\\\\", ["/"] = "\\/",
            ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n",
            ["\r"] = "\\r", ["\t"] = "\\t"
        })
    end

    local function encode_table(val, stack)
        local res = {}
        stack = stack or {}
        
        -- Проверка циклических ссылок
        if stack[val] then error("circular reference") end
        stack[val] = true
        
        if next(val) == nil then
            -- Если таблица пуста
            if setmetatable({}, getmetatable(val)) ~= {} then
                return "{}" -- Объект
            else
                return "[]" -- Массив
            end
        end
        
        local is_array = true
        local n = 0
        
        -- Проверка, является ли таблица массивом или объектом
        for k, v in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
            else
                n = math.max(n, k)
            end
        end
        
        if is_array then
            -- Массив
            for i = 1, n do
                res[i] = json._encode(val[i] or nil, stack)
            end
            stack[val] = nil
            return "[" .. table.concat(res, ",") .. "]"
        else
            -- Объект
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(res, '"' .. escapeStr(k) .. '":' .. json._encode(v, stack))
                end
            end
            stack[val] = nil
            return "{" .. table.concat(res, ",") .. "}"
        end
    end
    
    -- Функция кодирования данных в JSON
    function json._encode(val, stack)
        local t = type(val)
        
        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return val and "true" or "false"
        elseif t == "number" then
            return tostring(val)
        elseif t == "string" then
            return '"' .. escapeStr(val) .. '"'
        elseif t == "table" then
            return encode_table(val, stack)
        elseif t == "function" or t == "thread" or t == "userdata" then
            error("Unsupported type: " .. t)
        end
    end
    
    return json._encode(data)
end

-- Простая функция декодирования JSON
function json.decode(str)
    -- Для простоты используем функцию loadstring/load
    if str == nil or str == "" then
        return nil
    end
    
    str = string.gsub(str, "null", "nil")
    str = string.gsub(str, '"([^"]+)":', "['%1']=")
    str = "return " .. str
    
    local func, err
    if _VERSION == "Lua 5.1" then
        func, err = loadstring(str)
    else
        func, err = load("return " .. str, "json")
    end
    
    if not func then
        return nil, "JSON decode failed: " .. (err or "")
    end
    
    local success, result = pcall(func)
    if not success then
        return nil, "JSON decode execution failed: " .. result
    end
    
    return result
end
local config = require("config")
local sendMessage = require("modules.send_message")

local telegram = {}

-- API URL
local api_url = "https://api.telegram.org/bot" .. config.telegram_token

-- Функция для отправки запросов к Telegram API
local function makeRequest(method, parameters)
    print("===================================")
    print("[Отладка] Отправка запроса к Telegram: " .. method)
    print("[Отладка] URL: " .. api_url .. "/" .. method)
    
    local response_body = {}
    local request_body = json.encode(parameters)
    
    print("[Отладка] Запрос: " .. request_body)
    
    local response, code, headers, status = http.request{
        url = api_url .. "/" .. method,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #request_body
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    }
    
    print("[Отладка] Код ответа: " .. tostring(code))
    
    if code ~= 200 then
        print("[Отладка] Ошибка: " .. tostring(code))
        return nil
    end
    
    local response_str = table.concat(response_body)
    print("[Отладка] Ответ: " .. response_str)
    
    local success, response_data = pcall(function() return json.decode(response_str) end)
    if not success then
        print("[Отладка] Ошибка парсинга JSON: " .. tostring(response_data))
        return nil
    end
    
    print("===================================")
    return response_data
end

-- Получение обновлений от Telegram (метод Long Polling)
function telegram.getUpdates(offset)
    print("[Отладка] Запрос обновлений, offset: " .. tostring(offset))
    local parameters = {
        offset = offset,
        timeout = 5 -- Маленький таймаут для быстрого тестирования
    }
    
    local result = makeRequest("getUpdates", parameters)
    if result and result.ok then
        if result.result and #result.result > 0 then
            print("[Отладка] Получено обновлений: " .. #result.result)
        else
            print("[Отладка] Нет новых обновлений")
        end
    else
        print("[Отладка] Ошибка запроса")
    end
    return result
end

-- Отправка сообщения
function telegram.sendMessage(chat_id, text)
    local parameters = {
        chat_id = chat_id,
        text = text,
        parse_mode = "Markdown"
    }
    
    return makeRequest("sendMessage", parameters)
end

-- Отправка клавиатуры с кнопками
function telegram.sendKeyboard(chat_id, text, keyboard)
    local parameters = {
        chat_id = chat_id,
        text = text,
        reply_markup = {
            keyboard = keyboard,
            resize_keyboard = true,
            one_time_keyboard = false
        }
    }
    
    return makeRequest("sendMessage", parameters)
end

-- Запуск бота в режиме Long Polling
function telegram.run(callback)
    -- Начальный offset - это критически важный параметр!
    local offset = 0

    print("[Отладка] Запуск Telegram бота...")
    print("[Отладка] Токен: " .. config.telegram_token:sub(1, 10) .. "...")
    print("[Отладка] API URL: " .. api_url)
    
    -- Проверка соединения с Telegram API
    local me = makeRequest("getMe", {})
    if me and me.ok then
        print("[Отладка] Бот успешно подключен: " .. me.result.username)
        
        -- Отправим приветствие
        telegram.sendMessage(config.admin_id, "✅ Бот запущен и готов к работе!\nНапишите /help для получения списка команд.")
    else
        print("[Отладка] Ошибка подключения к API Telegram!")
        return
    end
    
    print("[Отладка] Ожидание сообщений...")
    
    -- Инициализация: удаляем все старые обновления
    print("[Отладка] Удаление всех старых обновлений...")
    local initial_updates = telegram.getUpdates(0)
    if initial_updates and initial_updates.ok and initial_updates.result and #initial_updates.result > 0 then
        local last_update = initial_updates.result[#initial_updates.result]
        -- Важно: сразу устанавливаем offset и запрашиваем с ним, чтобы подтвердить удаление
        offset = last_update.update_id + 1
        print("[Отладка] Установлен начальный offset: " .. offset)
        -- Еще один запрос с обновленным offset для подтверждения удаления
        local confirm = telegram.getUpdates(offset)
        print("[Отладка] Старые обновления удалены")
    end
    
    -- Основной цикл обработки сообщений
    while true do
        -- Запрашиваем обновления с текущим offset
        print("[Отладка] Запрос обновлений с offset = " .. offset .. "...")
        local updates = makeRequest("getUpdates", {offset = offset, timeout = 5})
        
        -- Проверяем успешность запроса
        if updates and updates.ok then
            -- Если есть новые сообщения
            if updates.result and #updates.result > 0 then
                print("[Отладка] Получено " .. #updates.result .. " новых сообщений")
                -- Обрабатываем каждое обновление
                for i, update in ipairs(updates.result) do
                    print("[Отладка] Обработка обновления #" .. i .. " из " .. #updates.result .. ", update_id: " .. update.update_id)
                    
                    -- КРИТИЧЕСКИ ВАЖНО: Сразу обновляем offset на update_id + 1
                    offset = update.update_id + 1
                    print("[Отладка] Новый offset: " .. offset)
                    
                    -- Обрабатываем сообщение, если оно есть
                    if update.message then
                        print("[Отладка] Обработка сообщения...")
                        -- Вызов функции обработки сообщения
                        local status, err = pcall(function() callback(update.message) end)
                        if not status then
                            print("[Отладка] Ошибка при обработке сообщения: " .. tostring(err))
                            -- Попробуем отправить сообщение об ошибке
                            telegram.sendMessage(update.message.chat.id, "❌ Произошла ошибка при обработке команды.")
                        end
                    end
                end
            else
                print("[Отладка] Нет новых сообщений")
            end
        else
            print("[Отладка] Ошибка запроса getUpdates")
        end
        
        -- Небольшая пауза между запросами, чтобы не нагружать сервер
        print("[Отладка] Ожидание 1 секунду...")
        os.execute("sleep 1")
    end
end

return telegram
