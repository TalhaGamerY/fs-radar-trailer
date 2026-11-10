fx_version 'cerulean'
game 'gta5'

name 'radar_trailer'
author 'Standalone'
description 'Portable police radar speed trailer – standalone'
version '1.2.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/detection.lua',
    'client/placement.lua',
    'client/interaction.lua',
    'client/debug.lua',
}

server_scripts {
    'server/permissions.lua',
    'server/persistence.lua',
    'server/main.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/app.js',
    'data/radars.json',
}

-- When you add radar_speed_trailer.ydr + .ytyp to stream/, uncomment:
-- data_file 'DLC_ITYP_REQUEST' 'stream/radar_speed_trailer.ytyp'
