-- Модуль управления списками доменов
local os = require("os")
local config = require("config")
local json = require("modules.json")

local domainsManager = {}

-- Функция для получения текущего списка доменов
function domainsManager.getCurrentDomains()
    local handle = io.popen("uci get " .. config.podkop_uci_path .. ".custom_domains_text 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    -- Обработка результата
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    if result == "" then
        return {}
    end
    
    -- Разбиваем строку на отдельные домены
    local domains = {}
    for domain in result:gmatch("[^\r\n]+") do
        table.insert(domains, domain)
    end
    
    return domains
end

-- Функция для сохранения списка доменов
function domainsManager.saveDomains(domains)
    -- Объединяем домены в одну строку с разделителями новой строки
    local domainsStr = table.concat(domains, "\n")
    
    -- Сохраняем в UCI и применяем изменения
    local command = "uci set " .. config.podkop_uci_path .. ".custom_domains_text='" .. domainsStr .. "' && uci commit " .. string.match(config.podkop_uci_path, "([^.]+)")
    os.execute(command)
    return true
end

-- Функция для добавления нового домена
function domainsManager.addDomain(domain)
    -- Получаем текущий список доменов
    local domains = domainsManager.getCurrentDomains()
    
    -- Проверяем, существует ли уже такой домен
    for _, existingDomain in ipairs(domains) do
        if existingDomain == domain then
            return false
        end
    end
    
    -- Добавляем новый домен
    table.insert(domains, domain)
    
    -- Сохраняем обновленный список
    return domainsManager.saveDomains(domains)
end

-- Функция для удаления домена
function domainsManager.removeDomain(domain)
    -- Получаем текущий список доменов
    local domains = domainsManager.getCurrentDomains()
    
    -- Ищем и удаляем домен
    local found = false
    for i, existingDomain in ipairs(domains) do
        if existingDomain == domain then
            table.remove(domains, i)
            found = true
            break
        end
    end
    
    if not found then
        return false
    end
    
    -- Сохраняем обновленный список
    return domainsManager.saveDomains(domains)
end

-- Функция для сохранения категорий доменов
function domainsManager.saveDomainCategories(categories)
    -- Создаем директорию, если она не существует
    os.execute("mkdir -p " .. string.match(config.domains_path, "(.+)/[^/]+$"))
    
    -- Записываем в файл
    local file = io.open(config.domains_path, "w")
    if file then
        file:write(json.encode(categories))
        file:close()
        return true
    else
        return false
    end
end

-- Функция для получения всех категорий доменов
function domainsManager.getDomainCategories()
    local categories = {}
    local file = io.open(config.domains_path, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            categories = require("modules.telegram").json.decode(content)
        end
    end
    return categories
end

return domainsManager
