-- luacheck: globals describe it assert
local eq = assert.are.same
local Providers = require("99.providers")

describe("providers", function()
  describe("OpenCodeProvider", function()
    it("builds correct command with model", function()
      local request = { context = { model = "anthropic/claude-opus-4-6" } }
      local cmd =
        Providers.OpenCodeProvider._build_command(nil, "test query", request)
      eq(
        {
          "opencode",
          "run",
          "--agent",
          "neovim",
          "-m",
          "anthropic/claude-opus-4-6",
          "test query",
        },
        cmd
      )
    end)

    it("has correct default model", function()
      eq(
        "anthropic/claude-opus-4-6",
        Providers.OpenCodeProvider._get_default_model()
      )
    end)
  end)

  describe("ClaudeCodeProvider", function()
    it("builds correct command with model", function()
      local request = { context = { model = "claude-opus-4-6" } }
      local cmd =
        Providers.ClaudeCodeProvider._build_command(nil, "test query", request)
      eq({
        "claude",
        "--dangerously-skip-permissions",
        "--model",
        "claude-opus-4-6",
        "--print",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("claude-opus-4-6", Providers.ClaudeCodeProvider._get_default_model())
    end)
  end)

  describe("CopilotCLIProvider", function()
    it("builds correct command with model", function()
      local request = { context = { model = "claude-opus-4.6" } }
      local cmd =
        Providers.CopilotCLIProvider._build_command(nil, "test query", request)
      eq({
        "copilot",
        "-p",
        "test query",
        "--model",
        "claude-opus-4.6",
        "--silent",
        "--yolo",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("claude-opus-4.6", Providers.CopilotCLIProvider._get_default_model())
    end)
  end)

  describe("CodexProvider", function()
    it("builds correct command with model", function()
      local request = { context = { model = "gpt-codex-5.3" } }
      local cmd = Providers.CodexProvider._build_command(nil, "test query", request)
      eq({
        "codex",
        "exec",
        "--dangerously-bypass-approvals-and-sandbox",
        "-m",
        "gpt-codex-5.3",
        "test query",
      }, cmd)
    end)

    it("has correct default model", function()
      eq("gpt-codex-5.3", Providers.CodexProvider._get_default_model())
    end)
  end)

  describe("provider integration", function()
    it("can be set as provider override", function()
      local _99 = require("99")

      _99.setup({ provider = Providers.ClaudeCodeProvider })
      local state = _99.__get_state()
      eq(Providers.ClaudeCodeProvider, state.provider_override)
    end)

    it(
      "uses OpenCodeProvider default model when no provider or model specified",
      function()
        local _99 = require("99")

        _99.setup({})
        local state = _99.__get_state()
        eq("anthropic/claude-opus-4-6", state.model)
      end
    )

    it(
      "uses ClaudeCodeProvider default model when provider specified but no model",
      function()
        local _99 = require("99")

        _99.setup({ provider = Providers.ClaudeCodeProvider })
        local state = _99.__get_state()
        eq("claude-opus-4-6", state.model)
      end
    )

    it("uses custom model when both provider and model specified", function()
      local _99 = require("99")

      _99.setup({
        provider = Providers.ClaudeCodeProvider,
        model = "custom-model",
      })
      local state = _99.__get_state()
      eq("custom-model", state.model)
    end)
  end)

  describe("BaseProvider", function()
    it("all providers have make_request", function()
      eq("function", type(Providers.OpenCodeProvider.make_request))
      eq("function", type(Providers.ClaudeCodeProvider.make_request))
      eq("function", type(Providers.CopilotCLIProvider.make_request))
      eq("function", type(Providers.GeminiProvider.make_request))
      eq("function", type(Providers.CodexProvider.make_request))
    end)
  end)
end)
