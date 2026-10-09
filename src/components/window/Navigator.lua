-- 导航器：每个 Tab 一个实例，拥有页面栈与返回栏
-- 只有 Tab（根）与 Folder（子目录）是可 Push 的页面，其余元素一律 inline
local NavBar = require("./NavBar")

local Navigator = {}

-- 新建导航器并挂载返回栏
-- tab:  所属 Tab（读 ShowTabTitle / Title / NavBarHeight / UIElements）
-- opts: { Window 必填 }
function Navigator.New(tab, opts)
	local Window = opts.Window
	local Canvas = tab.UIElements.ContainerFrameCanvas

	local nav = {
		Tab = tab,
		RootPage = tab.UIElements.ContainerFrame,
		Stack = {},
		Pages = {},
		BarHeight = tab.NavBarHeight or 40,
	}

	nav.Bar = NavBar.New({
		Window = Window,
		Height = nav.BarHeight,
		Parent = Canvas,
		OnBack = function()
			nav:Pop()
		end,
		OnJump = function(level)
			nav:PopTo(level)
		end,
	})
	tab.UIElements.NavBar = nav.Bar.Frame

	-- 根据是否在子目录重新排布所有页面：子目录时隐藏 TabTitle，留出返回栏高度
	function nav:Layout()
		local inSub = #nav.Stack > 0
		local titleH = 0
		if not inSub and tab.ShowTabTitle then
			titleH = (Window.UIPadding * 2.4) + 12
		end
		local total = titleH + (inSub and nav.BarHeight or 0)
		local function layout(page)
			if not page then
				return
			end
			page.AnchorPoint = Vector2.new(0, 1)
			page.Position = UDim2.new(0, 0, 1, 0)
			page.Size = UDim2.new(1, 0, 1, -total)
		end
		layout(nav.RootPage)
		for _, folder in next, nav.Pages do
			if folder and folder.Page then
				layout(folder.Page)
			end
		end
	end

	function nav:Update()
		local inSub = #nav.Stack > 0
		nav.Bar.Frame.Visible = inSub
		local titleFrame = Canvas:FindFirstChild("TabTitle")
		if titleFrame then
			titleFrame.Visible = (tab.ShowTabTitle or false) and (not inSub)
		end
		local divider = Canvas:FindFirstChild("TabTitleDivider")
		if divider then
			divider.Visible = (tab.ShowTabTitle or false) and (not inSub)
		end
		if inSub then
			local crumbs = { { Title = tab.Title, Level = 0 } }
			for i, folder in next, nav.Stack do
				table.insert(crumbs, { Title = folder.Title, Level = i })
			end
			nav.Bar:SetCrumbs(crumbs)
		end
		nav:Layout()
	end

	function nav:Register(folder)
		table.insert(nav.Pages, folder)
		if folder and folder.Page then
			folder.Page.Visible = false
		end
		nav:Layout()
	end

	function nav:Push(folder)
		if not folder or not folder.Page then
			return
		end
		local current = nav:Current()
		if current == folder.Page then
			return
		end
		for i, f in next, nav.Stack do
			if f == folder then
				table.remove(nav.Stack, i)
				break
			end
		end
		current.Visible = false
		table.insert(nav.Stack, folder)
		folder.Page.Visible = true
		folder.Page.CanvasPosition = Vector2.new(0, 0)
		nav:Update()
	end

	function nav:Pop()
		if #nav.Stack == 0 then
			return false
		end
		local top = table.remove(nav.Stack)
		if top and top.Page then
			top.Page.Visible = false
		end
		nav:Current().Visible = true
		nav:Update()
		return true
	end

	-- 跳到指定层级（0 = 根）：面包屑点击用；点当前层无操作
	function nav:PopTo(level)
		level = math.max(0, level or 0)
		if level >= #nav.Stack then
			return false
		end
		while #nav.Stack > level do
			local top = table.remove(nav.Stack)
			if top and top.Page then
				top.Page.Visible = false
			end
		end
		nav:Current().Visible = true
		nav:Update()
		return true
	end

	function nav:PopToRoot()
		if #nav.Stack == 0 then
			return
		end
		nav:PopTo(0)
	end

	-- 当前可见页面：栈空即根页面
	function nav:Current()
		if #nav.Stack == 0 then
			return nav.RootPage
		end
		return nav.Stack[#nav.Stack].Page
	end

	-- 从导航中摘除文件夹（行销毁时调用，第 3 步由 Folder 接线）
	function nav:Remove(folder)
		for i, f in next, nav.Pages do
			if f == folder then
				table.remove(nav.Pages, i)
				break
			end
		end
		for i, f in next, nav.Stack do
			if f == folder then
				table.remove(nav.Stack, i)
				break
			end
		end
		nav:Update()
	end

	nav:Layout()

	return nav
end

return Navigator
