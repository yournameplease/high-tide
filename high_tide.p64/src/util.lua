
function measure_string(str)
  local x, y = print(str, 0, -1000)

  return x, y + 1000
end
