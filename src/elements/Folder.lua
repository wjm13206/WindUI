local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local UserInputService = cloneref(game:GetService("UserInputService"))

local Creator = require("../modules/Creator")
local New = Creator.New

local Page = require("../components/window/Page")

local Element = {}

-- 文件夹：一行外观 + 子页面容器，行为对标真实文件系统
-- 父容器既可以是 Tab，也可以是上级 Folder；叶子文件与子文件夹混排
function Element:New(Config)
	local Window = Config.Window
	local RootTab = Config.Tab
	local Nav = RootTab and RootTab.Navigator or nil -- 本 Tab 的导航器（Tab.New 内已创建）
	local ParentTable = Config.ParentTable
	local ParentFolder = (ParentTable and ParentTable.__type == "Folder") and ParentTable or nil

	local Folder = {
		__type = "Folder",
		Title = Config.Title or "新建文件夹",
		Desc = Config.Desc,
		Icon = Config.Icon or "folder",
		Locked = Config.Locked or false,
		LockedTitle = Config.LockedTitle,
		Elements = {},
		Depth = (ParentFolder and ParentFolder.Depth or 0) + 1,
		ParentFolder = ParentFolder,
		RootTab = RootTab,
		UIElements = {},
		Page = nil,
	}

	local CanOpen = true

	-- 文件夹行：复用通用 Element 外壳，保证与 Button 等文件行风格一致
	Folder.FolderFrame = require("../components/window/Element")({
		Title = Folder.Title,
		Desc = Folder.Desc,
		Parent = Config.Parent,
		Window = Window,
		Color = Config.Color,
		Justify = "Between",
		TextOffset = 84,
		Hover = true,
		Scalable = true,
		Tab = RootTab,
		Index = Config.Index,
		ElementTable = Folder,
		ParentConfig = Config,
		Image = Folder.Icon,
		ImageSize = 20,
		IconThemed = Config.IconThemed,
	})

	local Main = Folder.FolderFrame.UIElements.Main

	-- 右侧：数量 + 进入箭头（不抢点击，点透到行本身）
	local CountLabel = New("TextLabel", {
		Text = "0 项",
		TextSize = 13,
		TextTransparency = 0.4,
		ThemeTag = {
			TextColor3 = "Text",
		},
		FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
	})

	local Chevron = Creator.Image(
		"chevron-right",
		"chevron:" .. Folder.Title,
		0,
		Window.Folder,
		"FolderChevron",
		true
	)
	Chevron.Size = UDim2.new(0, 18, 0, 18)

	local RightBox = New("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = "XY",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
	}, {
		CountLabel,
		Chevron,
		New("UIListLayout", {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 6),
		}),
	})
	RightBox.Parent = Main

	Folder.UIElements.Row = Main
	Folder.UIElements.Count = CountLabel

	function Folder:RefreshCount()
		local n = #Folder.Elements
		if CountLabel then
			CountLabel.Text = tostring(n) .. " 项"
		end
		if Folder.Page then
			local hint = Folder.Page:FindFirstChild("EmptyHint")
			if hint then
				hint.Visible = (n == 0)
			end
		end
	end

	function Folder:GetPath()
		local parts = {}
		local cur = Folder
		while cur do
			table.insert(parts, 1, cur.Title)
			cur = cur.ParentFolder
		end
		if RootTab then
			table.insert(parts, 1, RootTab.Title)
		end
		return table.concat(parts, " / ")
	end

	function Folder:Open()
		if Folder.Locked or not CanOpen then
			return
		end
		if Nav then
			Nav:Push(Folder)
		end
	end

	function Folder:Close()
		if Nav and #Nav.Stack > 0 then
			if Nav.Stack[#Nav.Stack] == Folder then
				Nav:Pop()
			end
		end
	end

	function Folder:Lock(title)
		Folder.Locked = true
		CanOpen = false
		return Folder.FolderFrame:Lock(title or Folder.LockedTitle)
	end

	function Folder:Unlock()
		Folder.Locked = false
		CanOpen = true
		return Folder.FolderFrame:Unlock()
	end

	-- 子页面走 Page 工厂：与 Tab 根页面同一种 ScrollingFrame，平时隐藏，进入时显示
	Folder.Page = Page.New({
		Window = Window,
		Gap = RootTab.Gap,
		Visible = false,
		Parent = RootTab.UIElements.ContainerFrameCanvas,
		Name = "FolderPage",
		EmptyHint = "此文件夹为空",
	})

	if Nav then
		Nav:Register(Folder)
	end

	-- 子内容递归加载：文件与子文件夹混排，子文件夹可继续下钻
	local ElementsModule = Config.ElementsModule
	ElementsModule.Load(
		Folder,
		Folder.Page,
		ElementsModule.Elements,
		Window,
		Config.WindUI,
		function()
			Folder:RefreshCount()
		end,
		ElementsModule,
		Config.UIScale,
		RootTab
	)

	Folder:RefreshCount()

	-- 删除行时同步刷新数量（新增已由 OnElementCreate 回调覆盖）
	Creator.AddSignal(Folder.Page.ChildRemoved, function()
		task.defer(function()
			if Folder.RefreshCount then
				Folder:RefreshCount()
			end
		end)
	end)

	-- 标题改名后同步面包屑
	local OrigSetTitle = Folder.FolderFrame.SetTitle
	function Folder.FolderFrame:SetTitle(text)
		OrigSetTitle(self, text)
		if Nav then
			for _, f in next, Nav.Stack do
				if f == Folder then
					Nav:Update()
					break
				end
			end
		end
	end

	-- 行销毁时从导航摘除并连带回收子页面，防止切页残留
	local OrigDestroy = Folder.FolderFrame.Destroy
	function Folder.FolderFrame:Destroy()
		if Nav then
			Nav:Remove(Folder)
		end
		if Folder.Page then
			Folder.Page:Destroy()
			Folder.Page = nil
		end
		OrigDestroy(self)
	end

	if Folder.Locked then
		Folder:Lock()
	end

	-- 单击选中高亮，双击进入；触屏单击直接进入
	local lastClick = 0
	Creator.AddSignal(Main.MouseButton1Click, function()
		if Folder.Locked or not CanOpen then
			return
		end
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		if touchOnly then
			Folder:Open()
			return
		end
		local now = os.clock()
		if now - lastClick < 0.35 then
			lastClick = 0
			Folder:Open()
		else
			lastClick = now
			Folder.FolderFrame:Highlight()
		end
	end)

	return Folder.__type, Folder
end

return Element
