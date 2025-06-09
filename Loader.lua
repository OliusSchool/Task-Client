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

local function ExtractVersion(Content)
    local Version = Content:match('Version%s*=%s*{%s*"([%d%.]+)"')
    return Version
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
        return true, Response.Body
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

local function RetryFolder(Folder, MaxRetries)
    local Retries = 0
    local Success = false
    
    while Retries < MaxRetries do
        local Files = GetFolderFiles(Folder)
        
        if #Files > 0 then
            for _, File in ipairs(Files) do
                if DownloadFile(File) then
                    Success = true
                end
            end
            
            if Success then
                return true
            end
        end
        
        warn("Retrying download for folder: " .. Folder .. " (attempt " .. (Retries + 1) .. "/" .. MaxRetries .. ")")
        Retries = Retries + 1
        wait(1)
    end
    
    warn("Failed to download folder after " .. MaxRetries .. " attempts: " .. Folder)
    return false
end

local function NeedsUpdate()
    local CurrentVersion = nil
    if isfile("Task/API/TaskAPI.lua") then
        local success, content = pcall(readfile, "Task/API/TaskAPI.lua")
        if success then
            CurrentVersion = ExtractVersion(content)
        end
    end

    local NewVersion = nil
    local Url = GitUrl .. "API/TaskAPI.lua"
    local Response = syn and syn.request({Url = Url, Method = "GET"}) or 
                    request and request({Url = Url, Method = "GET"}) or 
                    http_request and http_request({Url = Url, Method = "GET"})
    
    if Response and Response.StatusCode == 200 then
        NewVersion = ExtractVersion(Response.Body)
    end

    if not NewVersion then
        warn("Failed to fetch remote Version, skipping update check")
        return false
    end

    if not CurrentVersion then
        warn("No local Version found, installation needed")
        return true
    end

    if CurrentVersion ~= NewVersion then
        warn("Version changed from " .. CurrentVersion .. " to " .. NewVersion .. ", update needed")
        return true
    end
    
    warn("Versions match (" .. CurrentVersion .. "), no update needed")
    return false
end

local function CleanInstallation()
    warn("Performing clean installation...")
    
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

    local FilesToDelete = {
        "Task/API/TaskAPI.lua",
        "Task/API/Categories.lua"
    }
    
    for _, File in ipairs(FilesToDelete) do
        if isfile(File) then
            delfile(File)
        end
    end
end

if NeedsUpdate() then
    CleanInstallation()
end

local FolderDownload = {"API", "Games", "Assets", "Configs"}
local Retry = 3

for _, Folder in ipairs(FolderDownload) do
    RetryFolder(Folder, Retry)
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

local TaskAPI = RunFile("Task/API/TaskAPI.lua")

if TaskAPI then
    getgenv().TaskAPI = TaskAPI

    RunFile("Task/API/Categories.lua")

    if getgenv().TaskClient and getgenv().TaskClient.API then
        local Version = "unknown"
        if TaskAPI.Version and type(TaskAPI.Version) == "table" and #TaskAPI.Version > 0 then
            Version = TaskAPI.Version[1]
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

print("heelo")