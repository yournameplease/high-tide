
function measure_string(str)
  local x, y = print(str, 0, -1000)

  return x, y + 1000
end

function to_time_string(frames)
  local seconds = (frames % 3600) / 60
  local minutes = frames // 60 // 60

  if minutes >= 100 then
    minutes = 99
    seconds = 59 + 59/60
  end

  local fstring
  if seconds < 10 then
    -- surely there is a flag for this...
    fstring = "%.2d:0%.2f"
  else
    fstring = "%.2d:%.2f"
  end
  return string.format(fstring, minutes, seconds)
end
