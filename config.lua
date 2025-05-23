-- Конфигурационный файл для router_bot
local config = {}

-- Настройки для Wake-on-LAN
config.computer_mac = "МАК АДРЕС"  -- MAC-адрес компьютера для пробуждения
config.wake_interface = "br-lan"           -- Интерфейс для отправки WoL пакета

-- Настройки для VPN
config.vpn_service = "podkop"              -- Имя сервиса VPN 

-- Пути к файлам конфигурации
config.vless_configs_path = "/etc/router_bot/data/vpn_configs.json"  -- Путь к файлу с VPN конфигурациями
config.domains_path = "/etc/router_bot/data/domain_lists.json"       -- Путь к файлу со списками доменов

-- Настройки для speedtest
config.speedtest_command = "speedtest"      -- Команда для запуска speedtest

-- Настройки для Telegram
config.telegram_token = "ТОКЕН"    -- Токен Telegram бота, полученный от BotFather
config.allowed_users = {                   -- Список разрешенных пользователей (ID)
    ЮЗЕРИД,                           -- Ваш ID пользователя
}
config.admin_id = ЮЗЕРИД              -- ID администратора бота

-- Команды
config.commands = {
    reboot = "reboot",                       -- Команда для перезагрузки роутера
    network_restart = "service podkop restart",  -- Команда для перезапуска сети
    vpn_start = "service podkop start",      -- Команда для запуска VPN
    vpn_stop = "service podkop stop",        -- Команда для остановки VPN
    vpn_status = "service podkop status"     -- Команда для проверки статуса VPN
}

-- Настройки UCI для Podkop
config.podkop_uci_path = "podkop.main"      -- UCI путь к настройкам podkop

return config
