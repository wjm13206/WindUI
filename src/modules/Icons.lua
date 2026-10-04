local cloneref = (cloneref or clonereference or function(instance) return instance end)

local IconModule = cloneref(game:GetService("ReplicatedStorage"):WaitForChild("GetIcons", 99999):InvokeServer())

local function parseIconString(iconString)  
    if type(iconString) == "string" then  
        -- plain 查找：图标名不含模式字符，走模式引擎是纯浪费
        local splitIndex = iconString:find(":", 1, true)  
        if splitIndex then  
            local iconType = iconString:sub(1, splitIndex - 1)  
            local iconName = iconString:sub(splitIndex + 1)  
            return iconType, iconName  
        end  
    end  
    return nil, iconString  
end

-- 解析结果缓存：同一图标（如 "expand"/"x"/"lock"）在创建窗口时被解析几十次，
-- 图标集静态不变，首次解析后直接复用，避免重复 find/sub/表查找与结果表分配
local IconResolveCache = {}  

function IconModule.AddIcons(packName, iconsData)
    if type(packName) ~= "string" or type(iconsData) ~= "table" then
        error("AddIcons: packName must be string, iconsData must be table")
        return
    end
    
    if not IconModule.Icons[packName] then
        IconModule.Icons[packName] = {
            Icons = {},
            Spritesheets = {}
        }
    end
    
    -- AddIcons 会改变解析结果，先清空缓存避免命中旧值
    table.clear(IconResolveCache)
    for iconName, iconValue in pairs(iconsData) do
        if type(iconValue) == "number" or (type(iconValue) == "string" and iconValue:match("^rbxassetid://")) then
            local imageId = iconValue
            if type(iconValue) == "number" then
                imageId = "rbxassetid://" .. tostring(iconValue)
            end
            
            IconModule.Icons[packName].Icons[iconName] = {
                Image = imageId,
                ImageRectSize = Vector2.new(0, 0),
                ImageRectPosition = Vector2.new(0, 0),
                Parts = nil
            }
            IconModule.Icons[packName].Spritesheets[imageId] = imageId
            
        elseif type(iconValue) == "table" then
            if iconValue.Image and iconValue.ImageRectSize and iconValue.ImageRectPosition then
                local imageId = iconValue.Image
                if type(imageId) == "number" then
                    imageId = "rbxassetid://" .. tostring(imageId)
                end
                
                IconModule.Icons[packName].Icons[iconName] = {
                    Image = imageId,
                    ImageRectSize = iconValue.ImageRectSize,
                    ImageRectPosition = iconValue.ImageRectPosition,
                    Parts = iconValue.Parts
                }
                
                if not IconModule.Icons[packName].Spritesheets[imageId] then
                    IconModule.Icons[packName].Spritesheets[imageId] = imageId
                end
            else
                warn("AddIcons: Invalid spritesheet data format for icon '" .. iconName .. "'")
            end
        else
            warn("AddIcons: Unsupported data type for icon '" .. iconName .. "': " .. type(iconValue))
        end
    end
end
  
function IconModule.SetIconsType(iconType)  
    IconModule.IconsType = iconType  
end  
  
local New 
function IconModule.Init(_New, IconThemeTag)  
    IconModule.New = _New  
    IconModule.IconThemeTag = IconThemeTag  
      
    New = _New
    return IconModule  
end  

function IconModule.Icon(Icon, Type, DefaultFormat)
    DefaultFormat = DefaultFormat ~= false
    -- 结果缓存命中则直接返回：调用方只读 [1]/[2]，复用同一张表安全
    local cacheKey = typeof(Icon) == "string" and (Icon .. "\0" .. tostring(Type) .. "\0" .. (DefaultFormat and "1" or "0")) or nil
    if cacheKey ~= nil then
        local hit = IconResolveCache[cacheKey]
        if hit ~= nil then
            return hit
        end
    end

    local iconType, iconName = parseIconString(Icon)  
    
    local targetType = iconType or Type or IconModule.IconsType  
    local targetName = iconName  
      
    local iconSet = IconModule.Icons[targetType]  
      
    local result
    if iconSet and iconSet.Icons and iconSet.Icons[targetName] then  
        result = {   
            iconSet.Spritesheets[tostring(iconSet.Icons[targetName].Image)],   
            iconSet.Icons[targetName],  
        }  
    elseif iconSet and iconSet[targetName] and string.find(iconSet[targetName], "rbxassetid://", 1, true) then
        result = DefaultFormat and { 
            iconSet[targetName], 
            { ImageRectSize = Vector2.new(0,0), ImageRectPosition = Vector2.new(0,0) }
        } or iconSet[targetName]
    end
    if cacheKey ~= nil and result ~= nil then
        IconResolveCache[cacheKey] = result
    end
    return result
end  

function IconModule.GetIcon(Icon, Type)  
    return IconModule.Icon(Icon, Type, false) 
end  
  

function IconModule.Icon2(Icon, Type, DefaultFormat)  
    return IconModule.Icon(Icon, Type, true)  
end  
  
function IconModule.Image(IconConfig)  
    local Icon = {  
        Icon = IconConfig.Icon or nil,  
        Type = IconConfig.Type,  
        Colors = IconConfig.Colors or { ( IconModule.IconThemeTag or Color3.new(1,1,1) ), Color3.new(1,1,1) },  
        Transparency = IconConfig.Transparency or { 0, 0 },
        Size = IconConfig.Size or UDim2.new(0,24,0,24),  
          
        IconFrame = nil,  
    }  
      
    local Colors = {}
    local Transparencies = {}

    for i, v in next, Icon.Colors do
        Colors[i] = {
            ThemeTag = typeof(v) == "string" and v,
            Color = typeof(v) == "Color3" and v,
        }
    end

    for i, v in next, Icon.Transparency do
        Transparencies[i] = {
            ThemeTag = typeof(v) == "string" and v,
            Value = typeof(v) == "number" and v,
        }
    end


    local IconLabel = IconModule.Icon2(Icon.Icon, Icon.Type)  
    local isrbxassetid = typeof(IconLabel) == "string" and string.find(IconLabel, 'rbxassetid://')
    
    if IconModule.New then  
        local New = New or IconModule.New  
          
          
          
        local IconFrame = New("ImageLabel", {  
            Size = Icon.Size,  
            BackgroundTransparency = 1,  
            ImageColor3 = Colors[1].Color or nil,  
            ImageTransparency = Transparencies[1].Value or nil,
            ThemeTag = Colors[1].ThemeTag and {  
                ImageColor3 = Colors[1].ThemeTag,
                ImageTransparency = Transparencies[1].ThemeTag,
            },  
            Image = isrbxassetid and IconLabel or IconLabel[1],  
            ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize,  
            ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition,  
        })  
      
      
        if not isrbxassetid and IconLabel[2].Parts then  
            for _, part in next, IconLabel[2].Parts do  
                local IconPartLabel = IconModule.Icon(part, Icon.Type)  
                  
                local IconPart = New("ImageLabel", {  
                    Size = UDim2.new(1,0,1,0),  
                    BackgroundTransparency = 1,  
                    ImageColor3 = Colors[1 + _].Color or nil,  
                    ImageTransparency = Transparencies[1 + _].Value or nil,
                    ThemeTag = Colors[1 + _].ThemeTag and {  
                        ImageColor3 = Colors[1 + _].ThemeTag,
                        ImageTransparency = Transparencies[1 + _].ThemeTag,
                    },  
                    Image = IconPartLabel[1],  
                    ImageRectSize = IconPartLabel[2].ImageRectSize,  
                    ImageRectOffset = IconPartLabel[2].ImageRectPosition,  
                    Parent = IconFrame,  
                })  
            end  
        end  
          
        Icon.IconFrame = IconFrame  
    else  
        local IconFrame = Instance.new("ImageLabel")  
        IconFrame.Size = Icon.Size  
        IconFrame.BackgroundTransparency = 1  
        IconFrame.ImageColor3 = Colors[1].Color  
        IconFrame.ImageTransparency = Transparencies[1].Value or nil
        IconFrame.Image = isrbxassetid and IconLabel or IconLabel[1]  
        IconFrame.ImageRectSize = isrbxassetid and nil or IconLabel[2].ImageRectSize  
        IconFrame.ImageRectOffset = isrbxassetid and nil or IconLabel[2].ImageRectPosition  
          
          
        if not isrbxassetid and IconLabel[2].Parts then  
            for _, part in next, IconLabel[2].Parts do  
                local IconPartLabel = IconModule.Icon(part, Icon.Type)  
                  
                local IconPart = Instance.New("ImageLabel")  
                IconPart.Size = UDim2.new(1,0,1,0)  
                IconPart.BackgroundTransparency = 1  
                IconPart.ImageColor3 = Colors[1 + _].Color  
                IconPart.ImageTransparency = Transparencies[1 + _].Value or nil
                IconPart.Image = IconPartLabel[1]  
                IconPart.ImageRectSize = IconPartLabel[2].ImageRectSize  
                IconPart.ImageRectOffset = IconPartLabel[2].ImageRectPosition  
                IconPart.Parent = IconFrame  
            end  
        end  
          
        Icon.IconFrame = IconFrame  
    end  
      
      
    return Icon  
end  
  
return IconModule