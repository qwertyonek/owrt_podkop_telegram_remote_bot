-- Максимально простой и надежный модуль для работы с Telegram Bot API
local http = require("socket.http")
local ltn12 = require("ltn12")
local config = require("config")

local telegram = {}

-- API URL
local api_url = "https://api.telegram.org/bot" .. config.telegram_token

-- Простая функция преобразования таблицы в JSON
local function encode_json(data)
    if type(data) == "nil" then
        return "null"
    elseif type(data) == "boolean" then
        return data and "true" or "false"
    elseif type(data) == "number" then
        return tostring(data)
    elseif type(data) == "string" then
        return '"' .. data:gsub('["%\\]', '\\%1'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif type(data) == "table" then
        local is_array = true
        local i = 0
        for k,_ in pairs(data) do
            i = i + 1
            if type(k) ~= "number" or k ~= i then
                is_array = false
                break
            end
        end
        
        local result = {}
        if is_array then
            -- Массив
            for i, v in ipairs(data) do
                result[i] = encode_json(v)
            end
            return "[" .. table.concat(result, ",") .. "]"
        else
            -- Объект
            for k, v in pairs(data) do
                table.insert(result, encode_json(k) .. ":" .. encode_json(v))
            end
            return "{" .. table.concat(result, ",") .. "}"
        end
    else
        error("Unsupported type: " .. type(data))
    end
end

-- Функция для отправки запросов к Telegram API
local function make_request(method, parameters)
    print("[DEBUG] Отправка запроса: " .. method)
    
    -- Преобразуем параметры в JSON
    local request_body = encode_json(parameters or {})
    print("[DEBUG] Параметры: " .. request_body)
    
    -- Подготовка для ответа
    local response_body = {}
    
    -- Отправляем запрос
    local response, code, headers, status = http.request {
        url = api_url .. "/" .. method,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #request_body
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    }
    
    local response_str = table.concat(response_body)
    print("[DEBUG] Код ответа: " .. tostring(code))
    print("[DEBUG] Ответ: " .. response_str:sub(1, 100) .. (response_str:len() > 100 and "..." or ""))
    
    -- Проверка успешности запроса
    if code ~= 200 then
        print("[DEBUG] Ошибка HTTP: " .. tostring(code))
        return nil
    end
    
    return response_str, code
end

-- Извлекаем update_id из ответа JSON
local function extract_update_ids(json_str)
    local update_ids = {}
    for update_id in json_str:gmatch('"update_id":(%d+)') do
        table.insert(update_ids, tonumber(update_id))
    end
    return update_ids
end

-- Получить наибольший update_id из массива
local function get_max_update_id(update_ids)
    local max_id = 0
    for _, id in ipairs(update_ids) do
        if id > max_id then
            max_id = id
        end
    end
    return max_id
end

-- Получение сообщений с указанным offset
function telegram.get_updates(offset)
    print("[DEBUG] Запрос обновлений с offset=" .. tostring(offset))
    
    local response, code = make_request("getUpdates", {
        offset = offset,
        timeout = 5
    })
    
    if not response then
        print("[DEBUG] Не удалось получить обновления")
        return nil
    end
    
    -- Проверяем, что ответ содержит "ok":true
    if response:match('"ok":true') then
        -- Извлекаем update_ids
        local update_ids = extract_update_ids(response)
        
        if #update_ids > 0 then
            print("[DEBUG] Получено " .. #update_ids .. " обновлений")
            -- Парсим сообщения из ответа
            local messages = {}
            
            -- Извлекаем update_id и текст сообщения
            local i = 1
            for message_block in response:gmatch('"message":{.-}') do
                local chat_id = message_block:match('"chat":{"id":([^,]+)')
                local from_id = message_block:match('"from":{"id":([^,]+)')
                local text = message_block:match('"text":"([^"]+)"')
                
                if chat_id and from_id and text then
                    messages[i] = {
                        update_id = update_ids[i],
                        chat = {id = tonumber(chat_id)},
                        from = {id = tonumber(from_id)},
                        text = text
                    }
                    i = i + 1
                end
            end
            
            return {
                ok = true,
                result = messages,
                offset_for_next = update_ids[#update_ids] + 1
            }
        else
            print("[DEBUG] Нет новых сообщений")
            return {ok = true, result = {}}
        end
    else
        print("[DEBUG] API вернул ошибку: " .. response)
        return nil
    end
end

-- Отправка сообщения
function telegram.send_message(chat_id, text)
    -- В режиме Markdown нужно экранировать специальные символы,
    -- но проще отправить без форматирования
    
    -- удаляем звездочки из текста, чтобы избежать проблем с форматированием
    text = text:gsub("*", "")
    
    local response, code = make_request("sendMessage", {
        chat_id = chat_id,
        text = text
        -- Убираем parse_mode, чтобы избежать ошибок
    })
    
    return response ~= nil
end

-- Запуск бота
function telegram.run(callback)
    print("[DEBUG] Запуск бота...")
    
    -- Проверяем соединение с API
    local me, code = make_request("getMe", {})
    if not me or not me:match('"ok":true') then
        print("[DEBUG] Ошибка подключения к API Telegram!")
        return
    end
    
    print("[DEBUG] Бот успешно подключен")
    
    -- Отправляем приветствие
    telegram.send_message(config.admin_id, "✅ Бот запущен и готов к работе!\nНапишите /help для получения списка команд.")
    
    -- Сначала сбрасываем все старые обновления
    print("[DEBUG] Сброс старых обновлений...")
    local response, code = make_request("getUpdates", {offset = 0, timeout = 1})
    local offset = 0
    
    if response and response:match('"ok":true') then
        -- Извлекаем update_ids
        local update_ids = extract_update_ids(response)
        
        if #update_ids > 0 then
            -- Находим максимальный update_id
            local max_id = get_max_update_id(update_ids)
            offset = max_id + 1
            print("[DEBUG] Установлен начальный offset: " .. offset)
            
            -- Подтверждаем сброс
            make_request("getUpdates", {offset = offset, timeout = 1})
            print("[DEBUG] Старые обновления сброшены")
        end
    end
    
    -- Основной цикл
    print("[DEBUG] Ожидание новых сообщений...")
    while true do
        local response, code = make_request("getUpdates", {offset = offset, timeout = 30})
        
        if response and response:match('"ok":true') then
            -- Извлекаем update_ids
            local update_ids = extract_update_ids(response)
            
            if #update_ids > 0 then
                print("[DEBUG] Получено " .. #update_ids .. " обновлений")
                
                -- Извлекаем тексты сообщений
                for msg_text in response:gmatch('"text":"([^"]+)"') do
                    print("[DEBUG] Обработка сообщения: " .. msg_text)
                    
                    -- Для каждого сообщения создаем простой объект
                    local message = {
                        chat = {id = config.admin_id},
                        from = {id = config.admin_id},
                        text = msg_text
                    }
                    
                    -- Передаем сообщение в callback-функцию
                    local success, err = pcall(function() 
                        callback(message) 
                    end)
                    
                    if not success then
                        print("[DEBUG] Ошибка обработки сообщения: " .. tostring(err))
                    end
                end
                
                -- Обновляем offset на максимальный update_id + 1
                local max_id = get_max_update_id(update_ids)
                offset = max_id + 1
                print("[DEBUG] Новый offset: " .. offset)
            end
        else
            print("[DEBUG] Нет новых сообщений или ошибка запроса")
        end
        
        -- Небольшая пауза между запросами при ошибке
        if not response or not response:match('"ok":true') then
            os.execute("sleep 3")
        end
    end
end

return telegram
