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

_G.PrintFriendshipBar = PrintFriendshipBar
