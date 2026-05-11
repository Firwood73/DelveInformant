-- FriendshipUtils.lua
-- Utility slash command for printing friendship reputation progress from gossip context.

local function ExtractLevelFromReaction(reaction)
  if type(reaction) ~= "string" then
    return nil
  end

  local level = reaction:match("(%d+)")
  return tonumber(level)
end

local function PrintFriendshipBar(friendshipFactionID)
  local r = C_GossipInfo.GetFriendshipReputation(friendshipFactionID)
  if not r then
    print("Friendship rep nil (must be in an active Gossip NPC context, or not a friendship faction):", friendshipFactionID)
    return
  end

  local start = r.reactionThreshold or 0
  local finish = r.nextThreshold or r.maxRep or start
  local cur = (r.standing or 0) - start
  local max = finish - start
  if max < 0 then max = 0 end
  if cur < 0 then cur = 0 end
  if max > 0 and cur > max then cur = max end

  local reaction = r.reaction or "Friendship"
  local level = ExtractLevelFromReaction(reaction)

  if level then
    print(string.format("Level %d (%d / %d)", level, cur, max))
  else
    print(reaction, string.format("(%d / %d)", cur, max))
  end
end

-- Membership sets used only for fast instance lookups.
local TWW_DELVE_INSTANCE_IDS = {
  [2664] = true,
  [2679] = true,
  [2680] = true,
  [2681] = true,
  [2682] = true,
  [2683] = true,
  [2684] = true,
  [2685] = true,
  [2686] = true,
  [2687] = true,
  [2688] = true,
  [2689] = true,
  [2690] = true,
}

local MIDNIGHT_DELVE_INSTANCE_IDS = {
  [2933] = true,
  [2952] = true,
  [2953] = true,
  [2961] = true,
  [2962] = true,
  [2963] = true,
  [2964] = true,
  [2965] = true,
  [2966] = true,
  [2979] = true,
  [3003] = true,
}

local function GetCurrentDelveGroup()
  local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
  if instanceType ~= "scenario" then
    return nil
  end

  if TWW_DELVE_INSTANCE_IDS[instanceID] then
    return "tww"
  end

  if MIDNIGHT_DELVE_INSTANCE_IDS[instanceID] then
    return "midnight"
  end

  return nil
end

local SEASON_MAXLEVEL = {
  [1] = { Lvl = 60, Title = "Nullaeus Allies" },
  [2] = { Lvl = 80, Title = "Nullaeus Allies" },
  [3] = { Lvl = 100, Title = "Nullaeus Allies" },
}

local function GetCurrentSeasonMaxLevel(parse)
  local currentSeason
  if C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber then
    currentSeason = tonumber(C_DelvesUI.GetCurrentDelvesSeasonNumber())
  end

  local seasonData = SEASON_MAXLEVEL[currentSeason] or SEASON_MAXLEVEL[1]
  if parse == "Lvl" then
    return seasonData.Lvl
  else
    return seasonData.Title
  end
end

_G.PrintFriendshipBar = PrintFriendshipBar
_G.GetCurrentDelveGroup = GetCurrentDelveGroup
_G.GetCurrentSeasonMaxLevel = GetCurrentSeasonMaxLevel

-- Shared utility helpers for DelveInformant modules.
-- Keeping these in one place avoids duplicated helper logic in each feature file.
local DelveInformantUtils = _G.DelveInformantUtils or {}

function DelveInformantUtils.Clamp(value, minValue, maxValue)
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

function DelveInformantUtils.Round(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return math.ceil(value - 0.5)
end

function DelveInformantUtils.Snap(frame, value)
  local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale())
    or (UIParent and UIParent:GetEffectiveScale())
    or 1
  return DelveInformantUtils.Round((value or 0) * scale) / scale
end

function DelveInformantUtils.SnapPoint(frame, x, y)
  return DelveInformantUtils.Snap(frame, x or 0), DelveInformantUtils.Snap(frame, y or 0)
end

function DelveInformantUtils.FetchStatusbarTexture(mediaName)
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  local statusbarMediaType = (lsm and lsm.MediaType and lsm.MediaType.STATUSBAR) or "statusbar"
  local textureName = mediaName or "Flat"

  if lsm and lsm.Fetch then
    local texture = lsm:Fetch(statusbarMediaType, textureName, true)
    if texture and texture ~= "" then
      return texture
    end
  end

  return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

_G.DelveInformantUtils = DelveInformantUtils

local function CreateSegmentedBorder(parentFrame, options)
  if not parentFrame then
    return nil
  end

  options = options or {}

  local borderSize = tonumber(options.borderSize) or 8
  local borderAlpha = tonumber(options.alpha) or 1
  local texturePath = options.texturePath or "Interface\\AddOns\\ChatChange\\Textures\\"
  local frameLevelOffset = tonumber(options.frameLevelOffset) or 3
  local drawLayer = options.drawLayer or "BORDER"

  local borderFrame = CreateFrame("Frame", nil, parentFrame)
  borderFrame:SetAllPoints(parentFrame)
  borderFrame:SetFrameLevel(parentFrame:GetFrameLevel() + frameLevelOffset)
  borderFrame:EnableMouse(false)

  local borderPieces = {
    TL = borderFrame:CreateTexture(nil, drawLayer),
    T = borderFrame:CreateTexture(nil, drawLayer),
    TR = borderFrame:CreateTexture(nil, drawLayer),
    R = borderFrame:CreateTexture(nil, drawLayer),
    BR = borderFrame:CreateTexture(nil, drawLayer),
    B = borderFrame:CreateTexture(nil, drawLayer),
    BL = borderFrame:CreateTexture(nil, drawLayer),
    L = borderFrame:CreateTexture(nil, drawLayer),
  }

  borderPieces.TL:SetTexture(texturePath .. "TL.PNG")
  borderPieces.TL:SetSize(borderSize, borderSize)
  borderPieces.TL:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)

  borderPieces.TR:SetTexture(texturePath .. "TR.PNG")
  borderPieces.TR:SetSize(borderSize, borderSize)
  borderPieces.TR:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)

  borderPieces.BR:SetTexture(texturePath .. "BR.PNG")
  borderPieces.BR:SetSize(borderSize, borderSize)
  borderPieces.BR:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)

  borderPieces.BL:SetTexture(texturePath .. "BL.PNG")
  borderPieces.BL:SetSize(borderSize, borderSize)
  borderPieces.BL:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)

  borderPieces.T:SetTexture(texturePath .. "T.PNG")
  borderPieces.T:SetPoint("TOPLEFT", borderPieces.TL, "TOPRIGHT", 0, 0)
  borderPieces.T:SetPoint("TOPRIGHT", borderPieces.TR, "TOPLEFT", 0, 0)
  borderPieces.T:SetHeight(borderSize)

  borderPieces.R:SetTexture(texturePath .. "R.PNG")
  borderPieces.R:SetPoint("TOPRIGHT", borderPieces.TR, "BOTTOMRIGHT", 0, 0)
  borderPieces.R:SetPoint("BOTTOMRIGHT", borderPieces.BR, "TOPRIGHT", 0, 0)
  borderPieces.R:SetWidth(borderSize)

  borderPieces.B:SetTexture(texturePath .. "B.PNG")
  borderPieces.B:SetPoint("BOTTOMLEFT", borderPieces.BL, "BOTTOMRIGHT", 0, 0)
  borderPieces.B:SetPoint("BOTTOMRIGHT", borderPieces.BR, "BOTTOMLEFT", 0, 0)
  borderPieces.B:SetHeight(borderSize)

  borderPieces.L:SetTexture(texturePath .. "L.PNG")
  borderPieces.L:SetPoint("TOPLEFT", borderPieces.TL, "BOTTOMLEFT", 0, 0)
  borderPieces.L:SetPoint("BOTTOMLEFT", borderPieces.BL, "TOPLEFT", 0, 0)
  borderPieces.L:SetWidth(borderSize)

  local function SetColor(r, g, b, a)
    local alpha = a
    if alpha == nil then
      alpha = borderAlpha
    end

    for _, piece in pairs(borderPieces) do
      piece:SetVertexColor(r or 1, g or 1, b or 1, alpha)
    end
  end

  return {
    frame = borderFrame,
    pieces = borderPieces,
    SetColor = SetColor,
  }
end

_G.CreateSegmentedBorder = CreateSegmentedBorder

-- Shared vertical stack layout for DelveInformant bars.
-- The strongbox is the anchor row; ally bars occupy the next rows below it.
local DelveInformantLayout = _G.DelveInformantLayout or {}

DelveInformantLayout.rowGap = DelveInformantLayout.rowGap or 18
DelveInformantLayout.shiftSeconds = DelveInformantLayout.shiftSeconds or 0.25
DelveInformantLayout.entries = DelveInformantLayout.entries or {}
DelveInformantLayout.base = DelveInformantLayout.base or {
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
}

local function LayoutClamp01(value)
  if value < 0 then return 0 end
  if value > 1 then return 1 end
  return value
end

local function LayoutSnap(frame, value)
  if DelveInformantUtils and DelveInformantUtils.Snap then
    return DelveInformantUtils.Snap(frame, value)
  end
  return value or 0
end

function DelveInformantLayout.Register(key, frame, order, options)
  if not key or not frame then
    return nil
  end

  options = options or {}
  local entry = DelveInformantLayout.entries[key] or {}
  entry.key = key
  entry.frame = frame
  entry.order = tonumber(order) or 100
  entry.rowHeight = tonumber(options.rowHeight) or (frame.GetHeight and frame:GetHeight()) or 25
  entry.rowGap = tonumber(options.rowGap) or DelveInformantLayout.rowGap
  entry.currentOffsetY = entry.currentOffsetY or 0
  entry.targetOffsetY = entry.targetOffsetY or entry.currentOffsetY
  entry.animFromOffsetY = entry.currentOffsetY
  entry.animElapsed = 0
  entry.animDuration = 0
  entry.animating = false
  entry.active = entry.active or false
  DelveInformantLayout.entries[key] = entry
  DelveInformantLayout.Apply()
  return entry
end

function DelveInformantLayout.SetBaseFromFrame(frame)
  if not frame or not frame.GetPoint then
    return
  end

  local point, _, relativePoint, x, y = frame:GetPoint(1)
  if not point then
    return
  end

  DelveInformantLayout.base.point = point
  DelveInformantLayout.base.relativePoint = relativePoint or point
  DelveInformantLayout.base.x = LayoutSnap(frame, x or 0)
  DelveInformantLayout.base.y = LayoutSnap(frame, y or 0)
  DelveInformantLayout.Apply(true)
end

function DelveInformantLayout.SetBase(point, relativePoint, x, y)
  DelveInformantLayout.base.point = point or DelveInformantLayout.base.point or "CENTER"
  DelveInformantLayout.base.relativePoint = relativePoint or DelveInformantLayout.base.relativePoint or DelveInformantLayout.base.point
  DelveInformantLayout.base.x = tonumber(x) or 0
  DelveInformantLayout.base.y = tonumber(y) or 0
  DelveInformantLayout.Apply(true)
end

function DelveInformantLayout.SetActive(key, active)
  local entry = DelveInformantLayout.entries[key]
  if not entry then
    return
  end

  active = not not active
  if entry.active == active then
    return
  end

  entry.active = active
  DelveInformantLayout.UpdateTargets(false)
end

local function GetActiveEntriesSorted()
  local activeEntries = {}
  for _, entry in pairs(DelveInformantLayout.entries) do
    if entry.active then
      activeEntries[#activeEntries + 1] = entry
    end
  end

  table.sort(activeEntries, function(a, b)
    if a.order == b.order then
      return tostring(a.key) < tostring(b.key)
    end
    return a.order < b.order
  end)

  return activeEntries
end

function DelveInformantLayout.UpdateTargets(snapNow)
  local activeEntries = GetActiveEntriesSorted()
  local offsetY = 0

  for i = 1, #activeEntries do
    local entry = activeEntries[i]
    local target = offsetY
    entry.targetOffsetY = target

    if snapNow then
      entry.currentOffsetY = target
      entry.animating = false
    elseif math.abs((entry.currentOffsetY or 0) - target) > 0.001 then
      entry.animFromOffsetY = entry.currentOffsetY or 0
      entry.animElapsed = 0
      entry.animDuration = DelveInformantLayout.shiftSeconds
      entry.animating = entry.animDuration > 0
      if not entry.animating then
        entry.currentOffsetY = target
      end
    end

    offsetY = offsetY - ((entry.rowHeight or 25) + (entry.rowGap or DelveInformantLayout.rowGap))
  end

  DelveInformantLayout.Apply(false)
end

function DelveInformantLayout.Apply(snapNow)
  if DelveInformantLayout.suspended then
    return
  end

  if DelveInformantLayout.UpdateTargets and snapNow then
    DelveInformantLayout.UpdateTargets(true)
  end

  local base = DelveInformantLayout.base
  for _, entry in pairs(DelveInformantLayout.entries) do
    local frame = entry.frame
    if frame and frame.ClearAllPoints and frame.SetPoint then
      frame:ClearAllPoints()
      local x = LayoutSnap(frame, base.x or 0)
      local y = LayoutSnap(frame, (base.y or 0) + (entry.currentOffsetY or 0))
      frame:SetPoint(base.point or "CENTER", UIParent, base.relativePoint or base.point or "CENTER", x, y)
    end
  end
end

function DelveInformantLayout.OnUpdate(dt)
  local anyAnimating = false

  for _, entry in pairs(DelveInformantLayout.entries) do
    if entry.animating then
      entry.animElapsed = (entry.animElapsed or 0) + (dt or 0)
      local duration = entry.animDuration or 0
      local t = 1
      if duration > 0 then
        t = LayoutClamp01(entry.animElapsed / duration)
      end
      entry.currentOffsetY = (entry.animFromOffsetY or 0) + ((entry.targetOffsetY or 0) - (entry.animFromOffsetY or 0)) * t
      if t >= 1 then
        entry.currentOffsetY = entry.targetOffsetY or entry.currentOffsetY or 0
        entry.animating = false
      else
        anyAnimating = true
      end
    end
  end

  if anyAnimating then
    DelveInformantLayout.Apply(false)
  end
end

if not DelveInformantLayout.driver then
  DelveInformantLayout.driver = CreateFrame("Frame")
  DelveInformantLayout.driver:SetScript("OnUpdate", function(_, dt)
    DelveInformantLayout.OnUpdate(dt)
  end)
end

_G.DelveInformantLayout = DelveInformantLayout
