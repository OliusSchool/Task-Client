local GitUrl = "https://raw.githubusercontent.com/OliusSchool/Task-Client/main/"

local Folders = {
    "Task Client",
    "Task Client/API",
    "Task Client/Games",
    "Task Client/Assets"
}

for _, Folder in ipairs(Folders) do
    if not isfolder(Folder) then 
        makefolder(Folder)
    end
end

local function DownloadFile(Path)
    local Url = GitUrl .. Path
    local SavePath = "Task Client/" .. Path

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

local function GetDirectoryContents(Folder)
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
        -- Changed to use folder name instead of API URL
        warn("Failed to get files for folder: " .. Folder .. " (Status: " .. Response.StatusCode .. ")")
        return {}
    end
    
    local Files = {}
    local Success, Data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(Response.Body)
    end)
    
    if not Success then
        warn("Failed to parse GitHub API response for: " .. Folder)
        return {}
    end
    
    for _, item in ipairs(Data) do
        if item.type == "file" then
            table.insert(Files, Folder .. "/" .. item.name)
        elseif item.type == "dir" then
            local subFiles = GetDirectoryContents(item.path)
            for _, subFile in ipairs(subFiles) do
                table.insert(Files, subFile)
            end
        end
    end
    
    return Files
end

local function DownloadFolderWithRetry(Folder, maxRetries)
    local Retries = 0
    local Success = false
    
    while Retries < maxRetries do
        local Files = GetDirectoryContents(Folder)
        
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
        
        warn("Retrying download for folder: " .. Folder .. " (attempt " .. (Retries + 1) .. "/" .. maxRetries .. ")")
        Retries = Retries + 1
        wait(1)
    end
    
    warn("Failed to download folder after " .. maxRetries .. " attempts: " .. Folder)
    return false
end

local FolderDownload = {"API", "Games", "Assets"}
local Retry = 3

for _, Folder in ipairs(FolderDownload) do
    DownloadFolderWithRetry(Folder, Retry)
end

local function ExecuteFile(Path)
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

local TaskAPI = ExecuteFile("Task Client/API/TaskAPI.lua")

if TaskAPI then
    getgenv().TaskAPI = TaskAPI

    ExecuteFile("Task Client/API/Categories.lua")

    if getgenv().TaskClient and getgenv().TaskClient.API then
        TaskAPI.Notification("Loader", "Task Client initialized Successfully!", 3, "Success")
    else
        warn("Task Client failed to load properly!")
        if TaskAPI.Notification then
            TaskAPI.Notification("Loader", "Task Client failed to load properly!", 5, "Error")
        end
    end
else
    warn("Critical error: Failed to load TaskAPI")
end