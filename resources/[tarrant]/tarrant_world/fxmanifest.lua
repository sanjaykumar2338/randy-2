fx_version 'cerulean'
game 'gta5'
name 'tarrant_world'
description 'Reversible Arlington civic and stadium identity overlay'
version '0.1.0'

-- Script overlay only: no map asset, IPL, streaming or framework dependency.
client_scripts {
    'config/locations.lua',
    'client/main.lua'
}
