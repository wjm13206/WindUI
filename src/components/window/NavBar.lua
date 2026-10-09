-- 顶部导航栏：安卓式返回按钮 + 可点面包屑
-- 面包屑每段可点，点击直接跳到对应层级（0 = Tab 根）
local Creator = require("../../modules/Creator")
local New = Creator.New

local NavBar = {}

-- 超过该段数只保留末尾段，前面折叠为 …
local MAX_CRUMBS = 4
local CRUMB_MAX_WIDTH = 180

-- opts:
--   Window 必填（图标缓存用 Window.Folder）
--   Height 必填，栏高（取 Tab.NavBarHeight）
--   Parent 可选，父容器
--   OnBack 可选，返回按钮回调
--   OnJump 可选，面包屑跳转回调，参数为层级（0 = 根）
function NavBar.New(opts)
	local Window = opts.Window
	local Height = opts.Height or 40

	local BackIcon = Creator.Image(
		"chevron-left",
		"navbar:back",
		0,
		Window.Folder,
		"TabNav",
		true
	)
	BackIcon.Size = UDim2.new(0, 18, 0, 18)

	local BackLabel = New("TextLabel", {
		Text = "返回",
		TextSize = 15,
		ThemeTag = {
			TextColor3 = "Text",
		},
		FontFace = Font.new(Creator.Font, Enum.FontWeight.SemiBold),
		AutomaticSize = "XY",
		BackgroundTransparency = 1,
	})

	local BackButton = New("TextButton", {
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = "X",
		BackgroundTransparency = 1,
		Text = "",
		Name = "Back",
	}, {
		BackIcon,
		BackLabel,
		New("UIListLayout", {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 2),
		}),
	})

	local CrumbBox = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -90, 1, 0),
		ClipsDescendants = true,
		Name = "Crumbs",
	}, {
		New("UIListLayout", {
			SortOrder = "LayoutOrder",
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 2),
		}),
	})

	local Bar = New("Frame", {
		Size = UDim2.new(1, 0, 0, Height),
		BackgroundTransparency = 1,
		Visible = false,
		Name = "FolderNavBar",
		Parent = opts.Parent,
	}, {
		BackButton,
		CrumbBox,
		New("UIListLayout", {
			FillDirection = "Horizontal",
			VerticalAlignment = "Center",
			Padding = UDim.new(0, 10),
		}),
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
	})

	local self = {
		Frame = Bar,
		Box = CrumbBox,
	}

	local function AddSeparator(order)
		New("TextLabel", {
			Text = "/",
			TextSize = 13,
			TextTransparency = 0.5,
			ThemeTag = {
				TextColor3 = "Text",
			},
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			AutomaticSize = "XY",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = CrumbBox,
		})
	end

	local function AddCrumb(title, level, order, isCurrent)
		local btn = New("TextButton", {
			Text = title,
			TextSize = 14,
			TextTransparency = isCurrent and 0 or 0.35,
			TextTruncate = "AtEnd",
			ThemeTag = {
				TextColor3 = "Text",
			},
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			Size = UDim2.new(0, 0, 0, 28),
			AutomaticSize = "X",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = CrumbBox,
		}, {
			New("UISizeConstraint", {
				MaxSize = Vector2.new(CRUMB_MAX_WIDTH, math.huge),
			}),
		})
		Creator.AddSignal(btn.MouseButton1Click, function()
			if opts.OnJump then
				opts.OnJump(level)
			end
		end)
	end

	-- 重建面包屑：segments = {{ Title = "...", Level = N }}，Level 0 为根
	function self:SetCrumbs(segments)
		for _, child in next, CrumbBox:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if #segments == 0 then
			return
		end
		local show = segments
		local collapsed = false
		if #segments > MAX_CRUMBS then
			collapsed = true
			show = {}
			for i = #segments - MAX_CRUMBS + 1, #segments do
				table.insert(show, segments[i])
			end
		end
		local order = 0
		if collapsed then
			order = order + 1
			New("TextLabel", {
				Text = "…",
				TextSize = 14,
				TextTransparency = 0.5,
				ThemeTag = {
					TextColor3 = "Text",
				},
				FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
				AutomaticSize = "XY",
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Parent = CrumbBox,
			})
		end
		for i, seg in next, show do
			if i > 1 or collapsed then
				order = order + 1
				AddSeparator(order)
			end
			order = order + 1
			AddCrumb(seg.Title, seg.Level, order, i == #show)
		end
	end

	Creator.AddSignal(BackButton.MouseButton1Click, function()
		if opts.OnBack then
			opts.OnBack()
		end
	end)

	return self
end

return NavBar
