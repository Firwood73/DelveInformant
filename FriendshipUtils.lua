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

_G.PrintFriendshipBar = PrintFriendshipBar
_G.GetCurrentDelveGroup = GetCurrentDelveGroup

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
