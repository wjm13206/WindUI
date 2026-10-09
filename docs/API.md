# WindUI 文件夹导航 API

侧边栏只显示最顶层 Tab；右侧主界面里文件夹与文件混排，双击文件夹进入下一级，
二级及以上顶部出现安卓式返回栏 + 可点面包屑。行为对标真实文件系统。

```
Window
└── Tab（侧边栏顶层，唯一可进栈的根页面）
    ├── Button / Slider / …（文件行，直接点击）
    └── Folder（文件夹行，双击进入）
        ├── Button / Slider / …（文件行）
        └── Folder（子文件夹，可继续下钻）
```

核心只有两个可进栈的页面：**Tab（根）**与 **Folder（子目录）**，其余元素一律 inline 排列。

---

## 1. Folder 元素

### 创建

```lua
local moveFolder = Tab:Folder({
    Title = "移动",          -- 文件夹名，缺省 "新建文件夹"
    Desc = "速度 / 飞行",    -- 悬停提示，可选
    Icon = "folder",         -- 左侧图标，缺省 "folder"
    IconThemed = true,       -- 图标是否跟主题，可选
    Color = Color3.fromRGB(255, 170, 0), -- 行主题色，可选
    Locked = false,          -- 锁定后不可进入，可选
    LockedTitle = "未解锁",  -- 锁定提示标题，可选
})
```

子内容直接往返回值上挂，与 Tab 用法一致，文件与子文件夹可混排：

```lua
moveFolder:Slider({ Title = "速度", Min = 16, Max = 500, Default = 16 })
moveFolder:Toggle({ Title = "穿墙", Default = false })

local advFolder = moveFolder:Folder({ Title = "高级走位" })
advFolder:Button({ Title = "瞬移", Callback = function() end })
```

### 交互规则

| 操作 | 行为 |
|---|---|
| PC 双击（0.35 秒内两次单击） | 进入子页面 |
| PC 单击 | 仅高亮选中行，不进入 |
| 触屏单击（无键盘设备） | 直接进入子页面 |
| 返回栏"返回"按钮 / 面包屑 | 逐级返回 / 跳到任意层级（0 = 根）|
| 文件夹行为空 | 子页面显示"此文件夹为空" |

### 方法

| 方法 | 说明 |
|---|---|
| `folder:Open()` | 进入该文件夹（等价双击；锁定或已锁定行时无操作） |
| `folder:Close()` | 仅当自己是栈顶时返回上一级，否则无操作 |
| `folder:Lock(title?)` | 锁定：不可进入。`title` 缺省用创建时的 `LockedTitle` |
| `folder:Unlock()` | 解锁 |
| `folder:SetTitle(text)` | 改名；若正处导航栈内，面包屑同步更新 |
| `folder:GetPath()` | 返回完整路径，如 `"演示 / 移动 / 高级走位"` |
| `folder:RefreshCount()` | 刷新右侧" N 项"；增删子元素一般自动触发，手动调用兜底 |
| `folder:Destroy()` | 销毁行 + 连带回收子页面 + 从导航栈摘除，可重复调用（幂等） |

### 属性

| 属性 | 说明 |
|---|---|
| `folder.Elements` | 直接子元素数组（保序，`#folder.Elements` 即"N 项"） |
| `folder.Page` | 子页面实例；销毁后为 `nil` |
| `folder.Depth` | 嵌套深度（根 Tab 下为 1，逐级 +1） |
| `folder.ParentFolder` | 上级文件夹；根 Tab 下为 `nil` |
| `folder.RootTab` | 所属根 Tab |
| `folder.Locked` | 是否锁定中 |
| `folder.__type` | `"Folder"` |

---

## 2. Tab.Navigator（导航器）

每个 Tab 持有一个独立导航器，页面栈互不串扰。对外入口一律走它：

```lua
local nav = Tab.Navigator
nav:PopToRoot()   -- 回到根页面
nav:Current()     -- 当前可见页面
```

| 方法 | 说明 |
|---|---|
| `nav:Push(folder)` | 进入文件夹。重复进入同一页 / 缺页时直接返回；进入后滚动位置归零 |
| `nav:Pop()` | 返回上一级。已在根时返回 `false`，否则 `true` |
| `nav:PopTo(level)` | 跳到指定层级，`0` = 根。点当前层无操作（返回 `false`） |
| `nav:PopToRoot()` | 一键回到根页面 |
| `nav:Current()` | 当前可见页面：栈空返回根页面，否则返回栈顶文件夹的子页面 |
| `nav:Register(folder)` | 登记文件夹页面（Folder 创建时自动调用，一般不用手动调） |
| `nav:Remove(folder)` | 从登记表与栈中摘除（Folder 销毁时自动调用） |
| `nav:Update()` | 刷新返回栏显隐 + 面包屑 + 重排页面（改名/增删后一般自动触发） |
| `nav:Layout()` | 按"是否在子目录"重排所有页面尺寸（子目录时隐藏 Tab 大标题、留出返回栏高度） |

| 属性 | 说明 |
|---|---|
| `nav.Stack` | 文件夹栈数组，`#nav.Stack == 0` 即在根页面 |
| `nav.Pages` | 已登记的全部文件夹页面 |
| `nav.RootPage` | 根页面（Tab 的内容滚动区） |
| `nav.BarHeight` | 返回栏高度，取自 `Tab.NavBarHeight`（默认 40） |
| `nav.Bar` | 导航栏对象（见下节），`nav.Bar.Frame` 为其实例 |
| `nav.Tab` | 所属 Tab |

### 返回栏与面包屑行为

- 只在二级及以上（`#Stack > 0`）显示；在子目录时 Tab 大标题自动隐藏，给返回栏让位。
- 面包屑每段都可点，点击直达对应层级（含第 0 段根标题）。
- 超过 4 段时前面折叠为 `…`，只保留末尾 4 段；单段超宽截断（180px）保证栏内不溢出。

---

## 3. 底层模块（二次开发用）

### Page（`src/components/window/Page.lua`）

内容页面工厂，Tab 根页面与 Folder 子页面是同一种 `ScrollingFrame`，
内边距 / 列表布局 / 滚动行为全局一致，改样式只改这一处。

```lua
local Page = require("...components.window.Page")
local page = Page.New({
    Window = Window,   -- 必填（取 HidePanelBackground 决定内边距 10 / 20）
    Gap = Tab.Gap,     -- 必填，元素间距
    Size = nil,        -- 可选，初始尺寸；创建后由 Navigator 统一重排
    Visible = false,   -- 可选，缺省 true；子页面传 false
    Parent = canvas,   -- 可选；Tab 根页面不传（由 Canvas children 挂载）
    Name = "FolderPage", -- 可选；Tab 根页面不传（保持无名）
    EmptyHint = "此文件夹为空", -- 可选；传 nil 则不创建空提示节点
})
```

### NavBar（`src/components/window/NavBar.lua`）

返回栏 + 面包屑 UI，Navigator 内部创建，一般不直接实例化。手动用法：

```lua
local NavBar = require("...components.window.NavBar")
local bar = NavBar.New({
    Window = Window,       -- 必填
    Height = 40,           -- 必填
    Parent = canvas,       -- 可选
    OnBack = function() end,          -- 可选，返回按钮回调
    OnJump = function(level) end,     -- 可选，面包屑回调，0 = 根
})
bar:SetCrumbs({ { Title = "演示", Level = 0 }, { Title = "移动", Level = 1 } })
-- bar.Frame：栏实例；bar.Box：面包屑容器
```

### Container（`src/elements/Container.lua`）

所有可挂元素容器（Tab / Folder / Section / Group / HStack / VStack）共用的注册语义：

- `host.Elements` 永远是**数组**：保序、`#` 可计数、整数键可回查（搜索跳转与滚动定位依赖它）；
  只登记**直接子元素**，嵌套内容归各自子容器所有，互不覆盖下标。
- `Window.AllElements` 按**稳定 uid** 登记全窗口元素，销毁时按 uid 置空，不移位。

```lua
local Container = require("...elements.Container")
local uid = Container.NextUid()          -- 全局稳定 uid，元素终身不变
Container.Register(host, content)        -- 追加到 host.Elements 尾部
Container.Unregister(host, content)      -- 按身份摘除，找不到返回 false
```

---

## 4. 完整示例

```lua
local Tab = Window:Tab({ Title = "玩法", Icon = "gamepad-2" })

-- 顶层文件：与文件夹同级，直接点击
Tab:Button({ Title = "一键秒杀", Callback = function() end })

-- 一级文件夹
local move = Tab:Folder({ Title = "移动", Desc = "速度 / 飞行，双击进入" })
move:Slider({ Title = "速度", Min = 16, Max = 500, Default = 16 })
move:Toggle({ Title = "穿墙", Default = false })

-- 二级文件夹（进入"移动"后可见）
local adv = move:Folder({ Title = "高级走位" })
adv:Button({ Title = "瞬移", Callback = function() end })

-- 代码控制导航
move:Open()                    -- 进入"移动"
print(move:GetPath())          -- "玩法 / 移动"
Tab.Navigator:PopToRoot()      -- 回到根页面
```

## 5. 约束说明

- **搜索只搜根页面行**：`Tab.Elements` 仅含直接挂载的行，文件夹内部不参与全局搜索。
- **`Tab:LockAll()` 只锁根页面行**：子文件夹内容不受影响；如需整棵锁定请自行递归。
- 进入子目录后根页面的大标题与分隔线自动隐藏，返回根后恢复。
