-- Spends merit points, job points and trust points: one rank by name, or down a priority list.

_addon.name = 'BigSpender'
_addon.author = 'AlgarDude'
_addon.version = '1.0'
_addon.commands = { 'bigspender', 'spend', }

require('lists')
local config = require('config')
local packets = require('packets')
local res = require('resources')

local settings = config.load({
    debug = false,
    meritPriority = L { "Maximum Merit Points", "Max HP", "Max MP", "Magic Skills", "Combat Skills", "Attributes", },
    jpPriority = {
        WAR = L {},
        MNK = L {},
        WHM = L {},
        BLM = L {},
        RDM = L {},
        THF = L {},
        PLD = L {},
        DRK = L {},
        BST = L {},
        BRD = L {},
        RNG = L {},
        SAM = L {},
        NIN = L {},
        DRG = L {},
        SMN = L {},
        BLU = L {},
        COR = L {},
        PUP = L {},
        DNC = L {},
        SCH = L {},
        GEO = L {},
        RUN = L {},
    },
    trustPriority = L {},
})

local meritLevels = {}
local meritCosts = {}
local meritPoints = nil
local maxMeritPoints = nil
local meritListSeen = false
local meritListNumber = 0

local jpLevels = {}
local jpCosts = {}
local jpPoints = {}

local trustLevels = {}
local trustCosts = {}
local trustPoints = nil

local pendingKind = nil
local pendingId = nil
local pendingLevel = nil
local pendingCost = nil
local pendingEntrySeen = false
local pendingPointsSeen = false
local raiseNumber = 0

local runActive = false
local runKind = nil
local runAutomatic = false
local runBought = {}
local runBudget = nil
local runJobId = nil
local runAllJobs = false
local runStopping = false
local meritAutoSpend = false
local meritAutoSpendAt = nil
local meritAutoBlocked = false
local jpAutoSpend = false
local jpAutoSpendAt = nil
local jpAutoBlocked = false

local meritPriorityIds = {}
local jpPriorityIds = {}
local trustPriorityIds = {}
local debugLogging = settings.debug
local unsafeWarning = "Spending outside the Mog House can be seen by others and may get you banned."

-- Data

local trustCategories = {
    [8] = "HP",
    [9] = "MP",
    [10] = "STR",
    [11] = "DEX",
    [12] = "VIT",
    [13] = "AGI",
    [14] = "INT",
    [15] = "MND",
    [16] = "CHR",
    [17] = "Combat Skills",
    [18] = "Magic Skills",
}

local curves = {
    hpMp = { 1, 2, 3, 4, 5, 5, 5, 5, 5, 7, 7, 7, 9, 9, 9, },
    maxMerits = { 1, 3, 5, 7, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45,
        48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 51, 51, 51, 51, 51, 51, 51, 51, 51, },
    attributes = { 3, 6, 9, 9, 9, 12, 12, 12, 12, 15, 15, 15, 15, 18, 18, },
    skills = { 1, 2, 3, 3, 3, 3, 3, 3, },
    others = { 1, 2, 3, 4, 5, },
    jobGroup1 = { 1, 2, 3, 4, 5, },
    jobGroup2 = { 3, 4, 5, 5, 5, },
    weaponSkills = { 20, 22, 24, 27, 30, },
}

local categoryCaps = {
    ['HP/MP'] = 75,
    ['Attributes'] = 105,
    ['Combat Skills'] = 152,
    ['Magic Skills'] = 112,
    ['Others'] = 10,
    ['Weapon Skills'] = 15,
}

local priorityTokens = { ['magic skills'] = 'Magic Skills', ['combat skills'] = 'Combat Skills', ['attributes'] = 'Attributes', }

local casters = { WHM = true, BLM = true, RDM = true, PLD = true, DRK = true, BRD = true, SMN = true, BLU = true, SCH = true, GEO = true, RUN = true, }

local skillJobs = {
    [1] = { WAR = true, MNK = true, THF = true, NIN = true, PUP = true, DNC = true, },
    [2] = { WAR = true, BLM = true, RDM = true, THF = true, PLD = true, DRK = true, BST = true, BRD = true, RNG = true, SAM = true, NIN = true, DRG = true, SMN = true, COR = true, PUP = true, DNC = true, SCH = true, GEO = true, },
    [3] = { WAR = true, RDM = true, THF = true, PLD = true, DRK = true, BST = true, BRD = true, RNG = true, SAM = true, NIN = true, DRG = true, BLU = true, COR = true, DNC = true, RUN = true, },
    [4] = { WAR = true, PLD = true, DRK = true, RUN = true, },
    [5] = { WAR = true, DRK = true, BST = true, RNG = true, RUN = true, },
    [6] = { WAR = true, DRK = true, RUN = true, },
    [7] = { WAR = true, BLM = true, DRK = true, BST = true, },
    [8] = { WAR = true, PLD = true, SAM = true, DRG = true, },
    [9] = { NIN = true, },
    [10] = { SAM = true, NIN = true, },
    [11] = { WAR = true, MNK = true, WHM = true, BLM = true, RDM = true, THF = true, PLD = true, DRK = true, BST = true, BRD = true, RNG = true, SAM = true, NIN = true, DRG = true, SMN = true, BLU = true, PUP = true, SCH = true, GEO = true, RUN = true, },
    [12] = { WAR = true, MNK = true, WHM = true, BLM = true, PLD = true, BRD = true, DRG = true, SMN = true, SCH = true, GEO = true, },
    [25] = { WAR = true, RDM = true, THF = true, RNG = true, SAM = true, NIN = true, },
    [26] = { WAR = true, THF = true, DRK = true, RNG = true, NIN = true, COR = true, },
    [27] = { WAR = true, MNK = true, WHM = true, BLM = true, RDM = true, THF = true, BRD = true, RNG = true, SAM = true, NIN = true, COR = true, PUP = true, DNC = true, SCH = true, },
    [28] = { MNK = true, PUP = true, },
    [29] = { WAR = true, MNK = true, WHM = true, BLM = true, RDM = true, THF = true, PLD = true, DRK = true, BST = true, BRD = true, RNG = true, SAM = true, NIN = true, DRG = true, SMN = true, BLU = true, COR = true, PUP = true, DNC = true, SCH = true, GEO = true, RUN = true, },
    [30] = { WAR = true, WHM = true, RDM = true, THF = true, PLD = true, BST = true, },
    [31] = { WAR = true, MNK = true, RDM = true, THF = true, PLD = true, DRK = true, BST = true, BRD = true, SAM = true, NIN = true, DRG = true, BLU = true, COR = true, PUP = true, DNC = true, SCH = true, GEO = true, RUN = true, },
    [32] = { WHM = true, RDM = true, PLD = true, SCH = true, RUN = true, },
    [33] = { WHM = true, RDM = true, PLD = true, SCH = true, },
    [34] = { WHM = true, BLM = true, RDM = true, PLD = true, SCH = true, RUN = true, },
    [35] = { WHM = true, BLM = true, RDM = true, DRK = true, SCH = true, GEO = true, },
    [36] = { BLM = true, RDM = true, DRK = true, SCH = true, GEO = true, },
    [37] = { BLM = true, RDM = true, DRK = true, SCH = true, GEO = true, },
    [38] = { SMN = true, },
    [39] = { NIN = true, },
    [40] = { BRD = true, },
    [41] = { BRD = true, },
    [42] = { BRD = true, },
    [43] = { BLU = true, },
    [44] = { GEO = true, },
    [45] = { GEO = true, },
}

local meritInfo = {
    [64] = { category = 'HP/MP', curve = curves.hpMp, },
    [66] = { category = 'HP/MP', curve = curves.hpMp, casterOnly = true, },
    [68] = { category = 'HP/MP', curve = curves.maxMerits, },

    [128] = { category = 'Attributes', curve = curves.attributes, },
    [130] = { category = 'Attributes', curve = curves.attributes, },
    [132] = { category = 'Attributes', curve = curves.attributes, },
    [134] = { category = 'Attributes', curve = curves.attributes, },
    [136] = { category = 'Attributes', curve = curves.attributes, },
    [138] = { category = 'Attributes', curve = curves.attributes, },
    [140] = { category = 'Attributes', curve = curves.attributes, },

    [192] = { category = 'Combat Skills', curve = curves.skills, skill = 1, },
    [194] = { category = 'Combat Skills', curve = curves.skills, skill = 2, },
    [196] = { category = 'Combat Skills', curve = curves.skills, skill = 3, },
    [198] = { category = 'Combat Skills', curve = curves.skills, skill = 4, },
    [200] = { category = 'Combat Skills', curve = curves.skills, skill = 5, },
    [202] = { category = 'Combat Skills', curve = curves.skills, skill = 6, },
    [204] = { category = 'Combat Skills', curve = curves.skills, skill = 7, },
    [206] = { category = 'Combat Skills', curve = curves.skills, skill = 8, },
    [208] = { category = 'Combat Skills', curve = curves.skills, skill = 9, },
    [210] = { category = 'Combat Skills', curve = curves.skills, skill = 10, },
    [212] = { category = 'Combat Skills', curve = curves.skills, skill = 11, },
    [214] = { category = 'Combat Skills', curve = curves.skills, skill = 12, },
    [216] = { category = 'Combat Skills', curve = curves.skills, skill = 25, },
    [218] = { category = 'Combat Skills', curve = curves.skills, skill = 26, },
    [220] = { category = 'Combat Skills', curve = curves.skills, skill = 27, },
    [222] = { category = 'Combat Skills', curve = curves.skills, skill = 28, },
    [224] = { category = 'Combat Skills', curve = curves.skills, skill = 29, },
    [226] = { category = 'Combat Skills', curve = curves.skills, skill = 30, },
    [228] = { category = 'Combat Skills', curve = curves.skills, skill = 31, },

    [256] = { category = 'Magic Skills', curve = curves.skills, skill = 32, },
    [258] = { category = 'Magic Skills', curve = curves.skills, skill = 33, },
    [260] = { category = 'Magic Skills', curve = curves.skills, skill = 34, },
    [262] = { category = 'Magic Skills', curve = curves.skills, skill = 35, },
    [264] = { category = 'Magic Skills', curve = curves.skills, skill = 36, },
    [266] = { category = 'Magic Skills', curve = curves.skills, skill = 37, },
    [268] = { category = 'Magic Skills', curve = curves.skills, skill = 38, },
    [270] = { category = 'Magic Skills', curve = curves.skills, skill = 39, },
    [272] = { category = 'Magic Skills', curve = curves.skills, skill = 40, },
    [274] = { category = 'Magic Skills', curve = curves.skills, skill = 41, },
    [276] = { category = 'Magic Skills', curve = curves.skills, skill = 42, },
    [278] = { category = 'Magic Skills', curve = curves.skills, skill = 43, },
    [280] = { category = 'Magic Skills', curve = curves.skills, skill = 44, },
    [282] = { category = 'Magic Skills', curve = curves.skills, skill = 45, },

    [320] = { category = 'Others', curve = curves.others, },
    [322] = { category = 'Others', curve = curves.others, },
    [324] = { category = 'Others', curve = curves.others, },
    [326] = { category = 'Others', curve = curves.others, },
    [328] = { category = 'Others', curve = curves.others, },

    [1664] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { MNK = true, PUP = true, }, },
    [1666] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, RDM = true, THF = true, BST = true, BRD = true, RNG = true, NIN = true, COR = true, DNC = true, }, },
    [1668] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, RDM = true, PLD = true, DRK = true, SAM = true, BLU = true, COR = true, RUN = true, }, },
    [1670] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, PLD = true, DRK = true, RUN = true, }, },
    [1672] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, DRK = true, BST = true, RNG = true, RUN = true, }, },
    [1674] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, DRK = true, RUN = true, }, },
    [1676] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, DRK = true, BST = true, }, },
    [1678] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, SAM = true, DRG = true, }, },
    [1680] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { NIN = true, }, },
    [1682] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { SAM = true, }, },
    [1684] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, MNK = true, WHM = true, BLM = true, PLD = true, SMN = true, BLU = true, SCH = true, GEO = true, }, },
    [1686] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { WAR = true, MNK = true, WHM = true, BLM = true, PLD = true, BRD = true, DRG = true, SMN = true, SCH = true, GEO = true, }, },
    [1688] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { RNG = true, SAM = true, }, },
    [1690] = { category = 'Weapon Skills', curve = curves.weaponSkills, jobs = { THF = true, RNG = true, COR = true, }, },
}

local jobGroupStarts = {
    WAR = { 0x180, 0x800, },
    MNK = { 0x1C0, 0x840, },
    WHM = { 0x200, 0x880, },
    BLM = { 0x240, 0x8C0, },
    RDM = { 0x280, 0x900, },
    THF = { 0x2C0, 0x940, },
    PLD = { 0x300, 0x980, },
    DRK = { 0x340, 0x9C0, },
    BST = { 0x380, 0xA00, },
    BRD = { 0x3C0, 0xA40, },
    RNG = { 0x400, 0xA80, },
    SAM = { 0x440, 0xAC0, },
    NIN = { 0x480, 0xB00, },
    DRG = { 0x4C0, 0xB40, },
    SMN = { 0x500, 0xB80, },
    BLU = { 0x540, 0xBC0, },
    COR = { 0x580, 0xC00, },
    PUP = { 0x5C0, 0xC40, },
    DNC = { 0x600, 0xC80, },
    SCH = { 0x640, 0xCC0, },
    GEO = { 0x6C0, 0xD40, },
    RUN = { 0x700, 0xD80, },
}

for job, starts in pairs(jobGroupStarts) do
    for group, start in ipairs(starts) do
        local category = ('%s Group %d'):format(job, group)
        categoryCaps[category] = 10
        for id = start, start + 0x3E, 2 do
            if res.merit_points[id] then
                meritInfo[id] = { category = category, curve = group == 1 and curves.jobGroup1 or curves.jobGroup2, job = job, }
            end
        end
    end
end

local meritIdsByName = {}
for id, merit in pairs(res.merit_points) do
    meritIdsByName[merit.en:lower()] = id
end

-- Helpers

--- Writes a timestamped line to this character's debug log when debug logging is on.
---@param text string the line to write
local function debugLog(text)
    if not debugLogging then return end
    local player = windower.ffxi.get_player()
    local file = io.open(('%sdata/debug_%s.log'):format(windower.addon_path, player and player.name or 'unknown'), 'a')
    file:write(os.date('%Y-%m-%d %H:%M:%S ') .. text .. '\n')
    file:close()
end

--- Prints a line to chat under the addon's name and copies it to the debug log.
---@param text string the message
local function report(text)
    windower.add_to_chat(207, 'BigSpender: ' .. text)
    debugLog('Chat: ' .. text)
end

--- Prints the warning about spending outside the Mog House on its own lines, in red.
local function warnUnsafe()
    windower.add_to_chat(123, "BigSpender: " .. unsafeWarning)
    windower.add_to_chat(123, "BigSpender: To allow it anyway: //spend I am a cheater")
    debugLog('Chat: ' .. unsafeWarning)
end

--- Formats a point total with its kind, like "5 merit points".
---@param kind string 'merits', 'jp' or 'trust'
---@param points number the total
---@return string
local function pointsText(kind, points)
    local pointType = kind == 'jp' and 'job' or kind == 'trust' and 'trust' or 'merit'
    return ('%d %s point%s'):format(points, pointType, points == 1 and '' or 's')
end

--- The job a job point belongs to.
---@param id number job point id from res.job_points
---@return number job id
local function jobIdOf(id)
    return math.floor(id / 64)
end

--- Name for chat: a merit's name, a job point's name with its job in front, or a trust upgrade's category.
---@param kind string 'merits', 'jp' or 'trust'
---@param id number merit or job point id, or trust category
---@return string
local function pointName(kind, id)
    if kind == 'jp' then return ('%s %s'):format(res.jobs[jobIdOf(id)].ens, res.job_points[id].en) end
    if kind == 'trust' then return ('Trust %s'):format(trustCategories[id]) end
    return res.merit_points[id].en
end

--- The known ranks for a kind of point, keyed by id.
---@param kind string 'merits', 'jp' or 'trust'
---@return table
local function levelTable(kind)
    if kind == 'jp' then return jpLevels end
    if kind == 'trust' then return trustLevels end
    return meritLevels
end

--- Banked points of a kind; job points are banked per job.
---@param kind string 'merits', 'jp' or 'trust'
---@param jobId number|nil the job, for job points
---@return number|nil nil until the server has sent a total
local function bankedPoints(kind, jobId)
    if kind == 'jp' then return jpPoints[jobId] end
    if kind == 'trust' then return trustPoints end
    return meritPoints
end

--- Finds a merit by its full name or by the start of a name only one merit has.
---@param query string what was typed
---@return number|nil id
---@return table|nil candidate ids when the start matches several merits or none
local function findMerit(query)
    query = query:lower()
    if meritIdsByName[query] then return meritIdsByName[query] end

    local candidates = {}
    for name, id in pairs(meritIdsByName) do
        if name:sub(1, #query) == query then
            candidates[#candidates + 1] = id
        end
    end
    if #candidates == 1 then return candidates[1] end
    return nil, candidates
end

--- Finds one job's job point by its full name or by the start of a name only one of them has.
---@param query string what was typed
---@param jobId number the job to search
---@return number|nil id
---@return table|nil candidate ids when the start matches several job points or none
local function findJobPoint(query, jobId)
    query = query:lower()
    local candidates = {}
    for id = jobId * 64, jobId * 64 + 62, 2 do
        local name = res.job_points[id] and res.job_points[id].en:lower()
        if name == query then return id end
        if name and name:sub(1, #query) == query then
            candidates[#candidates + 1] = id
        end
    end
    if #candidates == 1 then return candidates[1] end
    return nil, candidates
end

--- Finds a trust upgrade category by its full name or by the start of a name only one category has.
---@param query string what was typed
---@return number|nil category
---@return table|nil candidate categories when the start matches several or none
local function findTrustCategory(query)
    query = query:lower()
    local candidates = {}
    for category = 8, 18 do
        local name = trustCategories[category]:lower()
        if name == query then return category end
        if name:sub(1, #query) == query then
            candidates[#candidates + 1] = category
        end
    end
    if #candidates == 1 then return candidates[1] end
    return nil, candidates
end

--- Whether this character has the Job Breaker key item that unlocks job points.
---@return boolean
local function hasJobBreaker()
    for _, keyItemId in ipairs(windower.ffxi.get_key_items()) do
        if keyItemId == 2544 then return true end
    end
    return false
end

--- Whether someone on this install has typed //spend I am a cheater.
---@return boolean
local function hasAccepted()
    local file = io.open(windower.addon_path .. 'data/accepted.txt', 'r')
    if not file then return false end
    file:close()
    return true
end

--- Turns the priority settings into merit ids, job point ids and trust categories, reporting entries that can't be used.
local function buildPriority()
    meritPriorityIds = {}
    for _, entry in ipairs(settings.meritPriority) do
        local lowerEntry = entry:lower()
        if priorityTokens[lowerEntry] then
            local ids = {}
            for id, info in pairs(meritInfo) do
                if info.category == priorityTokens[lowerEntry] then
                    ids[#ids + 1] = id
                end
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                meritPriorityIds[#meritPriorityIds + 1] = id
            end
        else
            local id = meritIdsByName[lowerEntry]
            local category = id and meritInfo[id].category
            if not category then
                report(('Priority entry "%s" is not a merit and was dropped.'):format(entry))
            elseif category ~= 'HP/MP' and category ~= 'Others' and not priorityTokens[category:lower()] then
                report(('Priority entry "%s" was dropped. %s merits are never bought from the priority list.'):format(entry, category))
            else
                meritPriorityIds[#meritPriorityIds + 1] = id
            end
        end
    end

    jpPriorityIds = {}
    for jobId, job in pairs(res.jobs) do
        local entries = settings.jpPriority[job.ens]
        if entries then
            jpPriorityIds[jobId] = {}
            for _, entry in ipairs(entries) do
                local id, candidates = findJobPoint(entry, jobId)
                if id then
                    jpPriorityIds[jobId][#jpPriorityIds[jobId] + 1] = id
                elseif #candidates > 1 then
                    report(('%s priority entry "%s" matches more than one %s job point and was dropped.'):format(job.ens, entry, job.ens))
                else
                    report(('%s priority entry "%s" is not a %s job point and was dropped.'):format(job.ens, entry, job.ens))
                end
            end
        end
    end

    trustPriorityIds = {}
    for _, entry in ipairs(settings.trustPriority) do
        local category, candidates = findTrustCategory(entry)
        if category then
            trustPriorityIds[#trustPriorityIds + 1] = category
        elseif #candidates > 1 then
            report(('Trust priority entry "%s" matches more than one trust upgrade and was dropped.'):format(entry))
        else
            report(('Trust priority entry "%s" is not a trust upgrade and was dropped.'):format(entry))
        end
    end
end

config.register(settings, buildPriority)
config.register(settings, function() debugLogging = settings.debug end)

-- Checks

--- Why points of a kind can't be counted on yet, or nil once the server has sent what's needed.
---@param kind string 'merits', 'jp' or 'trust'
---@param jobId number|nil the job, for job points
---@param allJobs boolean|nil check every job from jobId through RUN
---@return string|nil
local function readinessRefusal(kind, jobId, allJobs)
    if kind == 'jp' then
        if not hasJobBreaker() then return 'Job points are not unlocked on this character (no Job Breaker key item).' end
        for checkJobId = jobId, allJobs and 22 or jobId do
            if jpLevels[checkJobId * 64] == nil then
                return ('No %s job point list yet. It arrives a few seconds after loading or zoning.'):format(res.jobs[checkJobId].ens)
            end
            if bankedPoints('jp', checkJobId) == nil then return 'No job point total yet. Zone to receive one.' end
        end
        return nil
    end
    if kind == 'trust' then
        if trustPoints == nil then return 'No trust point total yet. Zone to receive one.' end
        return nil
    end
    local player = windower.ffxi.get_player()
    if player.main_job_level < 75 then return ('Merit points can only be spent at level 75 or higher. Your %s is level %d.'):format(player.main_job, player.main_job_level) end
    if not meritListSeen then return 'No merit list yet. Zone to receive one.' end
    if meritPoints == nil then return 'No merit point total yet. Open your equipment screen.' end
    return nil
end

--- Why points can't be spent right now, or nil when they can.
---@param kind string 'merits', 'jp' or 'trust'
---@param jobId number|nil the job, for job points
---@param allJobs boolean|nil check every job from jobId through RUN
---@return string|nil
local function globalRefusal(kind, jobId, allJobs)
    local inMogHouse = windower.ffxi.get_info().mog_house
    if kind == 'jp' and not inMogHouse and (allJobs or jobId ~= windower.ffxi.get_player().main_job_id) then
        return "Job points for other jobs can only be spent in your Mog House."
    end
    local reason = readinessRefusal(kind, jobId, allJobs)
    if reason then return reason end
    if not inMogHouse then
        if kind == 'trust' then return 'You must be in your Mog House.' end
        if not hasAccepted() then return unsafeWarning end
    end
    local status = windower.ffxi.get_player().status
    if status ~= 0 and status ~= 1 and status ~= 33 then return 'Points can only be spent while idle, engaged or resting.' end
    return nil
end

--- Cost of a merit's next rank: the server's price when it's for this rank, otherwise the expected one.
---@param id number merit id
---@param levels table ranks keyed by merit id, real or simulated
---@return number
local function meritNextCost(id, levels)
    local level = levels[id] or 0
    local serverCost = level == (meritLevels[id] or 0) and meritCosts[id] or nil
    return serverCost or meritInfo[id].curve[level + 1]
end

--- Cost of a job point's next rank: the server's price when it's for this rank, otherwise the expected one.
---@param id number job point id
---@param levels table ranks keyed by job point id, real or simulated
---@return number
local function jpNextCost(id, levels)
    local level = levels[id] or 0
    local serverCost = level == (jpLevels[id] or 0) and jpCosts[id] or nil
    return serverCost or level + 1
end

--- Cost of a trust upgrade's next rank: the server's price when it's for this rank, otherwise the expected one.
---@param category number trust category
---@param levels table ranks keyed by category, real or simulated
---@return number
local function trustNextCost(category, levels)
    local level = levels[category] or 0
    local serverCost = level == (trustLevels[category] or 0) and trustCosts[category] or nil
    return serverCost or math.floor(level / 10) + 1
end

--- Cost of the next rank for any kind.
---@param kind string 'merits', 'jp' or 'trust'
---@param id number merit or job point id, or trust category
---@param levels table ranks keyed by id
---@return number
local function nextCost(kind, id, levels)
    if kind == 'jp' then return jpNextCost(id, levels) end
    if kind == 'trust' then return trustNextCost(id, levels) end
    return meritNextCost(id, levels)
end

--- Why a merit's next rank can't be bought, or nil when it can.
---@param id number merit id
---@param mainJob string main job abbreviation
---@param levels table ranks keyed by merit id
---@param points number points available to spend
---@return string|nil
---@return boolean|nil true when the only problem is not having enough points yet
local function meritRefusal(id, mainJob, levels, points)
    local info = meritInfo[id]

    if info.skill and not skillJobs[info.skill][mainJob] then return ('%s does not have this skill.'):format(mainJob) end
    if info.jobs and not info.jobs[mainJob] then return ('%s cannot use this weapon skill.'):format(mainJob) end
    if info.job and info.job ~= mainJob then return ('This is a %s merit.'):format(info.job) end

    local level = levels[id] or 0
    if level >= #info.curve then return 'Already at maximum rank.' end
    local categoryRanks = 0
    for otherId, otherInfo in pairs(meritInfo) do
        if otherInfo.category == info.category then
            categoryRanks = categoryRanks + (levels[otherId] or 0)
        end
    end
    if categoryRanks >= categoryCaps[info.category] then return ('The %s category is at its cap.'):format(info.category) end

    local cost = meritNextCost(id, levels)
    if cost == 0 then return 'The server reports this merit as blocked.' end
    if cost > points then return ('Next rank costs %d. You have %s.'):format(cost, pointsText('merits', points)), true end
    return nil
end

--- Why a job point's next rank can't be bought, or nil when it can.
---@param id number job point id
---@param levels table ranks keyed by job point id
---@param points number points available to spend
---@return string|nil
---@return boolean|nil true when the only problem is not having enough points yet
local function jpRefusal(id, levels, points)
    local level = levels[id] or 0
    if level >= 20 then return 'Already at maximum rank.' end

    local cost = jpNextCost(id, levels)
    if cost == 0 then return 'The server reports this job point as blocked.' end
    if cost > points then return ('Next rank costs %d. You have %s.'):format(cost, pointsText('jp', points)), true end
    return nil
end

--- Why a trust upgrade's next rank can't be bought, or nil when it can.
---@param category number trust category
---@param levels table ranks keyed by category
---@param points number points available to spend
---@return string|nil
---@return boolean|nil true when the only problem is not having enough points yet
local function trustRefusal(category, levels, points)
    local level = levels[category] or 0
    if level >= 50 then return 'Already at maximum rank.' end

    local cost = trustNextCost(category, levels)
    if cost == 0 then return 'The server reports this upgrade as blocked.' end
    if cost > points then return ('Next rank costs %d. You have %s.'):format(cost, pointsText('trust', points)), true end
    return nil
end

--- Why the next rank of any kind can't be bought, or nil when it can.
---@param kind string 'merits', 'jp' or 'trust'
---@param id number merit or job point id, or trust category
---@param levels table ranks keyed by id
---@param points number points available to spend
---@return string|nil
---@return boolean|nil true when the only problem is not having enough points yet
local function refusal(kind, id, levels, points)
    if kind == 'jp' then return jpRefusal(id, levels, points) end
    if kind == 'trust' then return trustRefusal(id, levels, points) end
    return meritRefusal(id, windower.ffxi.get_player().main_job, levels, points)
end

--- The next rank to buy, strictly in list order, or nil once the next rank in line costs more than the points left.
---@param kind string 'merits', 'jp' or 'trust'
---@param levels table ranks keyed by id, real or simulated
---@param points number points available to spend
---@param jobId number|nil the job, for job points
---@return number|nil id
local function nextPick(kind, levels, points, jobId)
    local candidates = meritPriorityIds
    if kind ~= 'merits' then
        local listed = trustPriorityIds
        local firstId, lastId, step = 8, 18, 1
        if kind == 'jp' then
            listed = jpPriorityIds[jobId]
            firstId, lastId, step = jobId * 64, jobId * 64 + 62, 2
        end
        candidates = {}
        for _, id in ipairs(listed) do
            candidates[#candidates + 1] = id
        end
        local remaining = {}
        for id = firstId, lastId, step do
            if kind == 'trust' or res.job_points[id] then remaining[#remaining + 1] = id end
        end
        table.sort(remaining, function(a, b)
            local costA, costB = nextCost(kind, a, levels), nextCost(kind, b, levels)
            if costA ~= costB then return costA < costB end
            return a < b
        end)
        for _, id in ipairs(remaining) do
            candidates[#candidates + 1] = id
        end
    end

    local mainJob = windower.ffxi.get_player().main_job
    for _, id in ipairs(candidates) do
        if kind == 'merits' and meritInfo[id].casterOnly and not casters[mainJob] then
            debugLog(('Skip %s: Casters only.'):format(pointName(kind, id)))
        else
            local reason, notEnoughPoints = refusal(kind, id, levels, points)
            if not reason then return id end
            debugLog(('Skip %s: %s'):format(pointName(kind, id), reason))
            if notEnoughPoints then return nil end
        end
    end
    return nil
end

-- Raising

local runStep = nil
local checkAutoSpend = nil

--- Ends the current run and reports what it bought.
---@param reason string|nil why it ended early, shown before the summary
local function finishRun(reason)
    runActive = false
    runStopping = false
    if reason then report(reason) end

    local order = {}
    local counts = {}
    for _, id in ipairs(runBought) do
        if not counts[id] then order[#order + 1] = id end
        counts[id] = (counts[id] or 0) + 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        parts[#parts + 1] = ('%s x%d'):format(pointName(runKind, id), counts[id])
    end

    local summary = #parts > 0 and 'Bought ' .. table.concat(parts, ', ') .. '.' or 'Bought nothing.'
    if bankedPoints(runKind, runJobId) and not runAllJobs then
        summary = ('%s %s left.'):format(summary, pointsText(runKind, bankedPoints(runKind, runJobId)))
    end
    report(summary)
end

--- Reports a raise that wasn't confirmed and ends any run it was part of.
---@param reason string what went wrong
local function failRaise(reason)
    report(('%s: %s'):format(pointName(pendingKind, pendingId), reason))
    pendingId = nil
    if runActive then
        if runAutomatic and runKind == 'jp' then
            jpAutoBlocked = true
        elseif runAutomatic then
            meritAutoBlocked = true
        end
        finishRun()
    end
end

--- Reports the pending raise once both its new rank and the new point total have arrived, and moves a run on.
local function checkConfirmed()
    if not pendingId or not pendingEntrySeen or not pendingPointsSeen then return end

    local id = pendingId
    pendingId = nil
    local jobId = pendingKind == 'jp' and jobIdOf(id) or nil
    report(('%s raised to %d. %s left.'):format(pointName(pendingKind, id), levelTable(pendingKind)[id], pointsText(pendingKind, bankedPoints(pendingKind, jobId))))
    if runActive then
        runBought[#runBought + 1] = id
        if runBudget then runBudget = runBudget - pendingCost end
        if runStopping then
            finishRun('Stopped.')
        else
            coroutine.schedule(runStep, 2)
        end
    end
end

--- Sends the raise for one rank and waits up to 5 seconds for the server to confirm it.
---@param kind string 'merits', 'jp' or 'trust'
---@param id number merit or job point id, or trust category
local function sendRaise(kind, id)
    local packetId = 0x0BE
    local raw
    if kind == 'trust' then
        packetId = 0x0C1
        raw = string.char(0xC1, 0x04, 0x00, 0x00, id, 0x00, 0x00, 0x00)
    elseif kind == 'jp' then
        packetId = 0x0BF
        raw = packets.build(packets.new('outgoing', 0x0BF, { ['Type'] = id / 2 % 32, ['Job'] = jobIdOf(id), }))
    else
        raw = packets.build(packets.new('outgoing', 0x0BE, { ['Flag'] = 1, ['Merit Point'] = id / 2, }))
    end

    debugLog(('Sent %s (ID %d) at level %d with %s: %s'):format(pointName(kind, id), id, levelTable(kind)[id] or 0,
        pointsText(kind, bankedPoints(kind, kind == 'jp' and jobIdOf(id) or nil)),
        (raw:gsub('.', function(character) return ('%02X '):format(character:byte()) end))))

    pendingKind = kind
    pendingId = id
    pendingLevel = levelTable(kind)[id] or 0
    pendingCost = nextCost(kind, id, levelTable(kind))
    pendingEntrySeen = false
    pendingPointsSeen = false
    raiseNumber = raiseNumber + 1

    local thisRaise = raiseNumber
    coroutine.schedule(function()
        if pendingId and raiseNumber == thisRaise then
            local stopping = runStopping
            failRaise('No response from the server within 5 seconds.')
            if not stopping and pendingKind ~= 'trust' then checkAutoSpend(pendingKind == 'jp' and 'merits' or 'jp') end
        end
    end, 5)

    windower.packets.inject_outgoing(packetId, raw)
end

--- Points the current run may still spend on its current job.
---@return number
local function runPoints()
    local points = bankedPoints(runKind, runJobId) or 0
    if runBudget then return math.min(points, runBudget) end
    return points
end

--- Buys the run's next rank, moving on through the jobs in all-jobs mode, or ends the run when nothing is left.
runStep = function()
    if not runActive or pendingId then return end
    local reason = globalRefusal(runKind, runJobId, runAllJobs)
    if reason then
        finishRun(reason)
        return
    end

    local id = nextPick(runKind, levelTable(runKind), runPoints(), runJobId)
    while not id and runAllJobs and runJobId < 22 do
        runJobId = runJobId + 1
        id = nextPick(runKind, levelTable(runKind), runPoints(), runJobId)
    end
    if not id then
        finishRun()
        if runKind ~= 'trust' then checkAutoSpend(runKind == 'jp' and 'merits' or 'jp') end
        return
    end
    sendRaise(runKind, id)
end

--- Starts buying ranks one at a time until nothing more can be bought.
---@param kind string 'merits', 'jp' or 'trust'
---@param automatic boolean started by autospend
---@param budget number|nil most points to spend, or nil for no limit
---@param jobId number|nil the job, for job points
---@param allJobs boolean|nil go on through every job up to RUN
local function startRun(kind, automatic, budget, jobId, allJobs)
    runActive = true
    runKind = kind
    runAutomatic = automatic
    runBought = {}
    runBudget = budget
    runJobId = jobId
    runAllJobs = allJobs
    runStep()
end

--- Starts an automatic run when autospend is on, points have reached the autospend amount and something can be bought.
---@param kind string 'merits' or 'jp'
checkAutoSpend = function(kind)
    if pendingId or runActive then return end
    if kind == 'jp' then
        if not jpAutoSpend or jpAutoBlocked then return end
        local jobId = windower.ffxi.get_player().main_job_id
        if globalRefusal('jp', jobId) then return end
        local points = bankedPoints('jp', jobId)
        local spendAt = jpAutoSpendAt or 500
        if points < spendAt or not nextPick('jp', jpLevels, points, jobId) then return end
        report(('Job points reached %d/%d. Spending.'):format(points, spendAt))
        startRun('jp', true, nil, jobId)
    else
        if not meritAutoSpend or meritAutoBlocked then return end
        if globalRefusal('merits') then return end
        local spendAt = math.min(meritAutoSpendAt or maxMeritPoints, maxMeritPoints)
        if meritPoints < spendAt or not nextPick('merits', meritLevels, meritPoints) then return end
        report(('Merit points reached %d/%d. Spending.'):format(meritPoints, spendAt))
        startRun('merits', true)
    end
end

-- Commands

--- Buys one rank of a merit, job point or trust upgrade named in a command.
---@param kind string 'merits', 'jp' or 'trust'
---@param query string the name typed
---@param jobId number|nil the job, for job points
local function buy(kind, query, jobId)
    if pendingId or runActive then
        report('A raise is already in progress.')
        return
    end

    local id, candidates
    local pointType = 'merit'
    if kind == 'jp' then
        id, candidates = findJobPoint(query, jobId)
        pointType = res.jobs[jobId].ens .. ' job point'
    elseif kind == 'trust' then
        id, candidates = findTrustCategory(query)
        pointType = 'trust upgrade'
    else
        id, candidates = findMerit(query)
    end
    if not id then
        if #candidates == 0 then
            report(('No %s named "%s".'):format(pointType, query))
        else
            local names = {}
            for _, candidateId in ipairs(candidates) do
                names[#names + 1] = pointName(kind, candidateId)
            end
            table.sort(names)
            report(('"%s" matches more than one %s: %s.'):format(query, pointType, table.concat(names, ', ')))
        end
        return
    end

    local reason = globalRefusal(kind, jobId) or refusal(kind, id, levelTable(kind), bankedPoints(kind, jobId))
    if reason == unsafeWarning then
        warnUnsafe()
        return
    end
    if reason then
        report(('%s: %s'):format(pointName(kind, id), reason))
        return
    end
    sendRaise(kind, id)
end

--- Starts a run from a command.
---@param kind string 'merits', 'jp' or 'trust'
---@param budget number|nil most points to spend
---@param jobId number|nil the job, for job points
---@param allJobs boolean go on through every job up to RUN
local function spendNow(kind, budget, jobId, allJobs)
    if pendingId or runActive then
        report('A raise is already in progress.')
        return
    end

    local reason = globalRefusal(kind, jobId, allJobs)
    if reason == unsafeWarning then
        warnUnsafe()
        return
    end
    if reason then
        report(reason)
        return
    end
    startRun(kind, false, budget, jobId, allJobs)
end

--- Stops the current run once any raise already sent is answered.
local function stop()
    if not runActive then
        report('Nothing is being spent.')
        return
    end
    if runAutomatic and runKind == 'jp' then
        jpAutoBlocked = true
    elseif runAutomatic then
        meritAutoBlocked = true
    end
    if pendingId then
        runStopping = true
        report("Stopping after the raise in progress.")
        return
    end
    finishRun('Stopped.')
end

--- Writes data/accepted.txt, which lets every character on this install autospend and spend outside the Mog House.
local function accept()
    if hasAccepted() then
        report("Already accepted on this install.")
        return
    end

    local today = os.date('*t')
    local file = io.open(windower.addon_path .. 'data/accepted.txt', 'w')
    file:write(([[
  ______________________________________________
 / \                                           \
|   |                                           |
 \_ |                                           |
    |   %-40s|
    |   chose to break the rules.               |
    |                                           |
    |   Signed and witnessed by a very          |
    |   disappointed moogle. Kupo.              |
    |                                           |
    |   ________________________________________|___
    |  /                                            /
    \_/____________________________________________/
]]):format(("On %s %d, %d, this adventurer"):format(os.date('%B'), today.day, today.year)))
    file:close()
    local accepted = "Accepted. Every character on this install can now autospend and spend merits and job points outside the Mog House."
    windower.add_to_chat(123, "BigSpender: " .. accepted)
    debugLog('Chat: ' .. accepted)
end

--- Lists what spendnow would buy, one line per upgrade, or one line per job when covering every job.
---@param kind string 'merits', 'jp' or 'trust'
---@param budget number|nil most points to spend, or nil for no limit
---@param jobId number|nil the job, for job points
---@param allJobs boolean go on through every job up to RUN
local function preview(kind, budget, jobId, allJobs)
    local reason = readinessRefusal(kind, jobId, allJobs)
    if reason then
        report(reason)
        return
    end

    local previewLevels = {}
    for id, level in pairs(levelTable(kind)) do
        previewLevels[id] = level
    end
    local purchases = 0
    local budgetLeft = budget

    local previewJobId = jobId
    repeat
        local points = bankedPoints(kind, previewJobId) or 0
        local jobRanks = 0
        local jobCost = 0
        local raised = {}
        local startLevels = {}
        local costs = {}
        local id = nextPick(kind, previewLevels, budgetLeft and math.min(points, budgetLeft) or points, previewJobId)
        while id do
            local cost = nextCost(kind, id, previewLevels)
            if not startLevels[id] then
                raised[#raised + 1] = id
                startLevels[id] = previewLevels[id] or 0
                costs[id] = 0
            end
            costs[id] = costs[id] + cost
            points = points - cost
            if budgetLeft then budgetLeft = budgetLeft - cost end
            previewLevels[id] = (previewLevels[id] or 0) + 1
            purchases = purchases + 1
            jobRanks = jobRanks + 1
            jobCost = jobCost + cost
            id = nextPick(kind, previewLevels, budgetLeft and math.min(points, budgetLeft) or points, previewJobId)
        end
        if allJobs and jobRanks > 0 then
            report(('%s: would buy %d rank%s for %s.'):format(res.jobs[previewJobId].ens, jobRanks, jobRanks == 1 and '' or 's', pointsText(kind, jobCost)))
        elseif jobRanks > 0 then
            for _, raisedId in ipairs(raised) do
                report(('Would raise %s from %d to %d for %s.'):format(pointName(kind, raisedId), startLevels[raisedId], previewLevels[raisedId], pointsText(kind, costs[raisedId])))
            end
            report(('That spends %s and leaves %s.'):format(pointsText(kind, jobCost), pointsText(kind, points)))
        end
        previewJobId = allJobs and previewJobId + 1 or nil
    until not previewJobId or previewJobId > 22

    if purchases == 0 and allJobs then
        report('Nothing to buy on any job.')
    elseif purchases == 0 then
        report(('Nothing to buy. %s banked.'):format(pointsText(kind, bankedPoints(kind, jobId))))
    end
end

-- Events

windower.register_event('addon command', function(section, command, ...)
    local query = table.concat({ ..., }, ' ')
    local typed = table.concat({ section, command, ..., }, ' ')
    debugLog(('Command: //spend %s'):format(typed))
    section = (section or ''):lower()
    command = (command or ''):lower()
    local kind = (section == 'merits' or section == 'jp' or section == 'trust') and section or nil

    local jobId = nil
    local allJobs = false
    if kind == 'jp' and command ~= 'autospend' then
        jobId = windower.ffxi.get_player().main_job_id
        local jobToken, rest = query:match('^(%S+)%s*(.*)$')
        jobToken = jobToken and jobToken:lower()
        if jobToken == 'all' and command ~= 'buy' then
            jobId = 1
            allJobs = true
            query = rest
        elseif not (command == 'buy' and rest ~= '' and findJobPoint(query, jobId)) then
            for candidateId = 1, 22 do
                if res.jobs[candidateId].ens:lower() == jobToken then
                    jobId = candidateId
                    query = rest
                    break
                end
            end
        end
    end

    if (typed:lower():gsub('%s+', ' ')) == "i am a cheater" then
        accept()
    elseif section == 'stop' then
        stop()
    elseif section == 'debug' then
        if command == 'on' or command == 'off' then
            debugLogging = command == 'on'
        end
        report(('Debug logging is %s.'):format(debugLogging and 'on' or 'off'))
    elseif kind and command == 'buy' and query ~= '' then
        buy(kind, query, jobId)
    elseif kind and command == 'spendnow' and (query == '' or tonumber(query)) then
        spendNow(kind, tonumber(query), jobId, allJobs)
    elseif kind and command == 'preview' and (query == '' or tonumber(query)) then
        preview(kind, tonumber(query), jobId, allJobs)
    elseif kind and kind ~= 'trust' and command == 'autospend' then
        local setting = query:lower()
        local spendAt = tonumber(setting)
        local label = kind == 'jp' and 'Job point' or 'Merit'
        local highest = kind == 'jp' and 500 or (maxMeritPoints or 75)
        if spendAt and (spendAt < 1 or spendAt > highest or spendAt % 1 ~= 0) then
            report(('%s autospend takes 1 to %d.'):format(label, highest))
            return
        end
        if (setting == 'on' or spendAt) and not hasAccepted() then
            warnUnsafe()
            return
        end
        if setting == 'on' or setting == 'off' or spendAt then
            if kind == 'jp' then
                jpAutoSpend = setting ~= 'off'
                jpAutoSpendAt = spendAt
            else
                meritAutoSpend = setting ~= 'off'
                meritAutoSpendAt = spendAt
            end
        end
        local autoSpendOn, autoSpendAt = meritAutoSpend, meritAutoSpendAt
        if kind == 'jp' then autoSpendOn, autoSpendAt = jpAutoSpend, jpAutoSpendAt end
        if not autoSpendOn then
            report(('%s autospend off.'):format(label))
        elseif autoSpendAt then
            report(('%s autospend on at %d.'):format(label, autoSpendAt))
        else
            report(('%s autospend on at the cap.'):format(label))
        end
        checkAutoSpend(kind)
    elseif kind == 'trust' and command == 'autospend' then
        report("Trust points have no autospend.")
    else
        report("//spend merits buy <merit>: Raise one rank of a merit.")
        report("//spend merits spendnow [amount]: Spend merit points down the priority list, up to amount if given.")
        report("//spend merits preview [amount]: List what spendnow would buy.")
        report("//spend merits autospend [on|off|points]: Spend automatically at the merit cap (75) or at points.")
        report("//spend jp buy [job] <job point>: Raise one rank of a job point, on your main job unless a job is given.")
        report("//spend jp spendnow [job|all] [amount]: Spend job points down the job's priority list, then cheapest first, up to amount if given.")
        report("//spend jp preview [job|all] [amount]: List what spendnow would buy.")
        report("//spend jp autospend [on|off|points]: Spend automatically at the JP cap (500, main job only) or at points.")
        report("//spend trust buy <upgrade>: Raise one rank of a trust upgrade, like HP or Magic Skills. Mog House only.")
        report("//spend trust spendnow [amount]: Spend trust points down the priority list, then cheapest first, up to amount if given.")
        report("//spend trust preview [amount]: List what spendnow would buy.")
        report("//spend stop: Stop spending after the raise in progress.")
        report("//spend debug [on|off]: Log to data/debug_<name>.log.")
    end
end)

windower.register_event('incoming chunk', function(id, data)
    if id == 0x00A or id == 0x00B then
        debugLog(('0x%03X zone packet. Held data cleared.'):format(id))
        if pendingId then
            failRaise('Zoned before the raise was confirmed.')
        elseif runActive then
            finishRun('Stopped spending because you zoned.')
        end
        meritLevels = {}
        meritCosts = {}
        meritPoints = nil
        maxMeritPoints = nil
        meritListSeen = false
        meritListNumber = meritListNumber + 1
        meritAutoBlocked = false
        jpAutoBlocked = false
    elseif id == 0x08C then
        local count = data:byte(5)
        debugLog(('0x08C with %d entries.'):format(count))
        for entry = 0, count - 1 do
            local offset = 9 + entry * 4
            local meritId = data:unpack('H', offset)
            meritCosts[meritId] = data:byte(offset + 2)
            meritLevels[meritId] = data:byte(offset + 3)
            if pendingKind == 'merits' and meritId == pendingId then
                debugLog(('  %s: level %d, next cost %d.'):format(pointName('merits', meritId), meritLevels[meritId], meritCosts[meritId]))
                if meritLevels[meritId] == pendingLevel + 1 then pendingEntrySeen = true end
            end
        end
        if not meritListSeen and count < 61 then
            meritListSeen = true
            checkAutoSpend('merits')
        elseif not meritListSeen then
            meritListNumber = meritListNumber + 1
            local thisList = meritListNumber
            coroutine.schedule(function()
                if meritListSeen or meritListNumber ~= thisList then return end
                meritListSeen = true
                checkAutoSpend('merits')
            end, 10)
        end
        checkConfirmed()
    elseif id == 0x08D then
        debugLog('0x08D job point list.')
        for offset = 5, #data - 3, 4 do
            local jpId = data:unpack('H', offset) * 2
            if jpId ~= 0 then
                local packed = data:unpack('H', offset + 2)
                jpCosts[jpId] = packed % 1024
                jpLevels[jpId] = math.floor(packed / 1024)
                if pendingKind == 'jp' and jpId == pendingId then
                    debugLog(('  %s: level %d, next cost %d.'):format(pointName('jp', jpId), jpLevels[jpId], jpCosts[jpId]))
                    if jpLevels[jpId] == pendingLevel + 1 then pendingEntrySeen = true end
                end
            end
        end
        checkConfirmed()
        checkAutoSpend('jp')
    elseif id == 0x029 and pendingId then
        local parsed = packets.parse('incoming', data)
        -- The game's own raise message is blocked: the client holds the merit one until the merit menu opens, and NPC menus hang until then.
        local message = pendingKind == 'jp' and 720 or pendingKind == 'trust' and 828 or 380
        local param = pendingKind == 'trust' and pendingId or pendingId / 2
        if parsed['Message'] == message and parsed['Param 1'] == param then
            debugLog(('Blocked the game message for %s.'):format(pointName(pendingKind, pendingId)))
            return true
        end
    elseif id == 0x063 and data:byte(5) == 2 then
        local parsed = packets.parse('incoming', data)
        meritPoints = parsed['Merit Points']
        maxMeritPoints = parsed['Max Merit Points']
        debugLog(('0x063 order 2: %s banked, limit %d.'):format(pointsText('merits', meritPoints), maxMeritPoints))
        if pendingKind == 'merits' then pendingPointsSeen = true end
        checkConfirmed()
        checkAutoSpend('merits')
    elseif id == 0x063 and data:byte(5) == 5 then
        for jobId = 1, 22 do
            jpPoints[jobId] = data:unpack('H', 0x0C + jobId * 6 + 3)
        end
        local player = windower.ffxi.get_player()
        debugLog(('0x063 order 5: %s banked on main job.'):format(pointsText('jp', player and jpPoints[player.main_job_id] or 0)))
        if pendingKind == 'jp' then pendingPointsSeen = true end
        checkConfirmed()
        checkAutoSpend('jp')
    elseif id == 0x08E then
        trustPoints = data:unpack('H', 5)
        for category = 8, 18 do
            trustLevels[category] = data:byte(9 + category)
            trustCosts[category] = data:unpack('H', 41 + category * 2)
        end
        debugLog(('0x08E: %s banked.'):format(pointsText('trust', trustPoints)))
        if pendingKind == 'trust' and pendingId then
            debugLog(('  %s: level %d, next cost %d.'):format(pointName('trust', pendingId), trustLevels[pendingId], trustCosts[pendingId]))
            if trustLevels[pendingId] == pendingLevel + 1 then pendingEntrySeen = true end
            pendingPointsSeen = true
        end
        checkConfirmed()
    end
end)

windower.register_event('outgoing chunk', function(id)
    if id ~= 0x00C then return end
    local thisList = meritListNumber
    coroutine.schedule(function()
        if meritListSeen or meritListNumber ~= thisList then return end
        meritListSeen = true
        checkAutoSpend('merits')
    end, 15)
end)

windower.register_event('status change', function(newStatus)
    if newStatus == 0 or newStatus == 1 or newStatus == 33 then
        checkAutoSpend('merits')
        checkAutoSpend('jp')
    end
end)

windower.register_event('load', function()
    local player = windower.ffxi.get_player()
    if not player then return end
    for jobId = 1, 22 do
        local jobData = player.job_points[res.jobs[jobId].ens:lower()]
        if jobData then jpPoints[jobId] = jobData.jp end
    end
    debugLog('Sent 0x0C0 job point request.')
    packets.inject(packets.new('outgoing', 0x0C0))
end)

windower.register_event('logout', function()
    windower.send_command('lua reload bigspender')
end)
