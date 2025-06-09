local isfile = isfile or function(file)
    local suc, res = pcall(readfile, file)
    return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
    writefile(file, '')
end

local GitUrl = "https://raw.githubusercontent.com/OliusSchool/Task-Client/main/"
local CommitUrl = "https://api.github.com/repos/OliusSchool/Task-Client/commits/main"

-- Create necessary folders
for _, folder in {"Task", "Task/API", "Task/Games", "Task/Assets", "Task/Configs"} do
    if not isfolder(folder) then
        makefolder(folder)
    end
end

local function getLatestCommit()
    local response
    if syn then
        response = syn.request({Url = CommitUrl, Method = "GET"})
    elseif request then
        response = request({Url = CommitUrl, Method = "GET"})
    elseif http_request then
        response = http_request({Url = CommitUrl, Method = "GET"})
    else
        error("Unsupported executor")
    end
    
    if response.StatusCode ~= 200 then
        warn("Failed to get commit: " .. response.StatusCode)
        return nil
    end
    
    local success, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(response.Body)
    end)
    
    if success and data.sha then
        return data.sha
    end
    return nil
end

local function downloadFile(path)
    local url = GitUrl .. path
    local savePath = "Task/" .. path
    
    local parentDir = savePath:match("(.+)/[^/]+$")
    if parentDir and not isfolder(parentDir) then
        makefolder(parentDir)
    end

    local response
    if syn then
        response = syn.request({Url = url, Method = "GET"})
    elseif request then
        response = request({Url = url, Method = "GET"})
    elseif http_request then
        response = http_request({Url = url, Method = "GET"})
    else
        error("Unsupported executor")
    end
    
    if response.StatusCode ~= 200 then
        warn("Failed to download: " .. url .. " (" .. response.StatusCode .. ")")
        return false
    end
    
    local content = response.Body
    if path:match("%.lua$") then
        content = "--WATERMARK:" .. (readfile("Task/commit.txt") or "unknown") .. "\n" .. content
    end
    
    writefile(savePath, content)
    return true
end

local function wipeFolder(folder)
    if not isfolder(folder) then return end
    
    for _, file in pairs(listfiles(folder)) do
        if isfile(file) then
            local content = readfile(file)
            if content:find("^%-%-WATERMARK:") then
                delfile(file)
            end
        end
    end
end

-- Get current and latest commit
local currentCommit = isfile("Task/commit.txt") and readfile("Task/commit.txt") or "initial"
local latestCommit = getLatestCommit() or currentCommit

-- Update if commit changed
if currentCommit ~= latestCommit then
    warn("Updating from " .. currentCommit:sub(1,7) .. " to " .. latestCommit:sub(1,7))
    
    -- Wipe watermarked files
    wipeFolder("Task/API")
    wipeFolder("Task/Games")
    wipeFolder("Task/Assets")
    
    -- Download core files
    downloadFile("API/Version.txt")
    downloadFile("API/TaskAPI.lua")
    downloadFile("API/Categories.lua")
    
    -- Save new commit
    writefile("Task/commit.txt", latestCommit)
end

-- File loading function
local function loadFile(path)
    if not isfile(path) then
        warn("Missing file: " .. path)
        return nil
    end
    
    local content = readfile(path)
    if content:find("^%-%-WATERMARK:") then
        content = content:gsub("^%-%-WATERMARK:[^\n]*\n", "")
    end
    
    local func, err = loadstring(content)
    if not func then
        warn("Failed to load " .. path .. ": " .. err)
        return nil
    end
    
    return func()
end

-- Load main API
if not isfile("Task/API/TaskAPI.lua") then
    warn("Critical error: Missing TaskAPI.lua")
    return
end

local TaskAPI = loadFile("Task/API/TaskAPI.lua")

if TaskAPI then
    getgenv().TaskAPI = TaskAPI
    
    -- Load categories
    if isfile("Task/API/Categories.lua") then
        loadFile("Task/API/Categories.lua")
    end
    
    -- Show success message
    local version = isfile("Task/API/Version.txt") and readfile("Task/API/Version.txt") or "unknown"
    if TaskAPI.Notification then
        TaskAPI.Notification("Loader", "Task loaded successfully! v" .. version, 3, "Success")
    end
else
    warn("Failed to load TaskAPI")
end