--load stuff
yaml = require('lyaml')

colors = {
    ['0'] = "Black",
    ['1'] = "Dark blue",
    ['2'] = "Dark green",
    ['3'] = "Dark aqua",
    ['4'] = "Dark red",
    ['5'] = "Dark purple",
    ['6'] = "Gold(default team color)",
    ['7'] = "Gray",
    ['8'] = "Dark gray",
    ['9'] = "Blue",
    ['a'] = "Green",
    ['b'] = "Aqua",
    ['c'] = "Red",
    ['d'] = "Light purple",
    ['e'] = "Yellow",
    ['f'] = "White",
    ['g'] = "Minecoin",
    ['h'] = "Quartz",
    ['i'] = "Iron",
    ['j'] = "Netherite",
    ['m'] = "Redstone",
    ['n'] = "Copper",
    ['p'] = "Gold",
    ['q'] = "Emerald",
    ['s'] = "Diamond",
    ['t'] = "Lapis",
    ['u'] = "Amethyst"
}

--stolen functions
function exists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end

function isdir(path)
   -- "/" works on both Unix and Windows
   return exists(path.."/")
end

function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('ls -a "'..directory..'"')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

local function len(t)
    local n = 0

    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

--cli arguments stuff(I wrote it, simple, but still I like it)
function help()
    print("Usage: script.lua [path to data] [output folder]")
    os.exit()
end

if #arg<2 then
    help()
end

dataPath = arg[1]
outputPath = arg[2]

--more stolen functions
function checkDirectory(path)
    local exists, err = isdir(path)
    if err then
        print("Error: "..err)
        return(false)
    else
        return(exists)
    end
end

function read_file(path)
    local file = assert(io.open(path, 'r'))
    local content = file:read('*all')
    file:close()
    return content
end

function sortDict(dict)
    local sortable = {}

    for key, value in pairs(dict) do
        table.insert(sortable, {key = key, value = value})
    end

    table.sort(sortable, function(a, b)
        return a.value > b.value
    end)

    return sortable
end

--my functions
function loadYmlFile(path)
    local ymlFile = path
    local ymlContent = read_file(ymlFile)
    local ymlData, err = yaml.load(ymlContent)

    if err then
        print('Error parsing YAML:', err)
    else
        return ymlData
    end
end

function loadData(dataName, path, dataNameShort)
    print("Loading "..dataName)

    local contents = scandir(path)
    local t = {}
    for i=3, #contents do
        local str = contents[i]
        t[str:sub(1, #str-4)] = loadYmlFile(path..'/'..contents[i])
    end

    print("Loaded data of "..len(t).." "..dataNameShort)

    return t
end

function getUsername(uuid)
    return essentialsUserdata[uuid]["last-account-name"] or uuid
end

function getTeamName(id)
    return teams[id].name
end

function doChecks()
    print("Checking if data path is valid")
    if not checkDirectory(dataPath) then
        os.exit()
    else
        print("[pass]")
    end

    print("Checking if Essentials userdata exists")
    if not checkDirectory(dataPath..'/Essentials/userdata') then
        print("Can't proceed without Essentials userdata")
        os.exit()
    else
        print("[pass]")
    end

    print("Making sure it's not empty")
    local contents = scandir(dataPath..'/Essentials/userdata')
    if #contents==2 then --2 means it contains only . and .., so it's empty
        print("Can't proceed without Essentials userdata")
        os.exit()
    else
        print("[pass]")
    end

    betterTeams = false

    --check for BetterTeams
    if checkDirectory(dataPath..'/BetterTeams/teamInfo') then
        local contents = scandir(dataPath..'/BetterTeams/teamInfo')
        if #contents>2 then
            print("Found BetterTeams")
            betterTeams = true
        end
    end
end

function makeDirectory(dir)
    local path = outputPath..'/'..dir
    print("Creating "..path)
    os.execute("mkdir "..path)
end

function tableToSrting(t, fun)
    local str = ""
    for i=1, #t do
        local thing

        if fun then
            thing = fun(t[i])
        else
            thing = t[i]
        end

        str = str..thing..", "
    end
    str = str:sub(1, #str-2)

    return str
end

function writePlayerStats()
    print("Writing player stats")
    local file = io.open(outputPath.."/players/players.txt", "w")

    local noStatUUIDs = {}
    for k,v in pairs(essentialsUserdata) do
        local player = ""
        local hasMoney = false
        local setHome = false
        local team = {}

        local money = v.money
        if money ~= '0' then
            hasMoney = true
        end

        local home = v.homes
        if home then
            setHome = true
        end

        if betterTeams then
            for teamID, teamData in pairs(teams) do
                for i=1, #teamData.players do
                    local str = teamData.players[i]
                    -- Escape hyphen in k before using it in string.find
                    local escapedK = k:gsub("-", "%%-")
                    if str:find(escapedK) then
                        team.name = teamData.name
                        if str:find("OWNER") then
                            team.isOwner = true
                        end
                        --check for rank
                        local _, pos1 = str:find(",", 1)
                        local _, pos2 = str:find(",", pos1 + 1)

                        if pos1 and pos2 then
                            -- Extract substring after the second comma
                            local result = str:sub(pos2 + 1)
                            --print(result)
                            team.rank = result
                        end

                        break
                    end

                end
                if team.name then
                    break  -- No need to continue checking other teams if we found a match
                end
            end
        end

        if hasMoney or setHome or team.name then
            local title = getUsername(k)
            player = player.."==="..title.."===\n"

            if hasMoney then
                player = player.."Money: "..money..'\n'
            end

            if setHome then
                local home = v.homes.home
                player = player.."Home: "..home['world-name']..' x:'..home.x..' y:'..home.y..' z:'..home.z..'\n'
            end

            if team.name then
                if not teamPositions then
                    teamPositions = {}
                end

                local suffix1 = ""
                local suffix2 = ""
                if team.isOwner then
                    suffix1 = "(OWNER)"
                end
                if team.rank then
                    suffix2 = "["..team.rank.."]"
                end
                player = player.."Team: "..team.name..suffix1..suffix2..'\n'

                teamPositions[k] = title..suffix1..suffix2
            end

            file:write(player)
            file:write('\n')
        else
            table.insert(noStatUUIDs, k)
        end
    end


    if #noStatUUIDs>0 then
        file:write("---Players with no stats---\n")
        for i=1, #noStatUUIDs do
            local username = getUsername(noStatUUIDs[i])
            file:write(username..'\n')
        end
    end

    file:close()

    playerBalances = {}
    for k,v in pairs(essentialsUserdata) do
        if v.money~='0' then
            playerBalances[k] = tonumber(v.money)
        end
    end

    playerBalances = sortDict(playerBalances)
end

function generateBalanceTop()
    print("Generating balance top")
    local file = io.open(outputPath.."/players/balance top.txt", "w")

    local n = 0
    for _, entry in ipairs(playerBalances) do
        n=n+1
        local name = getUsername(entry.key)
        file:write(n..". "..name..": "..entry.value..'\n')
    end
end

function writeTeamInfo()
    print("Writing team info")
    local file = io.open(outputPath.."/teams/teams.txt", "w")

    for k,v in pairs(teams) do
        local desc = v.description
        local open = tostring(v.open)
        local home = v.home
        local color = v.color
        local players = v.players
        local level = v.level
        local tag = v.tag
        local score = v.score
        local bans = v.bans
        local warps = v.warps
        local allies = v.allies

        file:write("==="..v.name.."===\n")
        if desc~='' then
            file:write("Description: "..desc..'\n')
        end
        file:write("Open: "..open..'\n')
        if home~='' then
            file:write("Home: "..home..'\n')
        end
        file:write("Color: "..colors[color]..'\n')

        local playersString = ""
        for i=1, #players do
            local str = players[i]
            local escaped = str:gsub("-", "%%-")
            str = str:sub(1, str:find(',')-1)

            playersString = playersString..teamPositions[str]..", "
        end
        playersString = playersString:sub(1, #playersString-2)
        file:write("Players: "..playersString..'\n')

        file:write("Level: "..level..'\n')
        if tag=='' then
            tag = v.name
        end
        file:write("Tag: "..tag..'\n')

        if score then
            file:write("Score: "..score..'\n')
        end

        if bans then
            local bannedPlayers = tableToSrting(bans, getUsername)
            file:write("Banned players: "..bannedPlayers..'\n')
        end

        if warps then
            local warpsList = tableToSrting(warps)
            file:write("Warps: "..warpsList..'\n')
        end

        if allies then
            local alliesString = tableToSrting(allies, getTeamName)
            file:write("Allies: "..alliesString..'\n')
        end

        file:write('\n')
    end

    file:close()
end

function generateStats()
    print("Creating the output directory")
    os.execute("mkdir "..outputPath)

    makeDirectory("players")
    if betterTeams then
        makeDirectory("teams")
    end

    writePlayerStats()

    if len(playerBalances)>0 then
        generateBalanceTop()
    end

    if betterTeams then
        writeTeamInfo()
    end
end

--this is where it begins doing stuff
doChecks()

essentialsUserdata = loadData("Essentials userdata", dataPath.."/Essentials/userdata", "players")
if betterTeams then
    teams = loadData("teams", dataPath..'/BetterTeams/teamInfo', "teams")
end

generateStats()
