local M = {}

M.names = {
  body = "block",
}

--- @param item_name string
--- @return string
function M.log_item(item_name)
  return string.format(
    'std.debug.print("%s = {any}\\n", .{%s});',
    item_name,
    item_name
  )
end

return M
