-- ValeeraSanguinar.lua
-- Companion progress bar for Valeera Sanguinar via friendship reputation APIs.

DelveInformantDB = DelveInformantDB or {}
DelveInformantDB.ValeeraSanguinar = DelveInformantDB.ValeeraSanguinar or {}

local db = DelveInformantDB.ValeeraSanguinar

local UPDATE_INTERVAL = 0.25

local BAR_WIDTH, BAR_HEIGHT = 250, 42
local BAR_POINT, BAR_X, BAR_Y = "CENTER", 0, -34

local BG_R, BG_G, BG_B, BG_A = 0, 0, 0, 0.35
local BAR_R, BAR_G, BAR_B, BAR_A = 0.72, 0.18, 0.62, 1
local BORDER_R, BORDER_G, BORDER_B, BORDER_A = 0.5921568627, 0.5254901961, 0.968627451, 0.76

local VALEERA_NAME = "Valeera Sanguinar"
local VALEERA_NAME_KEYWORD = "valeera"
local VALEERA_FRIENDSHIP_ID = 2744

-- =========================
-- LibSharedMedia (optional)
-- =========================
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LSM_STATUSBAR = (LSM and LSM.MediaType and LSM.MediaType.STATUSBAR) or "statusbar"
local LSM_TEXTURE_NAME = "Flat"

local function FetchStatusbarTexture()
  if LSM and LSM.Fetch then
    local tex = LSM:Fetch(LSM_STATUSBAR, LSM_TEXTURE_NAME, true)
    if tex and tex ~= "" then
      return tex
    end
  end
  return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function GetCompanionFactionID()
  if C_Delves and C_Delves.GetCompanionFactionID then
    local factionID = tonumber(C_Delves.GetCompanionFactionID())
    if factionID and factionID > 0 then
      return factionID
    end
  end
  return VALEERA_FRIENDSHIP_ID
end

local function IsValeeraFaction(factionName, factionID, targetFactionID)
  if targetFactionID and factionID and tonumber(factionID) == targetFactionID then
    return true
  end

  if type(factionName) ~= "string" then
    return false
  end

  local lowered = string.lower(factionName)
  return string.find(lowered, VALEERA_NAME_KEYWORD, 1, true) ~= nil
end

local function GetFactionCompanionInfo(targetFactionID)
  if not GetNumFactions or not GetFactionInfo then
    return nil
  end

  local numFactions = GetNumFactions()
  for i = 1, numFactions do
    local name, _, standingID, barMin, barMax, barValue, _, _, _, _, _, _, _, _, _, _, _, factionID = GetFactionInfo(i)
    if IsValeeraFaction(name, factionID, targetFactionID) then
      local minValue = tonumber(barMin) or 0
      local maxValue = tonumber(barMax) or 0
      local value = tonumber(barValue) or 0
      local totalXP = maxValue - minValue
      local currentXP = value - minValue

      if totalXP < 0 then totalXP = 0 end
      if currentXP < 0 then currentXP = 0 end
      if totalXP > 0 and currentXP > totalXP then currentXP = totalXP end

      return {
        level = tonumber(standingID) or 0,
        currentXP = currentXP,
        totalXP = totalXP,
        factionID = factionID,
      }
    end
  end

  return nil
end

local function GetFriendshipCompanionInfo(friendshipFactionID)
  if not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then
    return nil
  end

  local r = C_GossipInfo.GetFriendshipReputation(friendshipFactionID)
  if not r then
    return nil
  end

  local start = tonumber(r.reactionThreshold) or 0
  local finish = tonumber(r.nextThreshold) or tonumber(r.maxRep) or start
  local standing = tonumber(r.standing) or 0
  local cur = standing - start
  local max = finish - start

  if max < 0 then max = 0 end
  if cur < 0 then cur = 0 end
  if max > 0 and cur > max then cur = max end

  local level = tonumber(r.reaction)
  if not level then
    local reactionText = tostring(r.reaction or "")
    level = tonumber(reactionText:match("(%d+)"))
  end

  return {
    level = level or 0,
    currentXP = cur,
    totalXP = max,
    factionID = friendshipFactionID,
  }
end

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

local function FormatNumber(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  while true do
    local nextS, count = s:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
    s = nextS
    if count == 0 then
      break
    end
  end
  return s
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
bar:SetStatusBarTexture(FetchStatusbarTexture())
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

local function GetCompanionInfo()
  local companionFactionID = GetCompanionFactionID()

  local friendshipInfo = GetFriendshipCompanionInfo(companionFactionID)
    or GetFriendshipCompanionInfo(VALEERA_FRIENDSHIP_ID)
  if friendshipInfo then
    return friendshipInfo
  end

  if C_Delves and C_Delves.GetCompanionLevel and C_Delves.GetCompanionXP then
    local level = tonumber(C_Delves.GetCompanionLevel(companionFactionID))
      or tonumber(C_Delves.GetCompanionLevel())
    local currentXP, totalXP = C_Delves.GetCompanionXP(companionFactionID)
    if currentXP == nil or totalXP == nil then
      currentXP, totalXP = C_Delves.GetCompanionXP()
    end

    currentXP = tonumber(currentXP)
    totalXP = tonumber(totalXP)

    if level and currentXP and totalXP then
      return {
        level = level,
        currentXP = currentXP,
        totalXP = totalXP,
        factionID = companionFactionID,
      }
    end
  end

  return GetFactionCompanionInfo(companionFactionID)
    or GetFactionCompanionInfo(VALEERA_FRIENDSHIP_ID)
end

local function UpdateDisplay()
  local companionInfo = GetCompanionInfo()
  if not companionInfo then
    f:Hide()
    return
  end

  local level = companionInfo.level
  local earned = companionInfo.currentXP
  local needed = companionInfo.totalXP
  local isCapped = needed <= 0
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

  nameText:SetText(VALEERA_NAME)
  levelText:SetText(string.format("Level %d", level))

  if isCapped then
    valueText:SetText("Max")
  else
    valueText:SetText(string.format("%s/%s (%.0f%%)", FormatNumber(earned), FormatNumber(needed), percent))
  end

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
evt:RegisterEvent("QUEST_TURNED_IN")
evt:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
evt:RegisterEvent("UPDATE_FACTION")
evt:RegisterEvent("PLAYER_LEVEL_UP")
evt:RegisterEvent("ZONE_CHANGED_NEW_AREA")
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
