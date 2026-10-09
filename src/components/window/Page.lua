-- 内容页面工厂：Tab 根页面与 Folder 子页面共用同一种 ScrollingFrame，
-- 保证内边距 / 列表布局 / 滚动行为全局一致，样式只在这里改一处。
local Creator = require("../../modules/Creator")
local New = Creator.New

local Page = {}

-- 新建一个内容页面
-- opts:
--   Window    必填，窗口表（取 HidePanelBackground 决定内边距）
--   Gap       必填，元素间距（传 Tab.Gap）
--   Size      可选，初始尺寸；缺省 UDim2.new(1, 0, 1, 0)
--             （创建后由 Navigator 统一重排）
--   Visible   可选，缺省 true；Folder 子页面传 false
--   Parent    可选，父容器；Tab 根页面不传（由 Canvas children 挂载）
--   Name      可选，实例名；Tab 根页面不传（保持无名）
--   EmptyHint 可选，空页面提示文本；传 nil 则不创建该节点
function Page.New(opts)
	local Window = opts.Window
	local pad = (Window.HidePanelBackground and 10 or 20)

	local children = {
		New("UIPadding", {
			PaddingTop = UDim.new(0, pad),
			PaddingLeft = UDim.new(0, pad),
			PaddingRight = UDim.new(0, pad),
			PaddingBottom = UDim.new(0, pad),
		}),
		New("UIListLayout", {
			SortOrder = "LayoutOrder",
			Padding = UDim.new(0, opts.Gap),
			HorizontalAlignment = "Center",
		}),
	}

	if opts.EmptyHint then
		table.insert(children, New("TextLabel", {
			Text = opts.EmptyHint,
			TextSize = 15,
			TextTransparency = 0.6,
			ThemeTag = {
				TextColor3 = "Text",
			},
			FontFace = Font.new(Creator.Font, Enum.FontWeight.Medium),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Name = "EmptyHint",
		}))
	end

	local props = {
		Size = opts.Size or UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		ElasticBehavior = "Never",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		AutomaticCanvasSize = "Y",
		ScrollingDirection = "Y",
		Visible = opts.Visible ~= false,
	}
	if opts.Name then
		props.Name = opts.Name
	end
	if opts.Parent then
		props.Parent = opts.Parent
	end

	return New("ScrollingFrame", props, children)
end

return Page
