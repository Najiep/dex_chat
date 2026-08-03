fx_version 'cerulean'
game 'gta5'

name 'dex_chat'
author 'Dex Development'
description 'Custom FiveM chat replacement with secure job and gang banners'
version '1.0.1'

provide 'chat'

ui_page 'web/dist/index.html'

shared_scripts {
    'config/shared.lua',
    'config/organizations.lua',
    'config/security.lua',
    'config/logging.lua',
    'locales/en.lua',
    'locales/tl.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'shared/sanitizer.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua'
}

files {
    'web/dist/index.html',
    'web/dist/style.css',
    'web/dist/app.js',
    'web/dist/images/**/*'
}
