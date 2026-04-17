fx_version 'cerulean'
game 'gta5'

name 'qb-npcmechanic'
author 'cosmo@gpt'
description 'Mobiler NPC Mechaniker (QB)'
version '1.0.0'

shared_scripts {
    'config.lua',
    'locales.lua',
    'spawnpoints.lua',
    'unsafezones.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/mechanic.png'
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu'
}
