-- Task Loader for Task-Client with proper version check
local GitUrl = "https://raw.githubusercontent.com/OliusSchool/Task-Client/main/"
local Folders = {
    "Task",
    "Task/API",
    "Task/Games",
    "Task/Assets",
    "Task/Configs"
}

-- Ensure folder structure exists
for _, Folder in ipairs(Folders) do
    if not isfolder(Folder) then
        makefolder(Folder)
    end
end

-- Download helper
local function httpGet(Url)
    if syn then
        return syn.request({Url = Url, Method = "GET"})
    elseif request then
        return request({Url = Url, Method = "GET"})
    elseif http_request then
        return http_request({Url = Url, Method = "GET"})
    else
        error("Unsupported executor")
    end
end

-- Download and save a file to Task/Path
local function DownloadFile(Path)
    local Url = GitUrl .. Path
    local SavePath = "Task/" .. Path
    -- ensure parent folder
    local Parent = SavePath:match("(.+)/[^/]+$")
    if Parent and not isfolder(Parent) then
        makefolder(Parent)
    end
    local resp = httpGet(Url)
    if resp and resp.StatusCode == 200 then
        writefile(SavePath, resp.Body)
        return true
    else
        warn("Failed to download " .. Url)
        return false
    end
end

-- Recursive listing of files in a GitHub folder
local function GetFolderFiles(Folder)
    local api = "https://api.github.com/repos/OliusSchool/Task-Client/contents/" .. Folder
    local resp = httpGet(api)
    if not resp or resp.StatusCode ~= 200 then
        warn("Failed to list " .. Folder)
        return {}
    end
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(resp.Body)
    end)
    if not ok then warn("Invalid JSON for "..Folder); return {} end
    local list = {}
    for _, entry in ipairs(data) do
        if entry.type == "file" then
            table.insert(list, Folder .. "/" .. entry.name)
        elseif entry.type == "dir" then
            for _, sub in ipairs(GetFolderFiles(entry.path)) do
                table.insert(list, sub)
            end
        end
    end
    return list
end

-- Retry download for all files in folder
local function RetryDownload(Folder, maxRetries)
    local files = GetFolderFiles(Folder)
    if #files == 0 then return false end
    for attempt=1, maxRetries do
        local allOK = true
        for _, f in ipairs(files) do
            if not DownloadFile(f) then allOK = false end
        end
        if allOK then return true end
        warn("Retry "..attempt.." for "..Folder)
        wait(1)
    end
    warn("Giving up on "..Folder)
    return false
end

-- Read local version if exists
local function GetCurrentVersion()
    local path = "Task/API/Version.txt"
    if isfile(path) then
        return (readfile(path):gsub("%s+", ""))
    end
    return nil
end

-- Fetch version string from GitHub without saving
local function FetchRemoteVersion()
    local Url = GitUrl .. "API/Version.txt"
    local resp = httpGet(Url)
    if resp and resp.StatusCode == 200 then
        return (resp.Body:gsub("%s+", ""))
    end
    return nil
end

-- Installation cleanup
local function Installation()
    for _, d in ipairs({"Task/API", "Task/Games", "Task/Assets"}) do
        if isfolder(d) then delfolder(d) end
        makefolder(d)
    end
end

-- Version check and update
local currentVersion = GetCurrentVersion()
local remoteVersion = FetchRemoteVersion()
local retries = 3

if remoteVersion and currentVersion ~= remoteVersion then
    warn("Updating from v"..tostring(currentVersion).." to v"..remoteVersion)
    Installation()
    -- re-download everything fresh
    RetryDownload("API", retries)
    RetryDownload("Games", retries)
    RetryDownload("Assets", retries)
    -- ensure configs
    if not isfolder("Task/Configs") then RetryDownload("Configs", retries) end
else
    -- initial download if no local version
    if not currentVersion then
        RetryDownload("API", retries)
        RetryDownload("Games", retries)
        RetryDownload("Assets", retries)
        if not isfolder("Task/Configs") then RetryDownload("Configs", retries) end
    end
end

-- Helper to run a Lua file
local function RunFile(path)
    if not isfile(path) then warn("Missing: "..path); return nil end
    local ok, content = pcall(readfile, path)
    if not ok then warn("Read error: "..path); return nil end
    local fn, err = loadstring(content)
    if not fn then warn("Compile error "..path..": "..err); return nil end
    return fn()
end

-- Load TaskAPI
local apiPath = "Task/API/TaskAPI.lua"
if not isfile(apiPath) then error("Critical: TaskAPI.lua missing") end
local TaskAPI = RunFile(apiPath)
getgenv().TaskAPI = TaskAPI

-- Load Categories
if isfile("Task/API/Categories.lua") then RunFile("Task/API/Categories.lua") end

-- Notify
local versionStr = remoteVersion or currentVersion or "unknown"
if TaskAPI and TaskAPI.Notification then
    TaskAPI.Notification("Loader", "Task initialized! Version: "..versionStr, 3, "Success")
end