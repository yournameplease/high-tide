
function measure_string(str)
  local x, y = print(str, 0, -1000)

  return x, y + 1000
end

function to_time_string(frames)
  local seconds = (frames % 3600) / 60
  local minutes = frames // 60 // 60

  minutes = min(minutes, 99)

  return string.format("%.2d:%02.2f", minutes, seconds)
end
