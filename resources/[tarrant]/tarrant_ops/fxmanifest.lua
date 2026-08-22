fx_version 'cerulean'
game 'gta5'
name 'tarrant_ops'
description 'Tarrant County RP operational logging, readiness, and access foundation'
version '0.1.0'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
dependencies { 'oxmysql', 'qbx_core' }
lua54 'yes'
