DexChat = DexChat or {}
DexChat.Version = '2.0.0'
DexChat.MessageSchema = 2

DexChat.MessageKind = {
    CHAT = 'chat',
    OOC = 'ooc',
    ROLEPLAY = 'roleplay',
    ADVERTISEMENT = 'advertisement',
    STAFF = 'staff',
    ORGANIZATION = 'organization',
    PRIVATE = 'private',
    SYSTEM = 'system',
    PRINT = 'print'
}

DexChat.Scope = {
    GLOBAL = 'global',
    BUCKET = 'bucket',
    PROXIMITY = 'proximity',
    ORGANIZATION = 'organization',
    STAFF = 'staff',
    DIRECT = 'direct'
}
