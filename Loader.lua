-- Task Loader for Task-Client with proper version check and debug logs
local GitUrl = "https://raw.githubusercontent.com/OliusSchool/Task-Client/main/"
local Folders = {"Task","Task/API","Task/Games","Task/Assets","Task/Configs"}

-- Ensure folder structure
for _, f in ipairs(Folders) do if not isfolder(f) then makefolder(f) end end

-- HTTP GET helper
local function httpGet(url)
    if syn then return syn.request({Url=url,Method="GET"})
    elseif request then return request({Url=url,Method="GET"})
    elseif http_request then return http_request({Url=url,Method="GET"})
    else error("Unsupported executor") end
end

-- Download and write file
local function download(path)
    local url = GitUrl .. path
    local save = "Task/"..path:gsub("^/*","")
    local dir = save:match("(.+)/[^"]+")
    if dir and not isfolder(dir) then makefolder(dir) end
    local res = httpGet(url)
    if res and res.StatusCode==200 then
        writefile(save, res.Body)
        print("Downloaded: "..path)
        return true
    else
        warn("Failed to download: "..url)
        return false
    end
end

-- Recursively list repo files
local function listFiles(folder)
    local apiURL = "https://api.github.com/repos/OliusSchool/Task-Client/contents/"..folder
    local res = httpGet(apiURL)
    if not (res and res.StatusCode==200) then warn("List error: "..folder); return {} end
    local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(res.Body) end)
    if not ok then warn("JSON decode failed for "..folder); return {} end
    local out={}
    for _,entry in ipairs(data) do
        if entry.type=="file" then table.insert(out,folder.."/"..entry.name)
        elseif entry.type=="dir" then
            for _,sub in ipairs(listFiles(entry.path)) do table.insert(out,sub) end
        end
    end
    return out
end

-- Retry download folder
local function retry(folder,max)
    local files=listFiles(folder)
    if #files==0 then return false end
    for i=1,max do
        local ok=true
        print("Retrying ",folder,"attempt",i)
        for _,f in ipairs(files) do if not download(f) then ok=false end end
        if ok then return true end
        wait(1)
    end
    warn("Giving up on "..folder)
    return false
end

-- Read and trim local version
local function getLocal()
    local p="Task/API/Version.txt"
    if isfile(p) then return readfile(p):gsub("%s+","") end
    return nil
end

-- Fetch remote version without saving
local function getRemote()
    local res=httpGet(GitUrl.."API/Version.txt")
    if res and res.StatusCode==200 then return res.Body:gsub("%s+","") end
    warn("Cannot fetch remote version")
    return nil
end

-- Clean install
local function clean()
    for _,d in ipairs({"Task/API","Task/Games","Task/Assets"}) do
        if isfolder(d) then delfolder(d) end; makefolder(d)
    end
end

-- Main update logic
local localV=getLocal()
local remoteV=getRemote()
print("Local version:",tostring(localV))
print("Remote version:",tostring(remoteV))
local retries=3
if remoteV and localV~=remoteV then
    print("Version changed. Updating from "..tostring(localV) .." to "..remoteV)
    clean()
    retry("API",retries)
    retry("Games",retries)
    retry("Assets",retries)
    if not isfolder("Task/Configs") then retry("Configs",retries) end
elseif not localV then
    print("No local version. First-time install")
    retry("API",retries)
    retry("Games",retries)
    retry("Assets",retries)
    if not isfolder("Task/Configs") then retry("Configs",retries) end
else
    print("Up-to-date. No update needed.")
end

-- Ensure version file is present and trimmed
if isfile("Task/API/Version.txt") then
    writefile("Task/API/Version.txt", remoteV or localV)
end

-- Load API
local function run(path)
    if not isfile(path) then warn("Missing:"..path);return end
    local s=readfile(path)
    local fn,err=loadstring(s)
    if not fn then warn(err);return end
    return fn()
end

local api=run("Task/API/TaskAPI.lua")
getgenv().TaskAPI=api
if isfile("Task/API/Categories.lua") then run("Task/API/Categories.lua") end
if api and api.Notification then api.Notification("Loader","Task init v"..(remoteV or localV),3,"Success") end