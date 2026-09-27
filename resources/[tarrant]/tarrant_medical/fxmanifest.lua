fx_version 'cerulean'
game 'gta5'
description 'Tarrant County civilian death and hospital recovery'
version '0.1.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'
dependencies { 'qbx_core', 'ox_lib', 'ox_inventory', '/onesync' }
