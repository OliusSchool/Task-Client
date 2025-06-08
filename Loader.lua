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

    local Response
    if syn then
        Response = syn.request({Url = Url, Method = "GET"})
    elseif request then
        Response = request({Url = Url, Method = "GET"})
    elseif http_request then
        Response = http_request({Url = Url, Method = "GET"})
    else
        error("bad executor")
    end
    
    if Response.StatusCode == 200 then
        writefile(SavePath, Response.Body)
        return true
    else
        warn("Failed to download: " .. Url)
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
        erro("unsupported executor")
    end
    
    local Files = {}
    local Data = game:GetService("HttpService"):JSONDecode(Response.Body)
    
    for _, item in ipairs(Data) do
        if item.type == "file" then
            table.insert(Files, Folder .. "/" .. item.name)
        end
    end
    
    return Files
end

local FolderDownload = {"API", "Games", "Assets"}

for _, Folder in ipairs(FolderDownload) do
    local Files = GetDirectoryContents(Folder)
    
    if #Files > 0 then
        for _, File in ipairs(Files) do
            DownloadFile(File)
        end
    else
        warn("No Files found in: " .. Folder)
    end
end

local function ExecuteFile(Path)
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
        TaskAPI.Notification("Loader", "Task Client initialized successfully!", 3, "Success")
    else
        TaskAPI.Notification("Loader", "Task Client failed to initialize properly", 5, "Error")
    end
end