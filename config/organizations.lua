Config.Organizations = {
    ballas = {
        enabled = true,
        type = 'gang',
        command = 'ballas',
        aliases = {},
        label = 'Ballas',
        shortLabel = 'BALLAS',
        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = false
        },
        message = {
            scope = 'bucket',
            anonymous = true,
            cooldown = 30,
            globalCooldown = 5,
            maxLength = 200
        },
        banner = {
            title = 'BALLAS ANNOUNCEMENT',
            logo = '',
            primary = '#7C3AED',
            secondary = '#2E1065',
            border = '#A78BFA',
            text = '#FFFFFF',
            duration = 10000
        }
    },

    vagos = {
        enabled = true,
        type = 'gang',
        command = 'vagos',
        aliases = {},
        label = 'Los Santos Vagos',
        shortLabel = 'VAGOS',
        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = false
        },
        message = {
            scope = 'bucket',
            anonymous = true,
            cooldown = 30,
            globalCooldown = 5,
            maxLength = 200
        },
        banner = {
            title = 'VAGOS ANNOUNCEMENT',
            logo = '',
            primary = '#EAB308',
            secondary = '#422006',
            border = '#FDE047',
            text = '#FFFFFF',
            duration = 10000
        }
    },

    police = {
        enabled = true,
        type = 'job',
        command = 'police',
        aliases = { 'pd', 'lspd' },
        label = 'Los Santos Police Department',
        shortLabel = 'LSPD',
        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = true
        },
        message = {
            scope = 'bucket',
            anonymous = false,
            cooldown = 15,
            globalCooldown = 3,
            maxLength = 220
        },
        banner = {
            title = 'PUBLIC SAFETY ANNOUNCEMENT',
            logo = '',
            primary = '#2563EB',
            secondary = '#0F172A',
            border = '#60A5FA',
            text = '#FFFFFF',
            duration = 10000
        }
    },

    ambulance = {
        enabled = true,
        type = 'job',
        command = 'ambulance',
        aliases = { 'ems' },
        label = 'Emergency Medical Services',
        shortLabel = 'EMS',
        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = true
        },
        message = {
            scope = 'bucket',
            anonymous = false,
            cooldown = 15,
            globalCooldown = 3,
            maxLength = 220
        },
        banner = {
            title = 'MEDICAL SERVICE ANNOUNCEMENT',
            logo = '',
            primary = '#DC2626',
            secondary = '#450A0A',
            border = '#F87171',
            text = '#FFFFFF',
            duration = 10000
        }
    },

    mechanic = {
        enabled = true,
        type = 'job',
        command = 'mechanic',
        aliases = { 'mech' },
        label = 'Los Santos Customs',
        shortLabel = 'MECHANIC',
        authorization = {
            minimumGrade = 0,
            allowedGrades = nil,
            bossOnly = false,
            requireDuty = false
        },
        message = {
            scope = 'bucket',
            anonymous = false,
            cooldown = 15,
            globalCooldown = 3,
            maxLength = 220
        },
        banner = {
            title = 'BUSINESS ANNOUNCEMENT',
            logo = '',
            primary = '#F59E0B',
            secondary = '#451A03',
            border = '#FBBF24',
            text = '#FFFFFF',
            duration = 10000
        }
    }
}
