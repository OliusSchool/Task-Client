local TaskAPI = {
	Categories = {},
	Notifications = {},
	CurrentVersion = "1.0.1"
}

local TaskAssets = {
	CategoryFrame = "rbxassetid://95529966065994"
}

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local InputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

getgenv().TaskClient = getgenv().TaskClient or {}
getgenv().TaskClient.API = TaskAPI

local TaskGui = Instance.new("ScreenGui")
TaskGui.Name = "TaskGui"
TaskGui.Enabled = false
TaskGui.ResetOnSpawn = false
TaskGui.Parent = CoreGui

local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Name = "BlurEffect"
BlurEffect.Size = 20
BlurEffect.Enabled = false
BlurEffect.Parent = Lighting

local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "NotificationGui"
NotificationGui.ResetOnSpawn = false
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
NotificationGui.Parent = CoreGui

local NotificationsContainer = Instance.new("Frame")
NotificationsContainer.Name = "NotificationsContainer"
NotificationsContainer.Size = UDim2.new(0.25, 0, 0.4, 0)
NotificationsContainer.AnchorPoint = Vector2.new(1, 1)
NotificationsContainer.Position = UDim2.new(1, -20, 1, -20)
NotificationsContainer.BackgroundTransparency = 1
NotificationsContainer.Parent = NotificationGui

local NotificationListLayout = Instance.new("UIListLayout")
NotificationListLayout.SortOrder = Enum.SortOrder.LayoutOrder
NotificationListLayout.Padding = UDim.new(0, 10)
NotificationListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
NotificationListLayout.Parent = NotificationsContainer

local NotificationColors = {
	Client = Color3.fromRGB(15, 15, 15),
	Success = Color3.fromRGB(46, 204, 113),
	Error = Color3.fromRGB(231, 76, 60),
	Warning = Color3.fromRGB(241, 196, 15),
	Info = Color3.fromRGB(52, 152, 219)
}

function TaskAPI.Notification(Title, Message, Duration, Type)
	Title = Title
	Message = Message or "No Message has been set for this Notification"
	Duration = Duration
	Type = Type or "Client"

	local NotificationFrame = Instance.new("Frame")
	NotificationFrame.Name = "NotificationFrame"
	NotificationFrame.BackgroundColor3 = NotificationColors[Type] or NotificationColors.Info
	NotificationFrame.Size = UDim2.new(1, 0, 0, 50)
	NotificationFrame.BackgroundTransparency = 1
	NotificationFrame.ZIndex = 10
	NotificationFrame.LayoutOrder = #TaskAPI.Notifications + 1
	NotificationFrame.Parent = NotificationsContainer

	local UICorner = Instance.new("UICorner")
	UICorner.CornerRadius = UDim.new(0, 8)
	UICorner.Parent = NotificationFrame

	local NotificationTitle = Instance.new("TextLabel")
	NotificationTitle.Name = "NotificationTitle"
	NotificationTitle.Text = Title
	NotificationTitle.Font = Enum.Font.GothamBold
	NotificationTitle.TextSize = 16
	NotificationTitle.TextColor3 = Color3.new(1, 1, 1)
	NotificationTitle.BackgroundTransparency = 1
	NotificationTitle.Size = UDim2.new(0.9, 0, 0, 20)
	NotificationTitle.Position = UDim2.new(0.05, 0, 0.1, 0)
	NotificationTitle.TextXAlignment = Enum.TextXAlignment.Left
	NotificationTitle.ZIndex = 11
	NotificationTitle.Parent = NotificationFrame

	local MessageText = Instance.new("TextLabel")
	MessageText.Name = "MessageText"
	MessageText.Text = Message
	MessageText.Font = Enum.Font.Gotham
	MessageText.TextSize = 14
	MessageText.TextColor3 = Color3.new(1, 1, 1)
	MessageText.BackgroundTransparency = 1
	MessageText.Size = UDim2.new(0.9, 0, 0.6, 0)
	MessageText.Position = UDim2.new(0.05, 0, 0.5, 0)
	MessageText.TextWrapped = true
	MessageText.TextXAlignment = Enum.TextXAlignment.Left
	MessageText.TextYAlignment = Enum.TextYAlignment.Top
	MessageText.ZIndex = 11
	MessageText.Parent = NotificationFrame

	NotificationFrame.BackgroundTransparency = 1
	NotificationTitle.TextTransparency = 1
	MessageText.TextTransparency = 1

	local FadeIn = TweenService:Create(NotificationFrame, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.2
	})

	local TextFadeIn = TweenService:Create(NotificationTitle, TweenInfo.new(0.3), {
		TextTransparency = 0
	})

	local MessageFadeIn = TweenService:Create(MessageText, TweenInfo.new(0.3), {
		TextTransparency = 0
	})

	FadeIn:Play()
	TextFadeIn:Play()
	MessageFadeIn:Play()

	table.insert(TaskAPI.Notifications, NotificationFrame)

	task.spawn(function()
		task.wait(Duration)

		local FadeOut = TweenService:Create(NotificationFrame, TweenInfo.new(0.3), {
			BackgroundTransparency = 1
		})

		local TextFadeOut = TweenService:Create(NotificationTitle, TweenInfo.new(0.3), {
			TextTransparency = 1
		})

		local MessageFadeOut = TweenService:Create(MessageText, TweenInfo.new(0.3), {
			TextTransparency = 1
		})

		FadeOut:Play()
		TextFadeOut:Play()
		MessageFadeOut:Play()

		FadeOut.Completed:Wait()
		NotificationFrame:Destroy()
		table.remove(TaskAPI.Notifications, table.find(TaskAPI.Notifications, NotificationFrame))
	end)
end

function TaskAPI:CreateCategory(CData)

	if not CData or type(CData.Name) ~= "string" or CData.Name == "" then
		TaskAPI.Notification("API Error", "Missing or invalid category name", 5, "Error")
		return
	end

	for _, Existing in ipairs(self.Categories) do
		if Existing.Name == CData.Name then
			TaskAPI.Notification("API Error", "Category '".. CData.Name .. "' already exists", 5, "Error")
			return
		end
	end

	local TaskFrame = Instance.new("Frame")
	TaskFrame.Name = "TaskFrame_" .. CData.Name
	TaskFrame.Size = UDim2.new(0, 200, 0, 40)
	TaskFrame.AnchorPoint = Vector2.new(0.5, 0)
	TaskFrame.Position = CData.Position
	TaskFrame.BackgroundTransparency = 1
	TaskFrame.Visible = false
	TaskFrame.Parent = TaskGui

	local TaskFrameUICorner = Instance.new("UICorner")
	TaskFrameUICorner.CornerRadius = UDim.new(0, 20)
	TaskFrameUICorner.Parent = TaskFrame

	local CategoryFrame = Instance.new("ImageLabel")
	CategoryFrame.Name = "CategoryFrame"
	CategoryFrame.Image = TaskAssets.CategoryFrame
	CategoryFrame.Size = UDim2.new(1, 0, 0, 40)
	CategoryFrame.AnchorPoint = Vector2.new(0.5, 0)
	CategoryFrame.Position = UDim2.new(0.5, 0, 0, 0)
	CategoryFrame.ImageColor3 = Color3.fromRGB(11, 11, 11)
	CategoryFrame.BackgroundTransparency = 1
	CategoryFrame.ZIndex = 1
	CategoryFrame.Parent = TaskFrame

	local CategoryText = Instance.new("TextLabel")
	CategoryText.Text = CData.Name
	CategoryText.Size = UDim2.new(1, 0, 1, 0)
	CategoryText.AnchorPoint = Vector2.new(0.5, 0.5)
	CategoryText.Position = UDim2.new(0.5, 0, 0.5, 0)
	CategoryText.Font = Enum.Font.GothamBold
	CategoryText.TextSize = 18
	CategoryText.TextColor3 = Color3.fromRGB(255, 255, 255)
	CategoryText.BackgroundTransparency = 1
	CategoryText.Parent = CategoryFrame

	table.insert(TaskAPI.Categories, {
		Name = CData.Name,
		TaskFrame = TaskFrame,
		CategoryFrame = CategoryFrame,
	})
end

InputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then return end
	if Input.KeyCode == Enum.KeyCode.LeftAlt then
		TaskGui.Enabled = not TaskGui.Enabled
		BlurEffect.Enabled = TaskGui.Enabled
		for _, Category in ipairs(TaskAPI.Categories) do
			Category.TaskFrame.Visible = TaskGui.Enabled
		end
	end
end)

return TaskAPI