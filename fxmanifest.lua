fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-TaxiJob'
author 'XyraL'
description 'Civilian taxi job with a driver tablet, live meter, NPC and player fares, depots you build in game, and phone support. Standalone for QBox/QBCore.'
version '2.0.2'

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
    'bridge/fuel.lua',
    'client/uniform.lua',
    'client/main.lua',
    'client/admin.lua',
    'client/locations.lua',
    'client/vehicle.lua',
    'client/meter.lua',
    'client/fare.lua',
    'client/rides.lua',
    'client/flagdown.lua',
    'client/builder.lua',
    'client/phone.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/phone.lua',
    'bridge/keys.lua',
    'server/main.lua',
    'server/locations.lua',
    'server/rates.lua',
    'server/stats.lua',
    'server/fares.lua',
    'server/rides.lua',
    'server/admin.lua',
    'server/commands.lua',
    'server/phone.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/vendor/leaflet/*.js',
    'html/vendor/leaflet/*.css',
    'html/assets/maps/tiles/*.webp',
    'html/phone/index.html',
    'html/phone/icon.png',
}
