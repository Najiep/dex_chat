DexChat = DexChat or {}
DexChat.Version = '1.0.0'
DexChat.MessageSchema = 1

DexChat.MessageKind = {
    CHAT = 'chat',
    OOC = 'ooc',
    ORGANIZATION = 'organization',
    SYSTEM = 'system',
    PRINT = 'print'
}

DexChat.Scope = {
    GLOBAL = 'global',
    BUCKET = 'bucket',
    PROXIMITY = 'proximity',
    ORGANIZATION = 'organization'
}
