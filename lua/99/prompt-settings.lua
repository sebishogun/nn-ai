---@param buffer number
---@return string
local function get_file_contents(buffer)
  local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  return table.concat(lines, "\n")
end

--- @class _99.Prompts.SpecificOperations
--- @field visual_selection fun(range: _99.Range, filetype: string): string
--- @field fill_in_function fun(filetype: string): string
--- @field implement_function fun(filetype: string): string
local prompts = {
  --- System role prompt - sets the AI's persona
  --- @return string
  role = function()
    return [[You are an expert software engineer. You write robust, canonical, idiomatic code.
You follow best practices and conventions for the language you are working in.
You ALWAYS return ONLY raw code - no markdown fences, no explanations, no conversation.]]
  end,

  --- Fill in function body prompt
  --- @param filetype string The programming language (e.g., "lua", "rust", "go")
  --- @return string
  fill_in_function = function(filetype)
    return string.format([[
You are given a function to implement in %s.

TASK: Create the complete function body.

RULES:
1. Return ONLY the complete function including its signature
2. Do NOT include any text before or after the function
3. Do NOT wrap code in markdown fences (no ```%s or ``` blocks)
4. Do NOT include explanations or comments about what you did
5. If the function already has partial contents, use those as context
6. Check the file for helper functions, types, or context you can use
7. Write idiomatic %s code following best practices

<Example language="typescript">
<Input>
export function fizz_buzz(count: number): void {
}
</Input>
<Output>
export function fizz_buzz(count: number): void {
  for (let i = 1; i <= count; i++) {
    if (i %% 15 === 0) {
      console.log("FizzBuzz");
    } else if (i %% 3 === 0) {
      console.log("Fizz");
    } else if (i %% 5 === 0) {
      console.log("Buzz");
    } else {
      console.log(i);
    }
  }
}
</Output>
<Notes>
- Keep modifiers/signature details present in the input (e.g. export/async/public)
- Return ONLY the function, nothing else
</Notes>
</Example>

If there are DIRECTIONS provided, follow them precisely. Do not deviate.
]], filetype or "the given language", filetype or "", filetype or "the given language")
  end,

  --- Implement function at call site prompt
  --- @param filetype string The programming language
  --- @return string
  implement_function = function(filetype)
    return string.format([[
You are given a function call in %s that references a function which does not exist yet.

TASK: Implement the missing function based on how it is being called.

RULES:
1. Return ONLY the complete function implementation
2. Do NOT include any text before or after the function
3. Do NOT wrap code in markdown fences (no ```%s or ``` blocks)
4. Infer the function signature from the call site (parameter types, return type)
5. Infer the function behavior from its name and how the result is used
6. Write idiomatic %s code following best practices
7. Include appropriate error handling if the language supports it

If there are DIRECTIONS provided, follow them precisely.
]], filetype or "the given language", filetype or "", filetype or "the given language")
  end,

  --- Output file instructions
  --- @return string
  output_file = function()
    return [[
CRITICAL OUTPUT RULES:
1. NEVER alter any file other than TEMP_FILE
2. NEVER provide conversational output - return ONLY code
3. ONLY write the requested code changes to TEMP_FILE
4. Do NOT include markdown code fences in your output
5. Do NOT include explanations before or after the code
]]
  end,

  --- Wrap user prompt with action context
  --- @param prompt string User's directions
  --- @param action string The action/context prompt
  --- @return string
  prompt = function(prompt, action)
    return string.format(
      [[
<DIRECTIONS>
%s
</DIRECTIONS>
<Context>
%s
</Context>
]],
      prompt,
      action
    )
  end,

  --- Visual selection replacement prompt
  --- @param range _99.Range The selected range
  --- @param filetype string The programming language
  --- @return string
  visual_selection = function(range, filetype)
    -- Get human-readable location (line:col to line:col)
    local start_line = range.start.row
    local start_col = range.start.col
    local end_line = range.end_.row
    local end_col = range.end_.col
    local location = string.format("Lines %d:%d to %d:%d", start_line, start_col, end_line, end_col)

    return string.format(
      [[
You are given a code selection in %s that you need to replace with new code.

TASK: Replace the selected code with an improved or corrected version.

RULES:
1. Return ONLY the replacement code
2. Do NOT include any text before or after the code
3. Do NOT wrap code in markdown fences (no ```%s or ``` blocks)
4. If the selection contains TODO/FIXME comments, implement what they describe
5. Maintain the same indentation level as the original selection
6. Consider the surrounding file context when writing the replacement

<SELECTION_LOCATION>
%s
</SELECTION_LOCATION>
<SELECTION_CONTENT>
%s
</SELECTION_CONTENT>
<FILE_CONTEXT>
%s
</FILE_CONTEXT>

If there are DIRECTIONS provided, follow them precisely.
]],
      filetype or "the given language",
      filetype or "",
      location,
      range:to_text(),
      get_file_contents(range.buffer)
    )
  end,

  -- luacheck: ignore 631
  read_tmp = "Never attempt to read TEMP_FILE. It is purely for output. Previous contents can be overwritten without concern.",
}

--- @class _99.Prompts
local prompt_settings = {
  prompts = prompts,

  --- @param tmp_file string
  --- @return string
  tmp_file_location = function(tmp_file)
    return string.format(
      "<OutputInstructions>\n%s\n%s\n</OutputInstructions>\n<TEMP_FILE>%s</TEMP_FILE>",
      prompts.output_file(),
      prompts.read_tmp,
      tmp_file
    )
  end,

  ---@param context _99.RequestContext
  ---@return string
  get_file_location = function(context)
    context.logger:assert(
      context.range,
      "get_file_location requires range specified"
    )
    -- Use human-readable format instead of internal range representation
    local start_line = context.range.start.row
    local end_line = context.range.end_.row
    return string.format(
      "<Location><File>%s</File><Lines>%d-%d</Lines></Location>",
      context.full_path,
      start_line,
      end_line
    )
  end,

  --- @param range _99.Range
  get_range_text = function(range)
    return string.format("<FunctionText>\n%s\n</FunctionText>", range:to_text())
  end,
}

return prompt_settings
