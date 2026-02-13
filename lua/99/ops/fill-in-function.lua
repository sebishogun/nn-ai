local geo = require("99.geo")
local Point = geo.Point
local Request = require("99.request")
local Mark = require("99.ops.marks")
local editor = require("99.editor")
local RequestStatus = require("99.ops.request_status")
local Window = require("99.window")
local make_clean_up = require("99.ops.clean-up")

local IMPORTS_MARKER = "---99-IMPORTS-END---"

--- Split response into imports and function body.
--- If the marker is present, everything before it is imports, everything after is the function.
--- @param res string
--- @return string[] imports, string function_body
local function parse_imports(res)
  local marker_pos = res:find(IMPORTS_MARKER, 1, true)
  if not marker_pos then
    return {}, res
  end
  local imports_str = res:sub(1, marker_pos - 1)
  local func_str = res:sub(marker_pos + #IMPORTS_MARKER + 1) -- +1 for newline
  -- Strip leading/trailing whitespace from func
  func_str = func_str:gsub("^%s*\n", "")
  local import_lines = {}
  for line in imports_str:gmatch("[^\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      table.insert(import_lines, trimmed)
    end
  end
  return import_lines, func_str
end

--- Find the line index (0-based) after the last existing import/use/require in the buffer.
--- Returns 0 if no imports found (inserts at top).
--- @param buffer number
--- @return number
local function find_import_insert_line(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  local last_import_line = -1
  for i, line in ipairs(lines) do
    -- Match common import patterns across languages
    if
      line:match("^import ")
      or line:match("^from .+ import")
      or line:match("^use ")
      or line:match("^local .+ = require")
      or line:match("^require%(")
      or line:match("^#include")
      or line:match("^const .+ = require")
      or line:match("^const {.+} from")
      or line:match("^import {")
      or line:match("^import %(")
    then
      last_import_line = i -- 1-based
    end
  end
  if last_import_line == -1 then
    -- No imports found; check for package declaration (Go) or shebang
    for i, line in ipairs(lines) do
      if line:match("^package ") then
        return i -- insert after package line (0-based = i because ipairs is 1-based)
      end
      if line:match("^#!") then
        return i
      end
    end
    return 0
  end
  return last_import_line -- 0-based insert point = 1-based last import line
end

--- Check if an import line already exists in the buffer
--- @param buffer number
--- @param import_line string
--- @return boolean
local function import_exists(buffer, import_line)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:match("^%s*(.-)%s*$") == import_line then
      return true
    end
  end
  return false
end

--- Add missing imports to the buffer
--- @param buffer number
--- @param imports string[]
--- @param logger any
local function add_missing_imports(buffer, imports, logger)
  if #imports == 0 then
    return
  end
  local to_add = {}
  for _, imp in ipairs(imports) do
    if not import_exists(buffer, imp) then
      table.insert(to_add, imp)
      logger:debug("adding import", "line", imp)
    else
      logger:debug("import already exists, skipping", "line", imp)
    end
  end
  if #to_add == 0 then
    return
  end
  local insert_at = find_import_insert_line(buffer)
  vim.api.nvim_buf_set_lines(buffer, insert_at, insert_at, false, to_add)
end

--- @param context _99.RequestContext
--- @param res string
local function update_file_with_changes(context, res)
  local buffer = context.buffer
  local mark = context.marks.function_location
  local logger =
    context.logger:set_area("fill_in_function#update_file_with_changes")

  logger:assert(
    mark and buffer,
    "mark and buffer have to be set on the location object"
  )
  logger:assert(mark:is_valid(), "mark is no longer valid")

  -- Parse imports from response
  local imports, func_body = parse_imports(res)

  local func_start = Point.from_mark(mark)
  local ts = editor.treesitter
  local func = ts.containing_function(context, func_start)

  logger:assert(
    func,
    "update_file_with_changes: unable to find function at mark location"
  )

  local lines = vim.split(func_body, "\n")
  func:replace_text(lines)

  -- Add missing imports after replacing the function
  add_missing_imports(buffer, imports, logger)
end

--- @param context _99.RequestContext
--- @param opts? _99.ops.Opts
local function fill_in_function(context, opts)
  opts = opts or {}
  local logger = context.logger:set_area("fill_in_function")
  local ts = editor.treesitter

  -- Restore focus to original window if it's still valid
  if context.window and vim.api.nvim_win_is_valid(context.window) then
    vim.api.nvim_set_current_win(context.window)
  end

  -- Use stored cursor position from context if available, otherwise get current
  local cursor
  if context.cursor_pos then
    -- cursor_pos is [row, col] from nvim_win_get_cursor (1-indexed row, 0-indexed col)
    cursor =
      Point.from_0_based(context.cursor_pos[1] - 1, context.cursor_pos[2])
  else
    cursor = Point:from_cursor()
  end

  local ok, result = pcall(ts.containing_function, context, cursor)
  local func = ok and result or nil

  if not func then
    local detail = not ok and tostring(result)
      or (
        "is treesitter parser installed for "
        .. (context.file_type or "unknown")
        .. "?"
      )
    logger:error(
      "fill_in_function: unable to find containing function",
      "error",
      detail
    )
    vim.notify(
      "99: No function found at cursor position (" .. detail .. ")",
      vim.log.levels.WARN
    )
    return
  end

  context.range = func.function_range

  logger:debug("fill_in_function", "opts", opts)
  local virt_line_count = context._99.ai_stdout_rows
  if virt_line_count >= 0 then
    context.marks.function_location = Mark.mark_func_body(context.buffer, func)
  end

  local request = Request.new(context)
  local full_prompt =
    context._99.prompts.prompts.fill_in_function(context.file_type)
  local additional_prompt = opts.additional_prompt
  if additional_prompt then
    full_prompt =
      context._99.prompts.prompts.prompt(additional_prompt, full_prompt)
  end

  local additional_rules = opts.additional_rules
  if additional_rules then
    logger:debug("additional_rules", "additional_rules", additional_rules)
    context:add_agent_rules(additional_rules)
  end

  request:add_prompt_content(full_prompt)

  local request_status = RequestStatus.new(
    250,
    context._99.ai_stdout_rows,
    "Loading",
    context.marks.function_location
  )
  request_status:start()

  local clean_up = make_clean_up(context, "Fill In Function", function()
    context:clear_marks()
    request:cancel()
    request_status:stop()
  end)

  request:start({
    on_stdout = function(line)
      request_status:push(line)
    end,
    on_complete = function(status, response)
      logger:info("on_complete", "status", status, "response", response)
      vim.schedule(clean_up)

      if status == "failed" then
        if context._99.display_errors then
          Window.display_error(
            "Error encountered while processing fill_in_function\n"
              .. (response or "No Error text provided.  Check logs")
          )
        end
        logger:error(
          "unable to fill in function, enable and check logger for more details"
        )
      elseif status == "cancelled" then
        logger:debug("fill_in_function was cancelled")
        -- TODO: small status window here
      elseif status == "success" then
        local apply_ok, err = pcall(update_file_with_changes, context, response)
        if not apply_ok then
          logger:error("Failed to apply changes", "error", tostring(err))
          vim.notify(
            "99: Failed to apply changes: " .. tostring(err),
            vim.log.levels.ERROR
          )
        end
      end
    end,
    on_stderr = function(line)
      logger:debug("fill_in_function#on_stderr", "line", line)
    end,
  })
end

return fill_in_function
