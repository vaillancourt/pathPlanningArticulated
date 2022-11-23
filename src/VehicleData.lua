--local io = require(io)
--local string = require(string)
local Vector2 = require "Vector2"
local Common = require "Common"

local VehicleData = {
  data = {},
  theoretical_max_angle = 0.785398 -- 45° / 180 * math.pi()
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
    -- local centerOfRotationX__ = 7
    -- local centerOfRotationY__ = 8
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
        turning_radius = turning_radius,
        entry_id = entryId
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

function VehicleData.get_estimated_values_for_ratio(self_, direction_, entry_speed_, joint_angle_ratio_)
  joint_angle_ratio_ = math.abs(joint_angle_ratio_)

  local key_entry = direction_ .. "." .. entry_speed_ .. "." .. "STEERING"
  local key_exit = direction_ .. "." .. "MOVING" .. "." .. "DESTEERING"

  local entry_maximum_joint_angle =
    math.abs(self_.data[key_entry].entries[self_.data[key_entry].last_entry].joint_angle)
  local exit_maximum_joint_angle = math.abs(self_.data[key_exit].entries[1].joint_angle)

  local effective_maximum_joint_angle = math.min(entry_maximum_joint_angle, exit_maximum_joint_angle)

  local desired_angle = math.min(joint_angle_ratio_ * self_.theoretical_max_angle, effective_maximum_joint_angle)

  -- require "pl/pretty"(entry_maximum_joint_angle, exit_maximum_joint_angle, effective_maximum_joint_angle,
  -- desired_angle)

  -- print("desired_angle", desired_angle)

  local lerp = Common.lerp

  local a = math.abs(desired_angle)
  local b = math.pi / 2 - a
  local R = 3.50466
  local F = 1.165728
  local PQ = F / math.cos(a)
  local CR = math.tan(b) * (R + PQ)

  -- const double b = simMath::PI_2 - a;
  -- const double R = componentControllerADT->mSettings.mDistancePinToRearWheelsCenter;
  -- const double F = componentControllerADT->mSettings.mDistancePinToFrontWheelsCenter;
  -- const double H = componentControllerADT->mSettings.mDistanceWheelToCenter;
  -- const double W = componentControllerADT->mSettings.mHalfDistanceBetweenRearWheels;

  -- const double PQ = F / std::cos( a );
  -- const double CR = std::tan( b ) * ( R + PQ );

  local get_curve_entry_data = function()
    local entry_1 = {}
    local entry_2 = {}

    local was_first_skipped = false
    for k, v in ipairs(self_.data[key_entry].entries) do
      if not was_first_skipped then
        was_first_skipped = true
        goto continue1
      end
      local previous = self_.data[key_entry].entries[k - 1]
      local current = v

      if desired_angle <= math.abs(current.joint_angle) then
        entry_1 = previous
        entry_2 = current
        break
      end

      ::continue1::
    end

    -- print("entry; entry_1")
    -- require "pl/pretty".dump(entry_1)
    -- print("entry; entry_2")
    -- require "pl/pretty".dump(entry_2)

    local ratio_from_entry_1_to_entry_2 =
      (desired_angle - math.abs(entry_1.joint_angle)) / (math.abs(entry_2.joint_angle) - math.abs(entry_1.joint_angle))

    return {
      position = Vector2(
        lerp(entry_1.rear_body_pos.x, entry_2.rear_body_pos.x, ratio_from_entry_1_to_entry_2),
        lerp(entry_1.rear_body_pos.y, entry_2.rear_body_pos.y, ratio_from_entry_1_to_entry_2)
      ),
      orientation = lerp(entry_1.rear_body_angle, entry_2.rear_body_angle, ratio_from_entry_1_to_entry_2)
    }, CR
  end

  local get_curve_exit_data = function()
    local entry_1 = {}
    local entry_2 = {}

    for k, v in ipairs(self_.data[key_exit].entries) do
      if k == self_.data[key_exit].last_entry then
        goto continue2
      end

      local current = v
      local next = self_.data[key_exit].entries[k + 1]

      if math.abs(next.joint_angle) <= desired_angle then
        entry_1 = current
        entry_2 = next
        break
      end

      ::continue2::
    end

    if not entry_1.rear_body_pos then
      entry_1 = self_.data[key_exit].entries[self_.data[key_exit].last_entry - 1]
      entry_2 = self_.data[key_exit].entries[self_.data[key_exit].last_entry]
    end

    -- print("exit; entry_1")
    -- require "pl/pretty".dump(entry_1)
    -- print("exit; entry_2")
    -- require "pl/pretty".dump(entry_2)

    local abs = function(num_)
      if not num_ then
        return 0
      end
      if num_ < 0 then
        return -num_
      end
      return num_
    end

    local ratio_from_entry_2_to_entry_1 =
      (desired_angle - abs(entry_2.joint_angle)) / (abs(entry_1.joint_angle) - abs(entry_2.joint_angle))

    -- print("desired_angle ", desired_angle)
    -- print("ratio_from_entry_1_to_entry_2 ", ratio_from_entry_1_to_entry_2)
    -- print("entry_1")
    -- require "pl/pretty".dump(entry_1)
    -- print("entry_2")
    -- require "pl/pretty".dump(entry_2)

    local interpolated_position =
      Vector2(
      lerp(entry_2.rear_body_pos.x, entry_1.rear_body_pos.x, ratio_from_entry_2_to_entry_1),
      lerp(entry_2.rear_body_pos.y, entry_1.rear_body_pos.y, ratio_from_entry_2_to_entry_1)
    )
    local interpolated_orientation =
      lerp(entry_2.rear_body_angle, entry_1.rear_body_angle, ratio_from_entry_2_to_entry_1)

    local last_entry_index = self_.data[key_exit].last_entry
    local last_entry_data = self_.data[key_exit].entries[last_entry_index]

    -- if desired_angle >= effective_maximum_joint_angle then
    --   local position = last_entry_data.rear_body_pos
    --   local orientation = last_entry_data.rear_body_angle
    --   local turning_radius = last_entry_data.turning_radius
    --   local effective_joint_angle_ratio = effective_maximum_joint_angle / self_.theoretical_max_angle

    --   return {position = position, orientation = orientation}, turning_radius, effective_joint_angle_ratio
    -- end

    local adjusted_position = last_entry_data.rear_body_pos - interpolated_position
    local adjusted_orientation = last_entry_data.rear_body_angle - interpolated_orientation
    return {position = adjusted_position, orientation = adjusted_orientation}
  end

  local curve_entry_location, curve_entry_radius = get_curve_entry_data()
  local curve_exit_location = get_curve_exit_data()

  return {
    effective_joint_angle_ratio = desired_angle / self_.theoretical_max_angle,
    curve_radius = curve_entry_radius,
    curve_entry_location = curve_entry_location,
    curve_exit_location = curve_exit_location
  }
end

return VehicleData
