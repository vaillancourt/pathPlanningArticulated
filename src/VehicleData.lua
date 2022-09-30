--local io = require(io)
--local string = require(string)
local Vector2 = require "Vector2"

local SCALE = 1.0

local VehicleData = {
  data = {}
}

-- luacheck: globals string
-- https://nocurve.com/2014/03/05/simple-csv-read-and-write-using-lua/
function string:split(sSeparator, nMax, bRegexp)
  if sSeparator == "" then
    sSeparator = ","
  end

  if nMax and nMax < 1 then
    nMax = nil
  end

  local aRecord = {}

  if self:len() > 0 then
    local bPlain = not bRegexp
    nMax = nMax or -1

    local nField, nStart = 1, 1
    local nFirst, nLast = self:find(sSeparator, nStart, bPlain)
    while nFirst and nMax ~= 0 do
      aRecord[nField] = self:sub(nStart, nFirst - 1)
      nField = nField + 1
      nStart = nLast + 1
      nFirst, nLast = self:find(sSeparator, nStart, bPlain)
      nMax = nMax - 1
    end
    aRecord[nField] = self:sub(nStart)
  end

  return aRecord
end

function VehicleData:new(o)
  o = o or {}
  setmetatable(o, VehicleData)
  self.__index = self

  local current_dir = io.popen "cd":read "*l"
  --print(current_dir)

  local data_file = io.open(current_dir .. "\\src\\assets\\vehicleTurning.csv")
  if not data_file then
    data_file = assert(io.open(current_dir .. "\\assets\\vehicleTurning.csv"))
  end

  local data = {}
  local phases = {}
  local was_first_line_processed = false
  for line in data_file:lines() do
    if not was_first_line_processed then
      was_first_line_processed = true
      goto continue
    end

    local line_content = line:split(",")
    local phase__ = 1
    local frame__ = 2
    local turningRadius__ = 3
    local rearBodyPosX__ = 4
    local rearBodyPosY__ = 5
    local rearBodyHeading__ = 6
    local centerOfRotationX__ = 7
    local centerOfRotationY__ = 8
    local jointAngle__ = 9

    local phase = line_content[phase__]
    phases[phase] = true
    local entryId = tonumber(line_content[frame__])
    local turning_radius = tonumber(line_content[turningRadius__])
    local rearBodyPos = Vector2(tonumber(line_content[rearBodyPosX__]), tonumber(line_content[rearBodyPosY__]))
    local rearBodyAngle = tonumber(line_content[rearBodyHeading__])
    local jointAngle = tonumber(line_content[jointAngle__])

    if entryId == 1 then
      data[phase] = {entries = {}, last_entry = 0}
    end

    table.insert(
      data[phase].entries,
      {
        rear_body_pos = rearBodyPos,
        rear_body_angle = rearBodyAngle,
        joint_angle = jointAngle,
        turning_radius = turning_radius
      }
    )
    if entryId > data[phase].last_entry then
      data[phase].last_entry = entryId
    end

    ::continue::
  end

  o.data = data
  o.phases = phases

  data_file:close()

  return o
end

return VehicleData
