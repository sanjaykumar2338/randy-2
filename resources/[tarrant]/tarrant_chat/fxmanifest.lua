fx_version 'cerulean'
game 'common'

description 'Dismiss stock chat history immediately when its input is cancelled with Escape.'
version '1.0.0'

dependency 'chat'

files { 'cancel.js', 'cancel.css' }

chat_theme 'tarrant_chat_cancel' {
    script = 'cancel.js',
    styleSheet = 'cancel.css',
}
