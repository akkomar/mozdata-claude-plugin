# Mozdata Plugin for Claude Code

This plugin enables Claude Code to access Mozilla's DataHub metadata through the Model Context Protocol (MCP).

## Setup

### DataHub access

TODO: we need to add notes about DataHub access via MCP server here.

Add this to your shell profile (`~/.zshrc`, `~/.bashrc`, or `~/.bash_profile`):

```bash
export DATAHUB_API_TOKEN="your-token-here"
```
Then reload your shell:
source ~/.zshrc  # or source ~/.bashrc

2. Install the plugin
```
/plugin marketplace add akomar/mozdata-claude-plugin
/plugin install mozdata-datahub@marketplace-name
```
3. Restart Claude Code

