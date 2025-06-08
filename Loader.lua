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

local function DownloadFile(Path, SkipExistings)
    SkipExistings = SkipExistings or false
    local Url = GitUrl .. Path
    local SavePath = "Task/" .. Path

    if SkipExistings and isfile(SavePath) then
        return true
    end

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

local function RetryFolder(Folder, MaxRetries, SkipExistings)
    local Retries = 0
    local Success = false
    
    while Retries < MaxRetries do
        local Files = GetFolderFiles(Folder)
        
        if #Files > 0 then
            for _, File in ipairs(Files) do
                if DownloadFile(File, SkipExistings) then
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

local function GetCurrentVersion()
    if isfile("Task/Version.txt") then
        return readfile("Task/Version.txt")
    end
    return nil
end

local function ExtractVersionFromContent(content)
    local Pattern = 'Version%s*=%s*{%s*"([%d%.]+)"%s*}'
    local Version = content:match(Pattern)
    return Version
end

local function GetNewVersion()
    local Url = GitUrl .. "API/TaskAPI.lua"
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
        return ExtractVersionFromContent(Response.Body)
    end
    return nil
end

local function CleanInstallation()
    local FoldersToDelete = {
        "Task/API",
        "Task/Games",
        "Task/Assets"
    }
    
    for _, Folder in ipairs(FoldersToDelete) do
        if isfolder(Folder) then
            delfolder(Folder)
        end
        makefolder(Folder)
    end
end

local CurrentVersion = GetCurrentVersion()
local NewVersion = GetNewVersion()

if NewVersion and CurrentVersion ~= NewVersion then
    warn("Version changed from " .. tostring(CurrentVersion) .. " to " .. NewVersion .. ". Cleaning installation.")
    CleanInstallation()
end

local FolderDownload = {"API", "Games", "Assets", "Configs"}
local RetryCount = 3

for _, Folder in ipairs(FolderDownload) do
    local SkipExisting = (Folder == "Configs")
    RetryFolder(Folder, RetryCount, SkipExisting)
end

if NewVersion then
    writefile("Task/Version.txt", NewVersion)
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
        TaskAPI.Notification("Loader", "Task initialized Successfully! Version: " .. (NewVersion or "unknown"), 3, "Success")
    else
        warn("Task failed to load properly!")
        if TaskAPI.Notification then
            TaskAPI.Notification("Loader", "Task failed to load properly!", 5, "Error")
        end
    end
else
    warn("Critical error: Failed to load TaskAPI")
end