"""Modal screens for MTCP TUI - Help, Credits, Debug, Update, Exit, Tool Output."""

from __future__ import annotations

import os
import subprocess
import sys
from typing import Optional

from textual import on, work
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import (
    Button,
    Footer,
    Header,
    Input,
    Label,
    ListItem,
    ListView,
    OptionList,
    RichLog,
    Static,
)
from textual.widgets.option_list import Option

from .tools import AppConfig, SlashCommand


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Help Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class HelpScreen(ModalScreen):
    """Shows available slash commands and navigation help."""

    BINDINGS = [
        Binding("escape", "close_help", "Close", priority=True),
        Binding("q", "close_help", "Close"),
    ]

    def __init__(self, config: AppConfig) -> None:
        super().__init__()
        self.config = config

    def action_close_help(self) -> None:
        """Close the help screen."""
        self.dismiss()

    def compose(self) -> ComposeResult:
        with Container(id="help-dialog"):
            yield Static("❓  HELP MENU", id="help-title")
            with VerticalScroll(id="help-content"):
                yield Static("💬 Available Commands", classes="help-section-title")
                yield Static("─" * 60, classes="separator")

                for cmd_name in sorted(self.config.commands.keys()):
                    cmd = self.config.commands[cmd_name]
                    yield Static(
                        f"  [cyan]/{cmd_name:<18}[/cyan] [dim]{cmd.description}[/dim]"
                    )

                yield Static("")
                yield Static("🎮 Navigation", classes="help-section-title")
                yield Static("─" * 60, classes="separator")
                yield Static("  [cyan]↑ / ↓[/cyan]      Navigate menu items")
                yield Static("  [cyan]Enter[/cyan]      Select / Run tool")
                yield Static("  [cyan]← / →[/cyan]      Navigate categories")
                yield Static("  [cyan]Escape[/cyan]     Go back / Close")
                yield Static("  [cyan]/[/cyan]          Open command palette")
                yield Static("  [cyan]W[/cyan]          Update wallpaper")
                yield Static("  [cyan]D[/cyan]          Toggle Deep Freeze")
                yield Static("  [cyan]Q / E[/cyan]      Exit application")
                yield Static("")
                yield Static(
                    "  [dim]Press [bold]ESC[/bold] to close this help menu[/dim]",
                    classes="text-center"
                )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Credits Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class CreditsScreen(ModalScreen):
    """Shows application credits and information."""

    BINDINGS = [
        Binding("escape", "close_screen", "Close", priority=True),
        Binding("q", "close_screen", "Close"),
    ]

    def __init__(self, config: AppConfig) -> None:
        super().__init__()
        self.config = config

    def action_close_screen(self) -> None:
        """Close the credits screen."""
        self.dismiss()

    def compose(self) -> ComposeResult:
        ascii_art = (
            "█▄█ ▀█▀ █▀▀ █▀█   ▀█▀ ▄▀█\n"
            "█░█ ░█░ █▄▄ █▀    ░█░ █▀█"
        )
        with Container(id="credits-dialog"):
            yield Static("⭐  CREDITS", id="credits-title")
            with VerticalScroll(id="credits-content"):
                yield Static(f"[cyan]{ascii_art}[/cyan]", classes="text-center")
                yield Static("")
                yield Static(
                    f"[cyan]MULTI-TOOL CONTROL PANEL[/cyan]",
                    classes="text-center",
                )
                yield Static(
                    f"[dim]Version {self.config.version}[/dim]",
                    classes="text-center",
                )
                yield Static("")
                yield Static("👥 Developed by", classes="credits-label")
                yield Static(
                    f"   {self.config.author}", classes="credits-value"
                )
                yield Static("")
                yield Static("🏢 Organization", classes="credits-label")
                yield Static("   Technical Assistants", classes="credits-value")
                yield Static("")
                yield Static("🔗 Repository", classes="credits-label")
                yield Static(
                    "   [link=https://github.com/TA-Softies/mtcp]https://github.com/TA-Softies/mtcp[/link]",
                    classes="credits-value",
                )
                yield Static("")
                yield Static("⚙️  Built with", classes="credits-label")
                yield Static("   Python + Textual TUI Framework", classes="credits-value")
                yield Static("   Windows 10/11 Compatible", classes="credits-value")
                yield Static("")
                yield Static("❤️  Special Thanks", classes="credits-label")
                yield Static("   SFU Technical Team", classes="credits-value")
                yield Static("   GitHub Copilot Assistant", classes="credits-value")
                yield Static("")
                yield Static(
                    "[dim]Press ESC to close[/dim]", classes="text-center"
                )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Debug Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class DebugScreen(ModalScreen):
    """Shows debug info and diagnostic options."""

    BINDINGS = [
        Binding("escape", "close_screen", "Close", priority=True),
    ]

    def __init__(self, config: AppConfig, script_root: str) -> None:
        super().__init__()
        self.config = config
        self.script_root = script_root

    def action_close_screen(self) -> None:
        """Close the debug screen."""
        self.dismiss()

    def compose(self) -> ComposeResult:
        import psutil
        proc = psutil.Process(os.getpid())

        mem_mb = round(proc.memory_info().rss / (1024 * 1024), 2)
        cpu_pct = proc.cpu_percent(interval=0.1)
        threads = proc.num_threads()
        start_time = proc.create_time()
        from datetime import datetime
        start_str = datetime.fromtimestamp(start_time).strftime("%Y-%m-%d %H:%M:%S")

        with Container(id="debug-dialog"):
            yield Static("🐛  DEBUG MENU", id="debug-title")
            with VerticalScroll(id="debug-content"):
                yield Static(f"  [bold]📊 Version:[/bold]  [cyan]v{self.config.version}[/cyan]")
                yield Static(f"  [bold]📋 Path:[/bold]     [dim]{self.script_root}[/dim]")
                yield Static("")
                yield Static("  [yellow]📊 Process Information[/yellow]")
                yield Static("  " + "─" * 50, classes="separator")
                yield Static(f"    [cyan]💻 CPU Usage:[/cyan]     {cpu_pct}%")
                yield Static(f"    [cyan]💾 Memory:[/cyan]        {mem_mb} MB")
                yield Static(f"    [cyan]🧵 Threads:[/cyan]       {threads}")
                yield Static(f"    [cyan]⏰ Start Time:[/cyan]    {start_str}")
                yield Static(f"    [cyan]🆔 Process ID:[/cyan]    {os.getpid()}")
                yield Static(f"    [cyan]🐍 Python:[/cyan]        {sys.version.split()[0]}")
                yield Static("")
                yield Static("  [yellow]🔧 Debug Actions[/yellow]")
                yield Static("  " + "─" * 50, classes="separator")
                yield Static("")
                yield Button("🔄 Check for Updates", id="debug-update", variant="primary")
                yield Button("📝 View Config", id="debug-config", variant="default")
                yield Button("📊 System Diagnostics", id="debug-sysdiag", variant="default")
                yield Button("❌ Close", id="debug-close", variant="error")

    @on(Button.Pressed, "#debug-close")
    def close_debug(self) -> None:
        self.dismiss()

    @on(Button.Pressed, "#debug-update")
    def check_update(self) -> None:
        self.app.notify("Checking for updates...", title="Update", severity="information")
        self.dismiss()
        # Trigger update check on the main app
        self.app.action_check_updates()

    @on(Button.Pressed, "#debug-config")
    def view_config(self) -> None:
        config_path = os.path.join(self.script_root, "sfu-tools", "config.json")
        if os.path.exists(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                content = f.read()
            self.app.push_screen(
                ToolOutputScreen("📝 config.json", content)
            )

    @on(Button.Pressed, "#debug-sysdiag")
    def sys_diagnostics(self) -> None:
        from .sysinfo import get_system_info
        info = get_system_info()
        diag = (
            f"Hostname:     {info.hostname_display}\n"
            f"Model:        {info.model}\n"
            f"OS:           {info.os_display}\n"
            f"Uptime:       {info.uptime}\n"
            f"RAM:          {info.ram_display}\n"
            f"Network:      {info.net_display}\n"
            f"Deep Freeze:  {info.deep_freeze}\n"
            f"Motherboard:  {info.motherboard}\n"
            f"Boot Time:    {info.boot_time}\n"
        )
        self.app.push_screen(
            ToolOutputScreen("📊 System Diagnostics", diag)
        )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tool Output Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class ToolOutputScreen(ModalScreen):
    """Displays output from a tool execution."""

    BINDINGS = [
        Binding("escape", "close_screen", "Close", priority=True),
        Binding("q", "close_screen", "Close"),
    ]

    def __init__(self, title: str, output: str) -> None:
        super().__init__()
        self.title_text = title
        self.output_text = output

    def action_close_screen(self) -> None:
        """Close the output screen."""
        self.dismiss()

    def compose(self) -> ComposeResult:
        with Container(id="output-dialog"):
            yield Static(self.title_text, id="output-title")
            yield RichLog(id="output-log", highlight=True, markup=True)
            yield Static(
                "[dim]Press ESC to close[/dim]", id="output-footer"
            )

    def on_mount(self) -> None:
        log = self.query_one("#output-log", RichLog)
        for line in self.output_text.split("\n"):
            log.write(line)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Update Notification Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class UpdateScreen(ModalScreen[bool]):
    """Shows update notification with install/skip options."""

    BINDINGS = [
        Binding("escape", "skip", "Skip", priority=True),
        Binding("u", "update", "Update"),
        Binding("enter", "skip", "Skip"),
    ]

    def __init__(
        self, current_version: str, new_version: str, download_url: str
    ) -> None:
        super().__init__()
        self.current_version = current_version
        self.new_version = new_version
        self.download_url = download_url

    def compose(self) -> ComposeResult:
        with Container(id="update-dialog"):
            yield Static(":)  UPDATE AVAILABLE", id="update-title")
            with Vertical(id="update-content"):
                yield Static(
                    "A new update is available and ready to install!"
                )
                yield Static("")
                yield Static(
                    f"  [dim]Current Version:[/dim]  {self.current_version}"
                )
                yield Static(
                    f"  [bold green]New Version:[/bold green]      {self.new_version}"
                )
                yield Static("")
                yield Static("  The update will:")
                yield Static("    [dim]• Backup your current installation[/dim]")
                yield Static("    [dim]• Download and install the new version[/dim]")
                yield Static("    [dim]• Restart the application automatically[/dim]")
                yield Static("")
                with Horizontal(id="exit-buttons"):
                    yield Button(
                        "🔄 Update", id="btn-update", variant="success"
                    )
                    yield Button(
                        "⏭️  Skip", id="btn-skip", variant="default"
                    )

    def action_skip(self) -> None:
        self.dismiss(False)

    def action_update(self) -> None:
        self.dismiss(True)

    @on(Button.Pressed, "#btn-update")
    def on_update(self) -> None:
        self.dismiss(True)

    @on(Button.Pressed, "#btn-skip")
    def on_skip(self) -> None:
        self.dismiss(False)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Exit Confirmation Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class ExitConfirmScreen(ModalScreen[bool]):
    """Confirmation dialog before exiting."""

    BINDINGS = [
        Binding("y", "confirm", "Yes"),
        Binding("n", "cancel", "No"),
        Binding("escape", "cancel", "Cancel", priority=True),
    ]

    def compose(self) -> ComposeResult:
        with Container(id="exit-dialog"):
            yield Static(
                "⚠️  Are you sure you want to exit?", id="exit-title"
            )
            with Horizontal(id="exit-buttons"):
                yield Button(
                    "Yes, Exit", id="btn-exit-yes", variant="error"
                )
                yield Button(
                    "No, Go Back", id="btn-exit-no", variant="primary"
                )

    def action_confirm(self) -> None:
        self.dismiss(True)

    def action_cancel(self) -> None:
        self.dismiss(False)

    @on(Button.Pressed, "#btn-exit-yes")
    def on_yes(self) -> None:
        self.dismiss(True)

    @on(Button.Pressed, "#btn-exit-no")
    def on_no(self) -> None:
        self.dismiss(False)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Deep Freeze Toggle Screen
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class DeepFreezeScreen(ModalScreen[bool]):
    """Toggle Deep Freeze between frozen and thawed states."""

    BINDINGS = [
        Binding("y", "confirm", "Yes"),
        Binding("n", "cancel", "No"),
        Binding("escape", "cancel", "Cancel", priority=True),
    ]

    def __init__(self, script_root: str, current_status: str = "Unknown") -> None:
        super().__init__()
        self.script_root = script_root
        self.current_status = current_status

    def compose(self) -> ComposeResult:
        # Determine action text and colors
        if self.current_status == "Not Installed":
            with Container(id="df-dialog"):
                yield Static("❄️  Deep Freeze Control", id="df-title")
                with Vertical(id="df-content"):
                    yield Static("\n  [dim]Deep Freeze is not installed on this system.[/dim]\n")
                    yield Static("  [bold]Esc[/bold] — Go Back")
            return

        if self.current_status == "FROZEN":
            status_markup = "[bold #00bcd4 on #003845] ❄️  FROZEN [/bold #00bcd4 on #003845]"
            action_text = "Thaw"
            action_desc = "This will [bold #ff4444]THAW[/bold #ff4444] Deep Freeze on next reboot."
        elif self.current_status == "THAWED":
            status_markup = "[bold #ff4444 on #3d0000] 🔥 THAWED [/bold #ff4444 on #3d0000]"
            action_text = "Freeze"
            action_desc = "This will [bold #00bcd4]FREEZE[/bold #00bcd4] Deep Freeze on next reboot."
        else:
            status_markup = f"[dim]{self.current_status}[/dim]"
            action_text = "Toggle"
            action_desc = "This will toggle the Deep Freeze state."

        with Container(id="df-dialog"):
            yield Static("❄️  Deep Freeze Control", id="df-title")
            with Vertical(id="df-content"):
                yield Static(f"\n  Current Status:  {status_markup}\n")
                yield Static(f"  {action_desc}\n")
                yield Static(
                    "  [bold]Y[/bold] — Yes, "
                    + action_text
                    + "    [bold]N[/bold] / [bold]Esc[/bold] — Cancel"
                )

    def action_confirm(self) -> None:
        if self.current_status == "Not Installed":
            self.dismiss(False)
            return

        toggle_script = os.path.join(
            self.script_root, "sfu-tools", "Toggle-DeepFreeze.ps1"
        )
        if os.path.exists(toggle_script):
            subprocess.Popen(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    toggle_script,
                ],
                creationflags=subprocess.CREATE_NEW_CONSOLE,
            )
            self.app.notify(
                "Deep Freeze toggle launched in new window.",
                title="Deep Freeze",
            )
        else:
            self.app.notify(
                "Toggle script not found!", title="Error", severity="error"
            )
        self.dismiss(True)

    def action_cancel(self) -> None:
        self.dismiss(False)

    def on_key(self, event) -> None:
        """Handle key presses - ensure ESC always works."""
        if event.key == "escape":
            event.stop()
            self.dismiss(False)
