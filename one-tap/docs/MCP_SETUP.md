# MCP setup (on your Windows PC)

The repo's `.mcp.json` (in the repo root) tells **Claude Code** about two MCP servers. Both control apps running on your own computer, so they only work when Claude runs on that PC. A cloud session can't reach Studio or Blender.

| Server | What it does | Needs |
|---|---|---|
| `Roblox_Studio` | Lets Claude read and edit your open Studio place (insert models, run code, check the Output window) | Roblox Studio open, with its MCP server enabled |
| `blender` | Lets Claude drive an open Blender window | Blender open with the Blender MCP add-on connected, and `uv` installed |

ForgeGUI is different: it's a claude.ai connector on your account and works in cloud sessions too. It's what can publish images, models and audio to your Roblox account (@designerissues).

## 1. Roblox Studio

1. Open Roblox Studio and any place.
2. Turn on Studio's built-in MCP server. Open the **Assistant** panel, click the **⋯** menu, choose **Manage MCP Servers**, and enable Studio as an MCP server. The menu names can move between Studio versions. If they don't match, check Roblox's guide: <https://create.roblox.com/docs/studio/mcp>
3. `.mcp.json` already holds the Windows launcher Studio gave you: `cmd.exe /c "cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat"`.

Only connect MCP clients you trust: they can read and change your open places.

## 2. Blender

1. Install **uv**: `winget install astral-sh.uv` (or `pip install uv`). Restart your terminal afterwards.
2. Download `addon.py` from <https://github.com/ahujasid/blender-mcp>.
3. In Blender, go to **Edit → Preferences → Add-ons**, choose **Install from Disk**, pick `addon.py`, and enable **Blender MCP**.
4. In the 3D view, press **N**, open the **BlenderMCP** tab and click **Connect**.

## 3. Use it

1. Open a terminal in the repo folder (`milfnet`) and run `claude`. Approve the two project MCP servers when asked.
2. Run `/mcp` to check that both show as connected.
3. Keep Studio and Blender open while you work.

**Claude Desktop instead of Claude Code:** go to **Settings → Developer → Edit Config** and paste the same `mcpServers` block from `.mcp.json` into `claude_desktop_config.json`. Then fully quit Claude (including from the system tray) and reopen it.

**If a server won't start:** restart Studio or Blender, then Claude. For Blender, also check that `uvx --version` works in a new terminal.
