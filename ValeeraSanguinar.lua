-- ValeeraSanguinar.lua
-- Reputation bar for Valeera Sanguinar (factionID 2744).

DelveInformantDB = DelveInformantDB or {}
DelveInformantDB.ValeeraSanguinar = DelveInformantDB.ValeeraSanguinar or {}

local db = DelveInformantDB.ValeeraSanguinar

local FACTION_ID = 2744
local UPDATE_INTERVAL = 0.25

local BAR_WIDTH, BAR_HEIGHT = 250, 42
local BAR_POINT, BAR_X, BAR_Y = "CENTER", 0, -34

local BG_R, BG_G, BG_B, BG_A = 0, 0, 0, 0.35
local BAR_R, BAR_G, BAR_B, BAR_A = 0.72, 0.18, 0.62, 1
local BORDER_R, BORDER_G, BORDER_B, BORDER_A = 0.5921568627, 0.5254901961, 0.968627451, 0.76

local function Round(x)
  if x >= 0 then
    return math.floor(x + 0.5)
  end
  return math.ceil(x - 0.5)
end

local function Snap(frame, value)
  local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale())
    or (UIParent and UIParent:GetEffectiveScale())
    or 1
  return Round(value * scale) / scale
end

local function SnapPoint(frame, x, y)
  return Snap(frame, x or 0), Snap(frame, y or 0)
end

local function EnsureDBDefaults()
  if db.locked == nil then db.locked = true end
  if db.point == nil then db.point = BAR_POINT end
  if db.relativePoint == nil then db.relativePoint = BAR_POINT end
  if db.x == nil then db.x = BAR_X end
  if db.y == nil then db.y = BAR_Y end
end

local f = CreateFrame("Frame", "DelveInformantValeeraSanguinarFrame", UIParent, "BackdropTemplate")
f:SetSize(BAR_WIDTH, BAR_HEIGHT)
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:EnableMouse(false)
f:RegisterForDrag("LeftButton")

f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  edgeSize = 12,
  tileSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
f:SetBackdropColor(BG_R, BG_G, BG_B, BG_A)
f:SetBackdropBorderColor(BORDER_R, BORDER_G, BORDER_B, BORDER_A)

local bar = CreateFrame("StatusBar", nil, f)
bar:SetPoint("TOPLEFT", 4, -20)
bar:SetPoint("BOTTOMRIGHT", -4, 4)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
bar:SetStatusBarColor(BAR_R, BAR_G, BAR_B, BAR_A)

local nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2, 2)
nameText:SetJustifyH("LEFT")

local levelText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
levelText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -2, 2)
levelText:SetJustifyH("RIGHT")

local valueText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
valueText:SetJustifyH("CENTER")

local helperText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helperText:SetPoint("TOP", f, "BOTTOM", 0, -2)
helperText:SetText("/vslock /vsunlock /vsmove")
helperText:SetShown(false)

local function RestorePosition()
  EnsureDBDefaults()
  f:ClearAllPoints()
  local x, y = SnapPoint(f, db.x, db.y)
  f:SetPoint(db.point, UIParent, db.relativePoint, x, y)
end

local function SavePosition()
  local point, _, relativePoint, x, y = f:GetPoint(1)
  if point and relativePoint and x and y then
    db.point = point
    db.relativePoint = relativePoint
    db.x = x
    db.y = y
  end
end

local function SetLocked(locked)
  db.locked = locked and true or false
  f:EnableMouse(not db.locked)
  helperText:SetShown(not db.locked)
end

f:SetScript("OnDragStart", function(self)
  if not db.locked then
    self:StartMoving()
  end
end)

f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SavePosition()
end)

local function GetFactionData()
  if not C_Reputation or not C_Reputation.GetFactionDataByID then
    return nil
  end
  return C_Reputation.GetFactionDataByID(FACTION_ID)
end

local function UpdateDisplay()
  local data = GetFactionData()
  if not data then
    f:Hide()
    return
  end

  local current = data.currentStanding or 0
  local min = data.currentReactionThreshold or 0
  local max = data.nextReactionThreshold or 0

  local earned = current - min
  local needed = max - min

  local isCapped = (needed <= 0) or data.isCapped
  local percent = 100
  if isCapped then
    bar:SetValue(1)
  else
    local pct = earned / needed
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    percent = pct * 100
    bar:SetValue(pct)
  end

  valueText:SetText(string.format("%.0f%%", percent))

  local name = data.name or "Valeera Sanguinar"
  nameText:SetText(name)

  local level = data.renownLevel or data.currentStanding or 0
  levelText:SetText(string.format("%d/60", level))

  f:Show()
end

SLASH_VALEERASANGUINARLOCK1 = "/vslock"
SlashCmdList["VALEERASANGUINARLOCK"] = function()
  SetLocked(true)
end

SLASH_VALEERASANGUINARUNLOCK1 = "/vsunlock"
SlashCmdList["VALEERASANGUINARUNLOCK"] = function()
  SetLocked(false)
end

SLASH_VALEERASANGUINARMOVE1 = "/vsmove"
SlashCmdList["VALEERASANGUINARMOVE"] = function()
  SetLocked(not db.locked)
end

local evt = CreateFrame("Frame")
evt:RegisterEvent("PLAYER_ENTERING_WORLD")
evt:RegisterEvent("UPDATE_FACTION")
evt:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
evt:RegisterEvent("QUEST_TURNED_IN")
evt:SetScript("OnEvent", function()
  UpdateDisplay()
end)

local elapsed = 0
f:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed >= UPDATE_INTERVAL then
    elapsed = 0
    UpdateDisplay()
  end
end)

EnsureDBDefaults()
RestorePosition()
SetLocked(db.locked)
UpdateDisplay()
