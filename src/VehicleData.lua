--local io = require(io)
--local string = require(string)
local SCALE = 10.0

local VehicleData = {
  data = {},
  rRadius = 5.15325 * SCALE,
  offset_data = {
    FORWARD = {
      MOVING = {
        STEERING = {
          -- stop_fwd_left-right_reset	3	144	1.96028	0.1279	0.0223739	0.78039
          orientation = 0.0223739,
          position = { x = 1.96028 * SCALE, y = 0.1279 * SCALE }
        },
        DESTEERING = {
          -- stop_fwd_left-right_reset	2	157	1.74404	0.574084	0.293663	-0.00501247
          orientation = 0.293663,
          position = { x = 1.74404 * SCALE, y = 0.574084 * SCALE }
        }
      },
      STOPPED = {
        STEERING = {
          -- stop_fwd_left-right_reset	1	142	1.82853	-0.111583	-0.0225189	-0.780212
          orientation = 0.0225189,
          position = { x = 1.82853 * SCALE, y = 0.111583 * SCALE }
        }
      }
    },
    REVERSE = {
      MOVING = {
        STEERING = {
          -- stop_rev_left-right_reset	3	145	-0.788294	0.121861	0.228424	0.779899
          orientation = 0.228424,
          position = { x = 0.788294 * SCALE, y = 0.121861 * SCALE }
        },
        DESTEERING = {
          -- stop_rev_left-right_reset	2	161	-1.14171	0.0526548	0.0785967	-0.0050098
          orientation = 0.0785967,
          position = { x = 1.14171 * SCALE, y = 0.0526548 * SCALE }
        }
      },
      STOPPED = {
        STEERING = {
          -- stop_rev_left-right_reset	1	144	-0.751856	-0.115498	-0.22438	-0.780039
          orientation = 0.22438,
          position = { x = 0.751856 * SCALE, y = 0.115498 * SCALE }
        }
      }
    }
  }
}
-- luacheck: globals string
-- https://nocurve.com/2014/03/05/simple-csv-read-and-write-using-lua/
function string:split(sSeparator, nMax, bRegexp)
    if sSeparator == '' then
        sSeparator = ','
    end

    if nMax and nMax < 1 then
        nMax = nil
    end

    local aRecord = {}

    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end

    return aRecord
end

function VehicleData:new(o)
  o = o or {}
  setmetatable(o, VehicleData)
  self.__index = self

  local current_dir = io.popen"cd":read'*l'
  --print(current_dir)

  local data_file = io.open(current_dir.."\\src\\assets\\vehicleTurning.csv")
  if not data_file then
    data_file = assert(io.open(current_dir.."\\assets\\vehicleTurning.csv"))
  end

  local data = {}
  local was_first_line_processed = false
  for line in data_file:lines() do
    if not was_first_line_processed then
      was_first_line_processed = true
      goto continue
    end

    local line_content = line:split(',')
    -- 1: test
    -- 2: state
    -- 3: entryId
    -- 4: rearBodyPosX
    -- 5: rearBodyPosY
    -- 6: rearBodyAngle
    -- 7: jointAngle

    local test = line_content[1]
    local state = tonumber(line_content[2])
    local entryId = tonumber(line_content[3])
    local rearBodyPos = {x = tonumber(line_content[4]), y = tonumber(line_content[5])}
    local rearBodyAngle = tonumber(line_content[6])
    local jointAngle = tonumber(line_content[7])

    -- print(line)
    -- print("line_content:")
    -- require "pl.pretty".dump(line_content)
    -- print(state, entryId)
    if state == 1 and entryId == 1 then
      -- print("pouf")
      data[test] = {}
      data[test][1] = {}
      data[test][2] = {}
      data[test][3] = {}
      data[test][4] = {}
    end

    -- print(data[test])
    -- print(data[test][state])
    table.insert(data[test][state], {rearBodyPos = rearBodyPos, rearBodyAngle = rearBodyAngle, jointAngle = jointAngle})

    ::continue::
  end

  o.data = data

  data_file:close()

  return o
end

return VehicleData
