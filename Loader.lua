local GitUrl = "https://raw.githubusercontent.com/OliusSchool/Task-Client/main/"

local Folders = {
    "Task",
    "Task/API",
    "Task/Games",
    "Task/Assets",
    "Task/Configs"
}

for _, Folder in ipairs(Folders) do
    if not isfolder(Folder) then 
        makefolder(Folder)
    end
end

local function DownloadFile(Path)
    local Url = GitUrl .. Path
    local SavePath = "Task/" .. Path

    local ParentDir = SavePath:match("(.+)/[^/]+$")
    if ParentDir and not isfolder(ParentDir) then
        makefolder(ParentDir)
    end

    local Response
    if syn then
        Response = syn.request({Url = Url, Method = "GET"})
    elseif request then
        Response = request({Url = Url, Method = "GET"})
    elseif http_request then
        Response = http_request({Url = Url, Method = "GET"})
    else
        error("Unsupported executor")
    end
    
    if Response.StatusCode == 200 then
        writefile(SavePath, Response.Body)
        return true
    else
        warn("Failed to download: " .. Url .. " (Status: " .. Response.StatusCode .. ")")
        return false
    end
end

local function GetFolderFiles(Folder)
    local APIUrl = "https://api.github.com/repos/OliusSchool/Task-Client/contents/" .. Folder
    local Response
    
    if syn then
        Response = syn.request({Url = APIUrl, Method = "GET"})
    elseif request then
        Response = request({Url = APIUrl, Method = "GET"})
    elseif http_request then
        Response = http_request({Url = APIUrl, Method = "GET"})
    else
        error("Unsupported executor")
    end
    
    if Response.StatusCode ~= 200 then
        warn("Failed to get files for folder: " .. Folder .. " (Status: " .. Response.StatusCode .. ")")
        return {}
    end
    
    local Files = {}
    local Success, Data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(Response.Body)
    end)
    
    if not Success then
        warn("Failed to read GitHub API response for: " .. Folder)
        return {}
    end
    
    for _, File in ipairs(Data) do
        if File.type == "file" then
            table.insert(Files, Folder .. "/" .. File.name)
        elseif File.type == "dir" then
            local SubFiles = GetFolderFiles(File.path)
            for _, SubFile in ipairs(SubFiles) do
                table.insert(Files, SubFile)
            end
        end
    end
    
    return Files
end

local function RetryDownload(Folder, MaxRetries)
    local Files = GetFolderFiles(Folder)
    if #Files == 0 then return false end
    
    local Retries = 0
    local Success = false
    
    while Retries < MaxRetries do
        Success = true
        for _, File in ipairs(Files) do
            if not DownloadFile(File) then
                Success = false
                warn("Failed to download: " .. File)
            end
        end
        
        if Success then
            return true
        end
        
        warn("Retrying folder: " .. Folder .. " (attempt " .. (Retries + 1) .. "/" .. MaxRetries .. ")")
        Retries = Retries + 1
        wait(1)
    end
    
    warn("Failed to download folder after " .. MaxRetries .. " attempts: " .. Folder)
    return false
end

local function GetCurrentVersion()
    if isfile("Task/API/Version.txt") then
        return readfile("Task/API/Version.txt")
    end
    return nil
end

local function GetNewVersion()
    local Success = DownloadFile("API/Version.txt")
    if Success then
        return readfile("Task/API/Version.txt")
    end
    return nil
end

local function Installation()
    local FoldersToClean = {
        "Task/API",
        "Task/Games",
        "Task/Assets"
    }
    
    for _, Folder in ipairs(FoldersToClean) do
        if isfolder(Folder) then
            delfolder(Folder)
            makefolder(Folder)
        end
    end
end

local CurrentVersion = GetCurrentVersion()
local NewVersion = GetNewVersion()

if NewVersion and CurrentVersion ~= NewVersion then
    warn("Version changed from " .. tostring(CurrentVersion) .. " to " .. NewVersion)
    Installation()
end

DownloadFile("API/Version.txt")
DownloadFile("API/TaskAPI.lua")
DownloadFile("API/Categories.lua")

local Retries = 3

RetryDownload("API", Retries)
RetryDownload("Games", Retries)
RetryDownload("Assets", Retries)

if not isfolder("Task/Configs") then
    RetryDownload("Configs", Retries)
end

local function RunFile(Path)
    if not isfile(Path) then
        warn("File not found: " .. Path)
        return nil
    end
    
    local Success, Content = pcall(readfile, Path)
    if not Success then
        warn("Failed to read file: " .. Path)
        return nil
    end
    
    local fn, Error = loadstring(Content)
    if not fn then
        warn("Failed to load " .. Path .. ": " .. Error)
        return nil
    end
    
    return fn()
end

if not isfile("Task/API/TaskAPI.lua") then
    warn("Critical error: TaskAPI.lua missing after installation!")
    return
end

local TaskAPI = RunFile("Task/API/TaskAPI.lua")

if TaskAPI then
    getgenv().TaskAPI = TaskAPI

    if isfile("Task/API/Categories.lua") then
        RunFile("Task/API/Categories.lua")
    else
        warn("Critical error: Categories.lua missing!")
    end

    if getgenv().TaskClient and getgenv().TaskClient.API then
        local Version = "unknown"
        if isfile("Task/API/Version.txt") then
            Version = readfile("Task/API/Version.txt")
        end
        
        TaskAPI.Notification("Loader", "Task initialized Successfully! Version: " .. Version, 3, "Success")
    else
        warn("Task failed to load properly!")
        if TaskAPI.Notification then
            TaskAPI.Notification("Loader", "Task failed to load properly!", 5, "Error")
        end
    end
else
    warn("Critical error: Failed to load TaskAPI")
end