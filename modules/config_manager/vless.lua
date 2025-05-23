-- Модуль управления VPN конфигурациями (VLESS)
local os = require("os")
local config = require("config")
local json = require("modules.json")

local vlessManager = {}

-- Функция для чтения текущего конфига через uci
function vlessManager.getCurrentConfig()
    local handle = io.popen("uci get " .. config.podkop_uci_path .. ".proxy_string 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    if result == "" then
        return "VLESS ключ не найден"
    end
    return result
end

-- Функция для сохранения текущего конфига в файл
function vlessManager.saveConfig(name, vlessConfig)
    -- Создаем директорию, если она не существует
    os.execute("mkdir -p " .. string.match(config.vless_configs_path, "(.+)/[^/]+$"))
    
    -- Читаем существующие конфигурации
    local configs = vlessManager.getAllConfigs()
    
    -- Добавляем новую конфигурацию
    configs[name] = {
        config = vlessConfig,
        active = false, -- По умолчанию неактивен
        created = os.time()
    }
    
    -- Записываем в файл
    local file = io.open(config.vless_configs_path, "w")
    if file then
        file:write(json.encode(configs))
        file:close()
        return true
    else
        return false
    end
end

-- Функция для получения всех сохраненных конфигураций
function vlessManager.getAllConfigs()
    local configs = {}
    local file = io.open(config.vless_configs_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            configs = json.decode(content)
        end
    end
    return configs
end

-- Функция для активации выбранной конфигурации
function vlessManager.activateConfig(name)
    local configs = vlessManager.getAllConfigs()
    if not configs[name] then
        sendMessage("Конфигурация '" .. name .. "' не найдена")
        return false
    end
    
    -- Устанавливаем выбранную конфигурацию через uci
    local command = "uci set " .. config.podkop_uci_path .. ".proxy_string='" .. configs[name].config .. "' && uci commit " .. string.match(config.podkop_uci_path, "([^.]+)")
    os.execute(command)
    
    -- Обновляем статусы конфигураций
    for configName, _ in pairs(configs) do
        configs[configName].active = (configName == name)
    end
    
    -- Сохраняем обновленные статусы
    local file = io.open(config.vless_configs_path, "w")
    if file then
        file:write(json.encode(configs))
        file:close()
    end
    
    return true
end

-- Функция для удаления конфигурации
function vlessManager.deleteConfig(name)
    local configs = vlessManager.getAllConfigs()
    if not configs[name] then
        sendMessage("Конфигурация '" .. name .. "' не найдена")
        return false
    end
    
    -- Проверяем, не является ли удаляемая конфигурация активной
    if configs[name].active then
        sendMessage("Нельзя удалить активную конфигурацию")
        return false
    end
    
    -- Удаляем конфигурацию
    configs[name] = nil
    
    -- Сохраняем обновленные конфигурации
    local file = io.open(config.vless_configs_path, "w")
    if file then
        file:write(require("modules.telegram").json.encode(configs))
        file:close()
        sendMessage("Конфигурация '" .. name .. "' удалена")
        return true
    else
        sendMessage("Ошибка при удалении конфигурации")
        return false
    end
end

return vlessManager
