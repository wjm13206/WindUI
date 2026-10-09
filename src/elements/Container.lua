-- 容器 mixin：所有可挂载元素的容器（Tab / Folder / Section / Group / HStack / VStack）共用注册语义
--   host.Elements 永远是数组：保序、`#` 可计数、整数键可回查（搜索 / ScrollToTheElement 依赖它）
--   Window.AllElements 按稳定 uid 注册：销毁时按 uid 置空，不再 table.remove 移位，
--   根治“存下的 Index/GlobalIndex 一经删减就错位，Destroy 删错元素”的级联腐败
local Container = {}

local UidSeq = 0

-- 分配全局稳定 uid：元素终身不变，不受任何增删移位影响，多窗口共用一段序列
function Container.NextUid()
	UidSeq = UidSeq + 1
	return UidSeq
end

-- 注册元素到宿主数组尾部，返回本次位置（即 config.Index）
function Container.Register(host, content)
	table.insert(host.Elements, content)
	return #host.Elements
end

-- 按身份摘除：线性查找，正确性优先；元素数量级小且销毁低频，O(n) 可接受
function Container.Unregister(host, content)
	if not host or not host.Elements then
		return false
	end
	for i, e in next, host.Elements do
		if e == content then
			table.remove(host.Elements, i)
			return true
		end
	end
	return false
end

return Container
