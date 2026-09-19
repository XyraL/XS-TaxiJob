fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-TaxiJob'
author 'XyraL'
description 'Civilian taxi job with a live meter, NPC and player fares, ride ratings and a reputation ladder. Standalone for QBox/QBCore.'
version '1.2.0'

-- Works on QBox (qbx_core) OR QBCore (qb-core). The bridge auto-detects.
-- Target: ox_target / qb-target, or a built-in marker and key prompt when the
-- server runs neither. See Config.Bridges.
-- Phone: XS-Phone is used for hail notifications when present, and a plain
-- notification when it is not. Entirely optional.
dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/text.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/target.lua',
    'bridge/phone.lua',
    'bridge/keys.lua',
    'client/uniform.lua',
    'client/main.lua',
    'client/admin.lua',
    'client/dispatcher.lua',
    -- After main.lua: these read the shift/cab state it owns.
    'client/vehicle.lua',
    'client/meter.lua',
    'client/fare.lua',
    'client/hail.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/phone.lua',
    'bridge/keys.lua',
    'server/main.lua',
    'server/stats.lua',
    'server/fares.lua',
    'server/hail.lua',
    'server/admin.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/meter.js',
    'html/js/panels/shift.js',
    'html/js/panels/vehicles.js',
    'html/js/panels/stats.js',
    'html/js/panels/leaderboard.js',
    'html/js/panels/admin.js',
}
