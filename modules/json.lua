--
-- json.lua
--
-- Простая реализация JSON для Lua
--

local json = {}

local function decode_value(str, pos, val)
    val = val or ''
    
    -- Пропускаем пробелы
    while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
        pos = pos + 1
    end
    
    if pos > #str then return nil, pos end
    
    local c = string.sub(str, pos, pos)
    
    -- Строка
    if c == '"' or c == "'" then
        return decode_string(str, pos)
    end
    
    -- null, true, false
    if c == 'n' and string.sub(str, pos, pos+3) == 'null' then
        return nil, pos + 4
    elseif c == 't' and string.sub(str, pos, pos+3) == 'true' then
        return true, pos + 4
    elseif c == 'f' and string.sub(str, pos, pos+4) == 'false' then
        return false, pos + 5
    end
    
    -- Число
    if string.match(c, "[%d%-]") then
        local endpos = pos
        while endpos <= #str and string.match(string.sub(str, endpos, endpos), "[%d%.eE%-%+]") do
            endpos = endpos + 1
        end
        local num = tonumber(string.sub(str, pos, endpos-1))
        return num, endpos
    end
    
    -- Массив
    if c == '[' then
        return decode_array(str, pos)
    end
    
    -- Объект
    if c == '{' then
        return decode_object(str, pos)
    end
    
    return nil, pos
end

function decode_string(str, pos)
    local quote = string.sub(str, pos, pos)
    local value = ""
    pos = pos + 1
    
    while pos <= #str do
        local c = string.sub(str, pos, pos)
        
        if c == quote then
            return value, pos + 1
        elseif c == '\\' and pos < #str then
            local nextc = string.sub(str, pos+1, pos+1)
            if nextc == quote or nextc == '\\' then
                value = value .. nextc
                pos = pos + 2
            else
                value = value .. c
                pos = pos + 1
            end
        else
            value = value .. c
            pos = pos + 1
        end
    end
    
    error("Unterminated string")
end

function decode_array(str, pos)
    local arr = {}
    local idx = 1
    pos = pos + 1 -- Skip [
    
    -- Пропускаем пробелы
    while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
        pos = pos + 1
    end
    
    if pos <= #str and string.sub(str, pos, pos) == ']' then
        return arr, pos + 1
    end
    
    while pos <= #str do
        local val, newpos = decode_value(str, pos)
        arr[idx] = val
        idx = idx + 1
        pos = newpos
        
        -- Пропускаем пробелы
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
        
        local c = string.sub(str, pos, pos)
        if c == ']' then
            return arr, pos + 1
        elseif c == ',' then
            pos = pos + 1
        else
            error("Expected ',' or ']' but got " .. c)
        end
        
        -- Пропускаем пробелы после запятой
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
    end
    
    error("Unterminated array")
end

function decode_object(str, pos)
    local obj = {}
    pos = pos + 1 -- Skip {
    
    -- Пропускаем пробелы
    while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
        pos = pos + 1
    end
    
    if pos <= #str and string.sub(str, pos, pos) == '}' then
        return obj, pos + 1
    end
    
    while pos <= #str do
        -- Ключ должен быть строкой
        local key, newpos
        
        if string.sub(str, pos, pos) == '"' or string.sub(str, pos, pos) == "'" then
            key, newpos = decode_string(str, pos)
        else
            error("Object key must be a string at " .. pos)
        end
        
        pos = newpos
        
        -- Пропускаем пробелы
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
        
        -- Ожидаем двоеточие
        if string.sub(str, pos, pos) ~= ':' then
            error("Expected ':' but got " .. string.sub(str, pos, pos))
        end
        pos = pos + 1
        
        -- Пропускаем пробелы
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
        
        -- Значение
        local val
        val, pos = decode_value(str, pos)
        obj[key] = val
        
        -- Пропускаем пробелы
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
        
        local c = string.sub(str, pos, pos)
        if c == '}' then
            return obj, pos + 1
        elseif c == ',' then
            pos = pos + 1
        else
            error("Expected ',' or '}' but got " .. c)
        end
        
        -- Пропускаем пробелы после запятой
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
    end
    
    error("Unterminated object")
end

function json.decode(str)
    if type(str) ~= "string" then
        error("Expected string, got " .. type(str))
    end
    
    local val, pos = decode_value(str, 1)
    
    -- Пропускаем пробелы
    while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
        pos = pos + 1
    end
    
    -- Проверяем, что строка закончилась
    if pos <= #str then
        error("Unexpected trailing characters")
    end
    
    return val
end

local function encode_value(val)
    local t = type(val)
    
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return encode_string(val)
    elseif t == "table" then
        local isArray = true
        local maxIndex = 0
        
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
                break
            end
            maxIndex = math.max(maxIndex, k)
        end
        
        isArray = isArray and maxIndex > 0 and maxIndex <= #val * 2
        
        if isArray then
            return encode_array(val)
        else
            return encode_object(val)
        end
    else
        error("Cannot encode value of type " .. t)
    end
end

function encode_string(str)
    local result = '"'
    
    for i = 1, #str do
        local c = string.sub(str, i, i)
        if c == '"' then
            result = result .. '\\"'
        elseif c == '\\' then
            result = result .. '\\\\'
        elseif c == '\n' then
            result = result .. '\\n'
        elseif c == '\r' then
            result = result .. '\\r'
        elseif c == '\t' then
            result = result .. '\\t'
        else
            result = result .. c
        end
    end
    
    return result .. '"'
end

function encode_array(arr)
    local result = "["
    
    for i, v in ipairs(arr) do
        if i > 1 then
            result = result .. ","
        end
        result = result .. encode_value(v)
    end
    
    return result .. "]"
end

function encode_object(obj)
    local result = "{"
    local first = true
    
    for k, v in pairs(obj) do
        if not first then
            result = result .. ","
        end
        first = false
        
        if type(k) ~= "string" then
            k = tostring(k)
        end
        
        result = result .. encode_string(k) .. ":" .. encode_value(v)
    end
    
    return result .. "}"
end

function json.encode(val)
    return encode_value(val)
end

return json
