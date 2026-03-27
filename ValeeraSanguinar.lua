-- ValeeraSanguinar.lua
-- Companion progress bar for Valeera Sanguinar via friendship reputation APIs.

DelveInformantDB = DelveInformantDB or {}
DelveInformantDB.ValeeraSanguinar = DelveInformantDB.ValeeraSanguinar or {}

local db = DelveInformantDB.ValeeraSanguinar
local Crayon = LibStub("LibCrayon-3.0")
local DIUtils = _G.DelveInformantUtils or {}

local UPDATE_INTERVAL = 0.25
local FADE_IN_SECONDS = 1.0
local FADE_OUT_SECONDS = FADE_IN_SECONDS

local BAR_WIDTH, BAR_HEIGHT = 250, 25
local BAR_POINT, BAR_X, BAR_Y = "CENTER", 0, -34

local BG_R, BG_G, BG_B, BG_A = 0, 0, 0, 0.35
local BORDER_R, BORDER_G, BORDER_B, BORDER_A = 0.65, 0.05, 0.05, 0.9

local VALEERA_NAME = "Valeera Sanguinar"
local VALEERA_NAME_KEYWORD = "valeera"
local VALEERA_FRIENDSHIP_ID = 2744
local VALEERA_CLASS_FILE = "ROGUE"

-- =========================
-- LibSharedMedia (optional)
-- =========================
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LSM_STATUSBAR = (LSM and LSM.MediaType and LSM.MediaType.STATUSBAR) or "statusbar"
local LSM_TEXTURE_NAME = "Flat"

local FetchStatusbarTexture = DIUtils.FetchStatusbarTexture or function()
  if LSM and LSM.Fetch then
    local tex = LSM:Fetch(LSM_STATUSBAR, LSM_TEXTURE_NAME, true)
    if tex and tex ~= "" then
      return tex
    end
  end
  return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function ApplyStatusbarTexture(statusbar)
  if statusbar and statusbar.SetStatusBarTexture then
    statusbar:SetStatusBarTexture(FetchStatusbarTexture())
  end
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

local function GetCurrentSeasonMaxLevel()
  if _G.GetCurrentSeasonMaxLevel then
    return _G.GetCurrentSeasonMaxLevel("Lvl")
  end
  return 0
end

local function IsPlayerInCombat()
  return UnitAffectingCombat and UnitAffectingCombat("player")
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

local Snap = DIUtils.Snap or function(frame, value)
  local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale())
    or (UIParent and UIParent:GetEffectiveScale())
    or 1
  local rounded = (value or 0) * scale
  if rounded >= 0 then
    rounded = math.floor(rounded + 0.5)
  else
    rounded = math.ceil(rounded - 0.5)
  end
  return rounded / scale
end

local SnapPoint = DIUtils.SnapPoint or function(frame, x, y)
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

local function GetValeeraClassColor()
  local classColorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local classColor = classColorTable and classColorTable[VALEERA_CLASS_FILE]
  if classColor then
    return classColor.r, classColor.g, classColor.b
  end
  return BORDER_R, BORDER_G, BORDER_B
end

local function EnsureDBDefaults()
  if db.locked == nil then db.locked = true end
  if db.point == nil then db.point = BAR_POINT end
  if db.relativePoint == nil then db.relativePoint = BAR_POINT end
  if db.x == nil then db.x = BAR_X end
  if db.y == nil then db.y = BAR_Y end
end

local f = CreateFrame("Frame", "DelveInformantValeeraSanguinarFrame", UIParent)
f:SetSize(BAR_WIDTH, BAR_HEIGHT)
f:SetFrameStrata("MEDIUM")
f:SetAlpha(0)
f:Hide()
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")

local fadeActive, fadeElapsed, fadeDuration = false, 0, 0
local fadeFrom, fadeTo = 0, 0
local fadeHideOnDone = false

local Clamp = DIUtils.Clamp or function(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function StartFadeTo(targetAlpha, duration, hideOnDone)
  targetAlpha = Clamp(targetAlpha or 0, 0, 1)
  duration = tonumber(duration) or 0
  hideOnDone = not not hideOnDone

  if fadeActive and fadeTo == targetAlpha and fadeHideOnDone == hideOnDone then
    return
  end

  local currentAlpha = Clamp(f:GetAlpha() or 0, 0, 1)
  if not fadeActive and math.abs(currentAlpha - targetAlpha) < 0.0001 and not hideOnDone then
    return
  end

  if not f:IsShown() then
    f:Show()
  end

  fadeActive = true
  fadeElapsed = 0
  fadeDuration = math.max(0, duration)
  fadeFrom = currentAlpha
  fadeTo = targetAlpha
  fadeHideOnDone = hideOnDone

  if fadeDuration == 0 then
    f:SetAlpha(fadeTo)
    fadeActive = false
    if fadeHideOnDone and fadeTo <= 0 then
      f:Hide()
    end
  end
end

local function ShowFrameWithFadeIfNeeded()
  if (fadeActive and fadeTo == 1 and not fadeHideOnDone) or ((f:GetAlpha() or 0) >= 0.999 and f:IsShown() and not fadeActive) then
    return
  end
  StartFadeTo(1, FADE_IN_SECONDS, false)
end

local function HideFrameWithFade()
  if not f:IsShown() and (f:GetAlpha() or 0) <= 0 then
    f:SetAlpha(0)
    f:Hide()
    fadeActive = false
    return
  end

  if fadeActive and fadeTo == 0 and fadeHideOnDone then
    return
  end

  StartFadeTo(0, FADE_OUT_SECONDS, true)
end

local BORDER_SIZE = 8
local INSET_SIZE = 4
local border = _G.CreateSegmentedBorder and _G.CreateSegmentedBorder(f, {
  borderSize = BORDER_SIZE,
  alpha = BORDER_A,
  frameLevelOffset = 3,
})

local function ApplyBorderColor()
  local r, g, b = GetValeeraClassColor()
  if border and border.SetColor then
    border.SetColor(r, g, b)
  end
end

ApplyBorderColor()

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetPoint("TOPLEFT", f, "TOPLEFT", INSET_SIZE, -INSET_SIZE)
bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -INSET_SIZE, INSET_SIZE - 1)
bg:SetColorTexture(BG_R, BG_G, BG_B, BG_A)

local bar = CreateFrame("StatusBar", nil, f)
bar:SetFrameLevel(f:GetFrameLevel() + 1)
bar:SetPoint("TOPLEFT", INSET_SIZE, -INSET_SIZE)
bar:SetPoint("BOTTOMRIGHT", -INSET_SIZE, INSET_SIZE - 1)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
ApplyStatusbarTexture(bar)
bar:SetStatusBarColor(0.35, 0, 0, 1)

local textLayer = CreateFrame("Frame", nil, f)
textLayer:SetAllPoints(true)
textLayer:SetFrameLevel(f:GetFrameLevel() + 10)
textLayer:EnableMouse(false)

if LSM and LSM.RegisterCallback then
  LSM.RegisterCallback(bar, "LibSharedMedia_Registered", function()
    ApplyStatusbarTexture(bar)
  end)
end

local nameText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
nameText:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 2, 2)
nameText:SetJustifyH("LEFT")
do
  local r, g, b = GetValeeraClassColor()
  nameText:SetTextColor(r, g, b, 1)
end

local levelText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
levelText:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -2, 2)
levelText:SetJustifyH("RIGHT")
do
  local r, g, b = GetValeeraClassColor()
  levelText:SetTextColor(r, g, b, 1)
end

local valueText = textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
valueText:SetJustifyH("CENTER")

local helperText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helperText:SetPoint("TOP", f, "BOTTOM", 0, -2)
helperText:SetText("/vslock /vsunlock /vsmove")
helperText:SetShown(false)

local isHovered = false
local lastEarned = 0
local lastNeeded = 0
local lastIsCapped = false

local function UpdateValueText()
  if lastIsCapped then
    valueText:SetText("100%")
    return
  end

  if isHovered then
    valueText:SetText(string.format("%s/%s", FormatNumber(lastEarned), FormatNumber(lastNeeded)))
  else
    local pct = 0
    if lastNeeded > 0 then
      pct = (lastEarned / lastNeeded) * 100
    end
    valueText:SetText(string.format("%.0f%%", pct))
  end
end

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

  -- Preferred source order:
  -- 1) Friendship APIs (most accurate while gossip/friendship data is available)
  -- 2) Delves APIs (direct companion level/xp when exposed)
  -- 3) Faction list scan fallback (legacy-safe path)
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
  if IsPlayerInCombat() then
    HideFrameWithFade()
    return
  end

  local delveGroup = _G.GetCurrentDelveGroup and _G.GetCurrentDelveGroup()
  if delveGroup ~= "midnight" then
    HideFrameWithFade()
    return
  end

  local companionInfo = GetCompanionInfo()
  if not companionInfo then
    HideFrameWithFade()
    return
  end

  local level = tonumber(companionInfo.level)
  local earned = companionInfo.currentXP
  local needed = companionInfo.totalXP
  local isCapped = needed <= 0
  local pct = 1

  if isCapped then
    bar:SetValue(1)
  else
    pct = earned / needed
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    bar:SetValue(pct)
  end

  local minRed = 0.35
  bar:SetStatusBarColor(minRed + ((1 - minRed) * pct), 0, 0, 1)

  lastEarned = earned
  lastNeeded = needed
  lastIsCapped = isCapped

  local currentMaxLevel = tonumber(GetCurrentSeasonMaxLevel())
  local HEX_LEVELVALUE = Crayon:GetThresholdHexColor(level, currentMaxLevel)

  nameText:SetText(VALEERA_NAME)
  levelText:SetText(string.format("Level %s/%s", Crayon:Colorize(HEX_LEVELVALUE, level), Crayon:Green(currentMaxLevel)))
  UpdateValueText()

  ShowFrameWithFadeIfNeeded()
end

f:SetScript("OnEnter", function()
  isHovered = true
  UpdateValueText()
end)

f:SetScript("OnLeave", function()
  isHovered = false
  UpdateValueText()
end)

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
evt:RegisterEvent("PLAYER_REGEN_DISABLED")
evt:RegisterEvent("PLAYER_REGEN_ENABLED")
evt:SetScript("OnEvent", function()
  UpdateDisplay()
end)

local elapsed = 0
f:SetScript("OnUpdate", function(_, dt)
  if fadeActive then
    fadeElapsed = fadeElapsed + dt
    if fadeDuration <= 0 then
      f:SetAlpha(fadeTo)
      fadeActive = false
      if fadeHideOnDone and fadeTo <= 0 then
        f:Hide()
      end
    else
      local t = fadeElapsed / fadeDuration
      if t > 1 then t = 1 end
      f:SetAlpha(Clamp(fadeFrom + (fadeTo - fadeFrom) * t, 0, 1))
      if t >= 1 then
        fadeActive = false
        if fadeHideOnDone and fadeTo <= 0 then
          f:Hide()
        end
      end
    end
  end

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
