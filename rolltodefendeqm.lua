--[[
    STANDALONE EQUIP TESTER (with delay before closing)
    Press E to run the equip macro once.
    No UI overlay – only notifications.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    notify("Player not found", "Error", 3)
    return
end

-- ===== YOUR OFFSETS (from logger) =====
local OFFSETS = {
    BackpackButton = Vector2.new(1066, 1317),
    ItemSlot       = Vector2.new(467, 767),
    UseButton      = Vector2.new(1693, 1068),
    InventoryTab   = Vector2.new(445, 652),
    EquipBestButton= Vector2.new(1807, 1118),
}
-- ====================================

local function runEquipMacro()
    local bp = OFFSETS.BackpackButton
    local inv = OFFSETS.InventoryTab
    local eq = OFFSETS.EquipBestButton

    if bp.X == 0 and bp.Y == 0 then
        notify("Offsets not set! Edit the script.", "Error", 3)
        return
    end

    notify("Equip macro running...", "Equip Tester", 2)

    -- 1. Open backpack (single click)
    mousemoveabs(bp.X, bp.Y)
    mouse1click()
    task.wait(0.4)   -- wait for backpack to open

    -- 2. Click Inventory tab (single click)
    mousemoveabs(inv.X, inv.Y)
    mouse1click()
    task.wait(0.3)

    -- 3. Click Equip Best (single click)
    mousemoveabs(eq.X, eq.Y)
    mouse1click()
    task.wait(0.8)   -- longer delay to let the equip action register

    -- 4. Close backpack (single click) – now with a longer pause to ensure it's still open
    mousemoveabs(bp.X, bp.Y)
    mouse1click()

    notify("Equip macro completed", "Equip Tester", 2)
end

-- Press E to trigger
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        task.spawn(runEquipMacro)
    end
end)

notify("Press E to run the equip macro", "Equip Tester", 3)
