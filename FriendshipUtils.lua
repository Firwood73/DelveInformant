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

DelveInformantDB = DelveInformantDB or {}
DelveInformantDB.Layout = DelveInformantDB.Layout or {}

DelveInformantLayout.rowGap = DelveInformantLayout.rowGap or 6
DelveInformantLayout.shiftSeconds = DelveInformantLayout.shiftSeconds or 0.25
DelveInformantLayout.entries = DelveInformantLayout.entries or {}
DelveInformantLayout.lockCallbacks = DelveInformantLayout.lockCallbacks or {}
DelveInformantLayout.moveModeCallbacks = DelveInformantLayout.moveModeCallbacks or {}
DelveInformantLayout.base = DelveInformantLayout.base or {
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
}
DelveInformantLayout.containerPadding = DelveInformantLayout.containerPadding or 8

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


local function DI_Print(msg)
  local chatFrame = DEFAULT_CHAT_FRAME
  if chatFrame and chatFrame.AddMessage then
    chatFrame:AddMessage("|cFF69CCF0DelveInformant|r: " .. tostring(msg))
  end
end

local function EnsureLayoutDBDefaults()
  DelveInformantDB = DelveInformantDB or {}
  DelveInformantDB.Layout = DelveInformantDB.Layout or {}

  if DelveInformantDB.Layout.x == nil then
    local strongboxDB = DelveInformantDB.NemesisStrongbox
    local valeeraDB = DelveInformantDB.ValeeraSanguinar
    local strongboxPos = type(strongboxDB) == "table" and strongboxDB.pos
    if type(strongboxPos) == "table" and strongboxPos.x ~= nil then
      DelveInformantDB.Layout.point = strongboxPos.point
      DelveInformantDB.Layout.relativePoint = strongboxPos.relativePoint
      DelveInformantDB.Layout.x = strongboxPos.x
      DelveInformantDB.Layout.y = strongboxPos.y
    elseif type(strongboxDB) == "table" and strongboxDB.x ~= nil then
      DelveInformantDB.Layout.point = strongboxDB.point
      DelveInformantDB.Layout.relativePoint = strongboxDB.relativePoint
      DelveInformantDB.Layout.x = strongboxDB.x
      DelveInformantDB.Layout.y = strongboxDB.y
    elseif type(valeeraDB) == "table" and valeeraDB.x ~= nil then
      DelveInformantDB.Layout.point = valeeraDB.point
      DelveInformantDB.Layout.relativePoint = valeeraDB.relativePoint
      DelveInformantDB.Layout.x = valeeraDB.x
      DelveInformantDB.Layout.y = valeeraDB.y
    end
  end

  if DelveInformantDB.moveMode == nil then
    DelveInformantDB.moveMode = false
  end

  if DelveInformantDB.locked == nil then
    local strongboxDB = DelveInformantDB.NemesisStrongbox
    local valeeraDB = DelveInformantDB.ValeeraSanguinar
    if type(strongboxDB) == "table" and strongboxDB.locked ~= nil then
      DelveInformantDB.locked = not not strongboxDB.locked
    elseif type(valeeraDB) == "table" and valeeraDB.locked ~= nil then
      DelveInformantDB.locked = not not valeeraDB.locked
    else
      DelveInformantDB.locked = true
    end
  end

  if DelveInformantDB.locked then
    DelveInformantDB.moveMode = false
  end
end

local function SaveEntryPositionToDB(entry)
  if not entry or not entry.key then
    return
  end

  local base = DelveInformantLayout.base
  local point = base.point or "CENTER"
  local relativePoint = base.relativePoint or point
  local x = LayoutSnap(entry.frame or UIParent, base.x or 0)
  local y = LayoutSnap(entry.frame or UIParent, (base.y or 0) + (entry.currentOffsetY or 0))

  if entry.key == "strongbox" then
    DelveInformantDB.NemesisStrongbox = DelveInformantDB.NemesisStrongbox or {}
    local strongboxDB = DelveInformantDB.NemesisStrongbox
    strongboxDB.pos = strongboxDB.pos or {}
    strongboxDB.pos.point = point
    strongboxDB.pos.relativePoint = relativePoint
    strongboxDB.pos.x = x
    strongboxDB.pos.y = y
    strongboxDB.point = point
    strongboxDB.relativePoint = relativePoint
    strongboxDB.x = x
    strongboxDB.y = y
  elseif entry.key == "valeera" then
    DelveInformantDB.ValeeraSanguinar = DelveInformantDB.ValeeraSanguinar or {}
    local valeeraDB = DelveInformantDB.ValeeraSanguinar
    valeeraDB.point = point
    valeeraDB.relativePoint = relativePoint
    valeeraDB.x = x
    valeeraDB.y = y
  end
end

local function SaveEntryPositionsToDB()
  for _, entry in pairs(DelveInformantLayout.entries or {}) do
    SaveEntryPositionToDB(entry)
  end
end

local function SaveLayoutBase()
  EnsureLayoutDBDefaults()
  local db = DelveInformantDB.Layout
  local base = DelveInformantLayout.base
  db.point = base.point or "CENTER"
  db.relativePoint = base.relativePoint or db.point
  db.x = base.x or 0
  db.y = base.y or 0
  SaveEntryPositionsToDB()
end

function DelveInformantLayout.RestoreBase(defaultPoint, defaultRelativePoint, defaultX, defaultY)
  EnsureLayoutDBDefaults()
  local db = DelveInformantDB.Layout
  DelveInformantLayout.base.point = db.point or defaultPoint or DelveInformantLayout.base.point or "CENTER"
  DelveInformantLayout.base.relativePoint = db.relativePoint or defaultRelativePoint or DelveInformantLayout.base.relativePoint or DelveInformantLayout.base.point
  DelveInformantLayout.base.x = tonumber(db.x)
  if DelveInformantLayout.base.x == nil then DelveInformantLayout.base.x = tonumber(defaultX) or 0 end
  DelveInformantLayout.base.y = tonumber(db.y)
  if DelveInformantLayout.base.y == nil then DelveInformantLayout.base.y = tonumber(defaultY) or 0 end
  SaveLayoutBase()
end

function DelveInformantLayout.IsLocked()
  EnsureLayoutDBDefaults()
  return not not DelveInformantDB.locked
end

function DelveInformantLayout.RegisterLockable(key, applyFn)
  if key and type(applyFn) == "function" then
    DelveInformantLayout.lockCallbacks[key] = applyFn
    applyFn(DelveInformantLayout.IsLocked())
  end
end

function DelveInformantLayout.ApplyLockStates()
  local locked = DelveInformantLayout.IsLocked()
  for _, applyFn in pairs(DelveInformantLayout.lockCallbacks) do
    applyFn(locked)
  end
end

function DelveInformantLayout.IsMoveMode()
  EnsureLayoutDBDefaults()
  return not not DelveInformantDB.moveMode
end

function DelveInformantLayout.RegisterMoveMode(key, applyFn)
  if key and type(applyFn) == "function" then
    DelveInformantLayout.moveModeCallbacks[key] = applyFn
    applyFn(DelveInformantLayout.IsMoveMode())
  end
end

function DelveInformantLayout.ApplyMoveModeStates()
  local active = DelveInformantLayout.IsMoveMode()
  for _, applyFn in pairs(DelveInformantLayout.moveModeCallbacks) do
    applyFn(active)
  end
end

function DelveInformantLayout.SetMoveMode(active, silent)
  EnsureLayoutDBDefaults()
  DelveInformantDB.moveMode = not not active
  DelveInformantLayout.ApplyMoveModeStates()
  if DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
  if not silent then
    DI_Print(DelveInformantDB.moveMode and "Move mode enabled. Drag the DelveInformant mover box to move the group, then use /dilock or /dimove to save." or "Move mode disabled.")
  end
end

function DelveInformantLayout.SetLocked(isLocked, silent)
  EnsureLayoutDBDefaults()
  DelveInformantDB.locked = not not isLocked
  if type(DelveInformantDB.NemesisStrongbox) == "table" then
    DelveInformantDB.NemesisStrongbox.locked = DelveInformantDB.locked
  end
  if type(DelveInformantDB.ValeeraSanguinar) == "table" then
    DelveInformantDB.ValeeraSanguinar.locked = DelveInformantDB.locked
  end
  DelveInformantLayout.ApplyLockStates()
  if DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
  if DelveInformantDB.locked then
    DelveInformantLayout.SetMoveMode(false, true)
  end
  if not silent then
    DI_Print(DelveInformantDB.locked and "Locked." or "Unlocked. Drag the DelveInformant mover box to move the group.")
  end
end

function DelveInformantLayout.ToggleLocked()
  DelveInformantLayout.SetLocked(not DelveInformantLayout.IsLocked())
end

function DelveInformantLayout.ToggleMoveMode()
  if DelveInformantLayout.IsMoveMode() then
    DelveInformantLayout.SetLocked(true)
  else
    DelveInformantLayout.SetLocked(false, true)
    DelveInformantLayout.SetMoveMode(true)
  end
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
  DelveInformantLayout.UpdateTargets(true)
  if DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
  return entry
end

function DelveInformantLayout.SetBaseFromFrame(frame, save)
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
  if save ~= false then
    SaveLayoutBase()
  end
  DelveInformantLayout.Apply(true)
end

function DelveInformantLayout.SetBaseFromEntryFrame(key, frame, save)
  if not key or not frame or not frame.GetPoint then
    return
  end

  local point, _, relativePoint, x, y = frame:GetPoint(1)
  if not point then
    return
  end

  local entry = DelveInformantLayout.entries[key]
  local offsetY = (entry and entry.currentOffsetY) or 0
  DelveInformantLayout.base.point = point
  DelveInformantLayout.base.relativePoint = relativePoint or point
  DelveInformantLayout.base.x = LayoutSnap(frame, x or 0)
  DelveInformantLayout.base.y = LayoutSnap(frame, (y or 0) - offsetY)
  if save ~= false then
    SaveLayoutBase()
  end
  DelveInformantLayout.Apply(true)
end

function DelveInformantLayout.SetBase(point, relativePoint, x, y, save)
  DelveInformantLayout.base.point = point or DelveInformantLayout.base.point or "CENTER"
  DelveInformantLayout.base.relativePoint = relativePoint or DelveInformantLayout.base.relativePoint or DelveInformantLayout.base.point
  DelveInformantLayout.base.x = tonumber(x) or 0
  DelveInformantLayout.base.y = tonumber(y) or 0
  if save ~= false then
    SaveLayoutBase()
  end
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

  local snapNow = active and not entry.activatedOnce
  entry.active = active
  if active then
    entry.activatedOnce = true
  end
  DelveInformantLayout.UpdateTargets(snapNow)
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
  if DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
end

local function GetFrameSize(frame)
  local width = (frame and frame.GetWidth and frame:GetWidth()) or 0
  local height = (frame and frame.GetHeight and frame:GetHeight()) or 0
  return tonumber(width) or 0, tonumber(height) or 0
end

function DelveInformantLayout.EnsureContainer()
  if DelveInformantLayout.container then
    return DelveInformantLayout.container
  end

  local container = CreateFrame("Frame", "DelveInformantMoverFrame", UIParent, "BackdropTemplate")
  container:SetFrameStrata("DIALOG")
  container:SetFrameLevel(1000)
  container:SetSize(280, 70)
  container:SetClampedToScreen(true)
  container:SetMovable(true)
  container:EnableMouse(false)
  container:RegisterForDrag("LeftButton")
  container:Hide()

  if container.SetBackdrop then
    container:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    container:SetBackdropColor(0, 0, 0, 0.25)
    container:SetBackdropBorderColor(0.41, 0.8, 0.94, 0.95)
  end

  local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOP", container, "TOP", 0, -4)
  label:SetText("DelveInformant unlocked - drag here")
  container.label = label

  local function StartContainerDrag()
    if DelveInformantLayout.StartGroupDrag then
      DelveInformantLayout.StartGroupDrag("container")
    end
  end

  local function StopContainerDrag()
    if DelveInformantLayout.StopGroupDrag then
      DelveInformantLayout.StopGroupDrag()
    end
  end

  container:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      StartContainerDrag()
    end
  end)
  container:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      StopContainerDrag()
    end
  end)
  container:SetScript("OnDragStart", StartContainerDrag)
  container:SetScript("OnDragStop", StopContainerDrag)

  DelveInformantLayout.container = container
  return container
end

function DelveInformantLayout.UpdateContainer()
  local container = DelveInformantLayout.EnsureContainer and DelveInformantLayout.EnsureContainer()
  if not container then
    return
  end

  local unlocked = not DelveInformantLayout.IsLocked()
  if not unlocked then
    container:EnableMouse(false)
    container:Hide()
    return
  end

  local activeEntries = GetActiveEntriesSorted()
  local padding = DelveInformantLayout.containerPadding or 10
  local maxWidth = 0
  local topOffset
  local bottomOffset

  for i = 1, #activeEntries do
    local entry = activeEntries[i]
    local frameWidth, actualFrameHeight = GetFrameSize(entry.frame)
    local frameHeight = tonumber(entry.rowHeight) or actualFrameHeight
    maxWidth = math.max(maxWidth, frameWidth)

    local offset = entry.currentOffsetY or 0
    local top = offset + (frameHeight / 2)
    local bottom = offset - (frameHeight / 2)
    topOffset = topOffset and math.max(topOffset, top) or top
    bottomOffset = bottomOffset and math.min(bottomOffset, bottom) or bottom
  end

  if not topOffset or not bottomOffset then
    maxWidth = 250
    topOffset = 15
    bottomOffset = -15
  end

  local width = LayoutSnap(container, maxWidth + (padding * 2))
  local height = LayoutSnap(container, (topOffset - bottomOffset) + (padding * 2) + 16)
  local centerOffsetY = ((topOffset + bottomOffset) / 2) - 8
  local base = DelveInformantLayout.base

  container:SetSize(math.max(width, 180), math.max(height, 40))
  container:ClearAllPoints()
  container:SetPoint(base.point or "CENTER", UIParent, base.relativePoint or base.point or "CENTER", LayoutSnap(container, base.x or 0), LayoutSnap(container, (base.y or 0) + centerOffsetY))
  container:EnableMouse(true)
  container:Show()
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

  if DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
end

function DelveInformantLayout.StartGroupDrag(key)
  if DelveInformantLayout.IsLocked() or not GetCursorPosition then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
  DelveInformantLayout.drag = {
    key = key,
    cursorX = cursorX or 0,
    cursorY = cursorY or 0,
    scale = scale,
    baseX = DelveInformantLayout.base.x or 0,
    baseY = DelveInformantLayout.base.y or 0,
  }
end

function DelveInformantLayout.StopGroupDrag()
  if not DelveInformantLayout.drag then
    return
  end

  DelveInformantLayout.drag = nil
  SaveLayoutBase()
  DelveInformantLayout.Apply(true)
  DI_Print("Position saved.")
end

local function UpdateGroupDrag()
  local drag = DelveInformantLayout.drag
  if not drag or not GetCursorPosition then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  local scale = drag.scale or 1
  DelveInformantLayout.base.x = LayoutSnap(UIParent, (drag.baseX or 0) + ((cursorX or 0) - (drag.cursorX or 0)) / scale)
  DelveInformantLayout.base.y = LayoutSnap(UIParent, (drag.baseY or 0) + ((cursorY or 0) - (drag.cursorY or 0)) / scale)
  DelveInformantLayout.Apply(false)
end

function DelveInformantLayout.OnUpdate(dt)
  UpdateGroupDrag()

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
  elseif DelveInformantLayout.UpdateContainer then
    DelveInformantLayout.UpdateContainer()
  end
end

EnsureLayoutDBDefaults()
if not DelveInformantLayout.baseRestored then
  DelveInformantLayout.RestoreBase("CENTER", "CENTER", 0, 0)
  DelveInformantLayout.baseRestored = true
end

if not DelveInformantLayout.driver then
  DelveInformantLayout.driver = CreateFrame("Frame")
  DelveInformantLayout.driver:SetScript("OnUpdate", function(_, dt)
    DelveInformantLayout.OnUpdate(dt)
  end)
end

SLASH_DELVEINFORMANTLOCK1 = "/dilock"
SlashCmdList["DELVEINFORMANTLOCK"] = function() DelveInformantLayout.SetLocked(true) end

SLASH_DELVEINFORMANTUNLOCK1 = "/diunlock"
SlashCmdList["DELVEINFORMANTUNLOCK"] = function()
  DelveInformantLayout.SetLocked(false, true)
  DelveInformantLayout.SetMoveMode(true)
end

SLASH_DELVEINFORMANTMOVE1 = "/dimove"
SlashCmdList["DELVEINFORMANTMOVE"] = function() DelveInformantLayout.ToggleMoveMode() end

_G.DelveInformantLayout = DelveInformantLayout
