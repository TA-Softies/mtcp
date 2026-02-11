"""Tool execution and configuration loading for MTCP TUI."""

import json
import os
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Tool:
    """A single tool/command entry."""
    name: str
    description: str = ""
    command: str = ""
    hotkey: str = ""


@dataclass 
class Subcategory:
    """A subcategory within a category."""
    name: str
    tools: list[Tool] = field(default_factory=list)


@dataclass
class Category:
    """A top-level category of tools."""
    name: str
    description: str = ""
    subcategories: list[Subcategory] = field(default_factory=list)
    tools: list[Tool] = field(default_factory=list)

    @property
    def has_subcategories(self) -> bool:
        return len(self.subcategories) > 0


@dataclass
class SlashCommand:
    """A slash command definition."""
    name: str
    description: str = ""
    action: str = ""
    script: str = ""
    command: str = ""


@dataclass
class AppConfig:
    """Full application configuration."""
    version: str = "0.0.0"
    author: str = "Technical Assistants"
    categories: list[Category] = field(default_factory=list)
    commands: dict[str, SlashCommand] = field(default_factory=dict)
    hotkey_map: dict[str, str] = field(default_factory=dict)


def load_config(config_path: str) -> AppConfig:
    """Load and parse the config.json file."""
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    config = AppConfig()

    # Meta
    meta = data.get("meta", {})
    config.version = meta.get("version", "0.0.0")
    config.author = meta.get("author", "Technical Assistants")

    # Categories
    for cat_data in data.get("categories", []):
        category = Category(
            name=cat_data.get("name", "Unknown"),
            description=cat_data.get("description", ""),
        )

        # Direct tools
        for tool_data in cat_data.get("tools", []):
            tool = Tool(
                name=tool_data.get("name", "Unknown"),
                description=tool_data.get("description", ""),
                command=tool_data.get("command", ""),
                hotkey=tool_data.get("hotkey", ""),
            )
            category.tools.append(tool)
            if tool.hotkey:
                config.hotkey_map[tool.hotkey.upper()] = tool.command

        # Subcategories
        for subcat_data in cat_data.get("subcategories", []):
            subcat = Subcategory(name=subcat_data.get("name", "Unknown"))
            for tool_data in subcat_data.get("tools", []):
                tool = Tool(
                    name=tool_data.get("name", "Unknown"),
                    description=tool_data.get("description", ""),
                    command=tool_data.get("command", ""),
                    hotkey=tool_data.get("hotkey", ""),
                )
                subcat.tools.append(tool)
                if tool.hotkey:
                    config.hotkey_map[tool.hotkey.upper()] = tool.command
            category.subcategories.append(subcat)

        config.categories.append(category)

    # Slash commands
    for cmd_name, cmd_data in data.get("commands", {}).items():
        config.commands[cmd_name] = SlashCommand(
            name=cmd_name,
            description=cmd_data.get("description", ""),
            action=cmd_data.get("action", ""),
            script=cmd_data.get("script", ""),
            command=cmd_data.get("command", ""),
        )

    return config


def resolve_command(command: str, script_root: str) -> str:
    """Replace $PSScriptRoot with actual path in command strings."""
    return command.replace("$PSScriptRoot", script_root)


def run_tool(command: str, script_root: str) -> subprocess.CompletedProcess:
    """Execute a tool command and return the result."""
    resolved = resolve_command(command, script_root)

    # Determine execution method
    if resolved.endswith(".msc"):
        # MMC snap-ins
        return subprocess.run(
            ["mmc", resolved],
            capture_output=False, shell=True
        )
    elif resolved.endswith(".exe"):
        # Direct executables
        return subprocess.run(
            resolved, capture_output=False, shell=True
        )
    elif "powershell" in resolved.lower() or resolved.endswith(".ps1"):
        # PowerShell scripts
        return subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", resolved],
            capture_output=True, text=True, timeout=300
        )
    else:
        # Generic command (cmd)
        return subprocess.run(
            resolved, capture_output=True, text=True, shell=True, timeout=300
        )


def check_for_updates(current_version: str, script_root: str) -> Optional[dict]:
    """Check for updates from GitHub."""
    check_script = os.path.join(script_root, "sfu-tools", "Check-Update.ps1")
    if not os.path.exists(check_script):
        return None

    try:
        result = subprocess.run(
            [
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", check_script,
                "-CurrentVersion", current_version,
                "-Silent"
            ],
            capture_output=True, text=True, timeout=10
        )
        # Parse PowerShell output - look for version info
        output = result.stdout.strip()
        if not output:
            return None

        # The script returns PSCustomObject; we need to parse it
        # Use a wrapper to get JSON output
        json_cmd = (
            f"$r = & '{check_script}' -CurrentVersion '{current_version}' -Silent; "
            "if ($r) { $r | ConvertTo-Json -Compress } else { 'null' }"
        )
        result2 = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", json_cmd],
            capture_output=True, text=True, timeout=15
        )
        json_out = result2.stdout.strip()
        if json_out and json_out != "null":
            return json.loads(json_out)
    except Exception:
        pass

    return None


def install_update(download_url: str, current_version: str, new_version: str, script_root: str) -> bool:
    """Run the install-update script."""
    install_script = os.path.join(script_root, "sfu-tools", "Install-Update.ps1")
    if not os.path.exists(install_script):
        return False

    try:
        subprocess.Popen(
            [
                "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                "-File", install_script,
                "-DownloadUrl", download_url,
                "-CurrentVersion", current_version,
                "-NewVersion", new_version,
            ],
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        return True
    except Exception:
        return False
