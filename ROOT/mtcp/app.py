"""MTCP - Multi-Tool Control Panel - Main Textual TUI Application."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

from textual import on, work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical, VerticalScroll
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual.widgets import (
    Collapsible,
    Footer,
    Input,
    Label,
    LoadingIndicator,
    OptionList,
    ProgressBar,
    RichLog,
    Static,
)
from textual.widgets.option_list import Option

from .screens import (
    CreditsScreen,
    DeepFreezeScreen,
    DebugScreen,
    ExitConfirmScreen,
    HelpScreen,
    ToolOutputScreen,
    UpdateScreen,
)
from .sysinfo import SystemInfo, get_system_info, LiveMetrics, get_live_metrics
from .tools import (
    AppConfig,
    Category,
    Subcategory,
    Tool,
    check_for_updates,
    install_update,
    load_config,
    resolve_command,
    run_tool,
)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Determine paths (PyInstaller-aware)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _get_bundle_dir() -> Path:
    """Get the base directory for bundled resources (PyInstaller or source)."""
    if getattr(sys, 'frozen', False):
        # Running as compiled exe - sys._MEIPASS is the temp extraction folder
        return Path(sys._MEIPASS)
    else:
        # Running from source - mtcp package directory
        return Path(__file__).resolve().parent


def _find_script_root() -> str:
    """Find the ROOT directory (parent of mtcp package or exe location)."""
    # When frozen, config is bundled inside the exe but we also need
    # to check the exe's directory for external config
    if getattr(sys, 'frozen', False):
        # First check bundled location
        bundle_dir = Path(sys._MEIPASS)
        config = bundle_dir / "sfu-tools" / "config.json"
        if config.exists():
            return str(bundle_dir)
        
        # Then check exe's directory
        exe_dir = Path(sys.executable).resolve().parent
        config = exe_dir / "sfu-tools" / "config.json"
        if config.exists():
            return str(exe_dir)
        
        # Fallback to bundled
        return str(bundle_dir)
    
    # Running from source
    # Try relative to this file
    pkg_dir = Path(__file__).resolve().parent          # mtcp/
    root_dir = pkg_dir.parent                          # ROOT/
    config = root_dir / "sfu-tools" / "config.json"
    if config.exists():
        return str(root_dir)

    # Try CWD
    cwd = Path.cwd()
    config = cwd / "sfu-tools" / "config.json"
    if config.exists():
        return str(cwd)

    # Fallback
    return str(root_dir)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ASCII Banner Widget
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BANNER_ART = """\
█▄█ ▀█▀ █▀▀ █▀█   ▀█▀ ▄▀█
█░█ ░█░ █▄▄ █▀    ░█░ █▀█\
"""


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Application
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


class MTCPApp(App):
    """Multi-Tool Control Panel - Technical Assistants."""

    TITLE = "MTCP - Multi-Tool Control Panel"
    CSS_PATH = "theme.tcss"

    BINDINGS = [
        Binding("q", "request_exit", "Exit", priority=True),
        Binding("e", "request_exit", "Exit", show=False),
        Binding("w", "wallpaper", "Wallpaper", priority=True),
        Binding("d", "deep_freeze", "Deep Freeze", priority=True),
        Binding("f1", "help", "Help"),
        Binding("escape", "go_back", "Back", priority=True),
        Binding("left", "go_back", "Back", show=False),
        Binding("right", "enter_selection", "Enter", show=False),
    ]

    # Navigation state
    current_view: reactive[str] = reactive("categories")
    current_category: Optional[Category] = None
    current_subcategory: Optional[Subcategory] = None
    command_mode: reactive[bool] = reactive(False)

    def __init__(self) -> None:
        super().__init__()
        self.script_root = _find_script_root()
        self.config: Optional[AppConfig] = None
        self.sys_info: Optional[SystemInfo] = None

    def compose(self) -> ComposeResult:
        with VerticalScroll():
            # Banner
            with Container(id="banner"):
                yield Static(BANNER_ART, id="banner-art")
                yield Static("", id="banner-title")
                yield Static("Technical Assistants", id="banner-subtitle")

            # System info summary (always visible)
            with Container(id="sysinfo-summary"):
                yield Static("[dim]⏳ Loading...[/dim]", id="sysinfo-summary-content")
            
            # Expanded system info (collapsible)
            with Collapsible(title="📋 More Details", collapsed=True, id="sysinfo-collapsible"):
                yield Static("", id="sysinfo-content")

            # Live monitoring panel (compact single row)
            with Container(id="monitor-panel"):
                with Horizontal(id="monitor-row"):
                    yield Static("CPU", classes="mon-label")
                    yield ProgressBar(total=100, show_eta=False, id="cpu-bar")
                    yield Static("0%", id="cpu-pct", classes="mon-val")
                    yield Static("│", classes="mon-sep")
                    yield Static("RAM", classes="mon-label")
                    yield ProgressBar(total=100, show_eta=False, id="mem-bar")
                    yield Static("0/0G", id="mem-pct", classes="mon-val")
                    yield Static("│", classes="mon-sep")
                    yield Static("DISK", classes="mon-label")
                    yield ProgressBar(total=100, show_eta=False, id="disk-bar")
                    yield Static("0/0G", id="disk-pct", classes="mon-val")
                    yield Static("│", classes="mon-sep")
                    yield Static("NET", classes="mon-label")
                    yield Static("● OFF", id="net-status", classes="mon-val")
                    yield Static("↑0↓0", id="net-rate", classes="mon-val-dim")

            # Breadcrumb / navigation bar
            with Container(id="breadcrumb-bar"):
                yield Static("📍 Main Menu", id="breadcrumb-text")
                yield Static("", id="breadcrumb-desc")

            # Main menu
            with Container(id="menu-container"):
                yield OptionList(id="tool-list")

        # Command input (hidden by default)
        with Container(id="command-input-container"):
            with Horizontal():
                yield Static("/ ", id="command-label")
                yield Input(
                    placeholder="Type a command (e.g. help, credits, debug)...",
                    id="command-input",
                )

        # Hotkey footer
        with Horizontal(id="hotkey-bar"):
            yield Static(
                "[bold]↑↓[/bold] Nav  "
                "[bold]Enter[/bold] Select  "
                "[bold]←[/bold] Back  "
                "[bold cyan]/[/bold cyan] Command  "
                "[bold]W[/bold] Wallpaper  "
                "[bold]D[/bold] DF  "
                "[bold red]Q[/bold red] Exit",
                id="footer-nav",
            )
            yield Static("", id="footer-version")

    def on_mount(self) -> None:
        """Initialize the app on mount."""
        self.load_app_config()
        self.refresh_sysinfo()
        self.check_updates_on_start()
        # Focus the option list so up/down navigation works immediately
        self.set_timer(0.3, self._focus_menu)
        # Start live metrics monitoring
        self.set_interval(2.0, self._update_live_metrics)
        # Initial metrics update
        self.set_timer(0.5, self._update_live_metrics)

    def _focus_menu(self) -> None:
        """Focus the tool list for keyboard navigation."""
        try:
            opt_list = self.query_one("#tool-list", OptionList)
            opt_list.focus()
        except Exception:
            pass

    @work(thread=True)
    def load_app_config(self) -> None:
        """Load configuration from config.json."""
        config_path = os.path.join(self.script_root, "sfu-tools", "config.json")
        try:
            self.config = load_config(config_path)
            self.call_from_thread(self._on_config_loaded)
        except FileNotFoundError:
            self.call_from_thread(
                self.notify,
                f"Config not found: {config_path}",
                title="Error",
                severity="error",
            )
        except Exception as e:
            self.call_from_thread(
                self.notify,
                f"Config error: {e}",
                title="Error",
                severity="error",
            )

    def _on_config_loaded(self) -> None:
        """Called after config is successfully loaded."""
        if not self.config:
            return

        # Update banner title
        banner_title = self.query_one("#banner-title", Static)
        banner_title.update(
            f"MULTI-TOOL CONTROL PANEL v{self.config.version}"
        )

        # Update footer
        footer_ver = self.query_one("#footer-version", Static)
        footer_ver.update(
            f"[dim]v{self.config.version} │ {self.config.author}[/dim]"
        )

        # Update window title
        self.title = f"MTCP v{self.config.version} - Multi-Tool Control Panel"
        self.sub_title = "Technical Assistants"

        # Populate menu
        self._populate_menu()

    @work(thread=True)
    def refresh_sysinfo(self) -> None:
        """Refresh system information in background."""
        info = get_system_info()
        self.sys_info = info
        self.call_from_thread(self._update_sysinfo_display, info)

    def _update_sysinfo_display(self, info: SystemInfo) -> None:
        """Update the system info panel widgets."""
        # Net status
        if info.net_status == "Connected":
            net_icon = "[#4caf50]🌐[/#4caf50]"
            net_label = "[#4caf50]ONLINE[/#4caf50]"
        else:
            net_icon = "[#ff4444]🌐[/#ff4444]"
            net_label = "[#ff4444]OFFLINE[/#ff4444]"

        # Deep Freeze
        if info.deep_freeze == "FROZEN":
            df_icon = "[#00bcd4]❄️[/#00bcd4]"
            df_badge = "[bold #00bcd4]FROZEN[/bold #00bcd4]"
        elif info.deep_freeze == "THAWED":
            df_icon = "[#ff4444]🔥[/#ff4444]"
            df_badge = "[bold #ff4444]THAWED[/bold #ff4444]"
        else:
            df_icon = "🔒"
            df_badge = f"[dim]{info.deep_freeze}[/dim]"

        # Summary panel (always visible) - shows key info
        summary = (
            f"  [#555]Host:[/#555] [bold]{info.hostname_display}[/bold]  │  "
            f"[#555]User:[/#555] {info.username}  │  "
            f"{df_icon} {df_badge}\n"
            f"  [#555]CPU:[/#555]  {info.cpu_display}\n"
            f"  [#555]RAM:[/#555]  {info.ram_display}  │  "
            f"[#555]Disk:[/#555] {info.disk_display}"
        )
        try:
            self.query_one("#sysinfo-summary-content", Static).update(summary)
        except Exception:
            pass

        # Detailed content (in collapsible - extra info)
        content = (
            f"  [#00d4ff bold]💻 SYSTEM[/#00d4ff bold]\n"
            f"  [#555]Model:[/#555]    {info.model}\n"
            f"  [#555]OS:[/#555]       {info.os_display}\n"
            f"\n"
            f"  [#00d4ff bold]🔧 HARDWARE[/#00d4ff bold]\n"
            f"  [#555]GPU:[/#555]      {info.gpu_name}\n"
            f"  [#555]Mobo:[/#555]     {info.motherboard}\n"
            f"  [#555]BIOS:[/#555]     {info.bios_version}\n"
            f"\n"
            f"  [#00d4ff bold]⏱ UPTIME[/#00d4ff bold]\n"
            f"  [#555]Up:[/#555]       {info.uptime}\n"
            f"  [#555]Boot:[/#555]     {info.boot_time}\n"
            f"\n"
            f"  [#00d4ff bold]{net_icon} NETWORK[/#00d4ff bold]\n"
            f"  [#555]Status:[/#555]   {net_label}\n"
            f"  [#555]Type:[/#555]     {info.net_type}\n"
            f"  [#555]IP:[/#555]       {info.net_ip}"
        )
        self.query_one("#sysinfo-content", Static).update(content)

    def _update_live_metrics(self) -> None:
        """Update live monitoring metrics."""
        try:
            metrics = get_live_metrics()
            
            # Update CPU
            cpu_bar = self.query_one("#cpu-bar", ProgressBar)
            cpu_bar.progress = metrics.cpu_percent
            self.query_one("#cpu-pct", Static).update(f"{metrics.cpu_percent:.0f}%")
            
            # Update Memory
            mem_bar = self.query_one("#mem-bar", ProgressBar)
            mem_bar.progress = metrics.memory_percent
            self.query_one("#mem-pct", Static).update(
                f"{metrics.memory_used_gb:.0f}/{metrics.memory_total_gb:.0f}G"
            )
            
            # Update Disk
            disk_bar = self.query_one("#disk-bar", ProgressBar)
            disk_bar.progress = metrics.disk_percent
            self.query_one("#disk-pct", Static).update(
                f"{metrics.disk_used_gb:.0f}/{metrics.disk_total_gb:.0f}G"
            )
            
            # Update Network
            if metrics.net_online:
                self.query_one("#net-status", Static).update("[#4caf50]● ON[/#4caf50]")
            else:
                self.query_one("#net-status", Static).update("[#ff4444]● OFF[/#ff4444]")
            self.query_one("#net-rate", Static).update(
                f"↑{metrics.net_sent_rate:.0f}↓{metrics.net_recv_rate:.0f}"
            )
        except Exception:
            pass

    @work(thread=True)
    def check_updates_on_start(self) -> None:
        """Check for updates on startup."""
        if not self.config:
            # Config not loaded yet, retry after a delay
            import time
            time.sleep(2)
            if not self.config:
                return

        update_info = check_for_updates(self.config.version, self.script_root)
        if update_info and update_info.get("UpdateAvailable"):
            self.call_from_thread(
                self._show_update_notification, update_info
            )

    def _show_update_notification(self, update_info: dict) -> None:
        """Show the update notification screen."""
        self.push_screen(
            UpdateScreen(
                current_version=update_info.get("CurrentVersion", "?"),
                new_version=update_info.get("RemoteVersion", "?"),
                download_url=update_info.get("DownloadUrl", ""),
            ),
            callback=self._on_update_decision,
        )

    def _on_update_decision(self, should_update: bool) -> None:
        """Handle user's update decision."""
        if should_update and self.config:
            update_info = check_for_updates(self.config.version, self.script_root)
            if update_info:
                success = install_update(
                    update_info.get("DownloadUrl", ""),
                    update_info.get("CurrentVersion", ""),
                    update_info.get("RemoteVersion", ""),
                    self.script_root,
                )
                if success:
                    self.notify(
                        "Update launched. Application will restart.",
                        title="Update",
                        severity="information",
                    )
                    self.exit()
                else:
                    self.notify(
                        "Update script not found.",
                        title="Error",
                        severity="error",
                    )

    # ── Menu Population ──────────────────────────────────────

    def _populate_menu(self) -> None:
        """Populate the OptionList based on current navigation state."""
        if not self.config:
            return

        opt_list = self.query_one("#tool-list", OptionList)
        opt_list.clear_options()

        breadcrumb = "📍 Main Menu"
        desc = ""

        if self.current_view == "categories":
            breadcrumb = "📍 Main Menu"
            desc = "Select a category to continue"
            for cat in self.config.categories:
                icon = "📦" if cat.has_subcategories else "�"
                opt_list.add_option(
                    Option(f"{icon}  {cat.name}", id=f"cat:{cat.name}")
                )

        elif self.current_view == "subcategories" and self.current_category:
            breadcrumb = f"📍 Main Menu › {self.current_category.name}"
            desc = self.current_category.description
            for subcat in self.current_category.subcategories:
                opt_list.add_option(
                    Option(f"📂  {subcat.name}", id=f"sub:{subcat.name}")
                )

        elif self.current_view == "tools":
            tools = []
            if self.current_subcategory:
                breadcrumb = (
                    f"📍 Main Menu › {self.current_category.name} › "
                    f"{self.current_subcategory.name}"
                )
                tools = self.current_subcategory.tools
            elif self.current_category:
                breadcrumb = f"📍 Main Menu › {self.current_category.name}"
                desc = self.current_category.description
                tools = self.current_category.tools

            for tool in tools:
                hotkey_badge = f" [{tool.hotkey}]" if tool.hotkey else ""
                opt_list.add_option(
                    Option(
                        f"🔧  {tool.name}{hotkey_badge}",
                        id=f"tool:{tool.name}",
                    )
                )

        # Update breadcrumb
        self.query_one("#breadcrumb-text", Static).update(breadcrumb)
        self.query_one("#breadcrumb-desc", Static).update(
            f"[dim italic]{desc}[/dim italic]" if desc else ""
        )

        # Auto highlight first item
        if opt_list.option_count > 0:
            opt_list.highlighted = 0
            opt_list.focus()

    def _update_tool_description(self) -> None:
        """Update the breadcrumb description based on highlighted tool."""
        if self.current_view != "tools":
            return

        opt_list = self.query_one("#tool-list", OptionList)
        if opt_list.highlighted is None:
            return

        tools = []
        if self.current_subcategory:
            tools = self.current_subcategory.tools
        elif self.current_category:
            tools = self.current_category.tools

        idx = opt_list.highlighted
        if 0 <= idx < len(tools):
            desc = tools[idx].description
            self.query_one("#breadcrumb-desc", Static).update(
                f"[dim italic]{desc}[/dim italic]" if desc else ""
            )

    # ── Event Handlers ───────────────────────────────────────

    @on(OptionList.OptionSelected, "#tool-list")
    def on_option_selected(self, event: OptionList.OptionSelected) -> None:
        """Handle menu item selection (Enter key)."""
        option_id = str(event.option_id)
        self._handle_selection(option_id)

    @on(OptionList.OptionHighlighted, "#tool-list")
    def on_option_highlighted(
        self, event: OptionList.OptionHighlighted
    ) -> None:
        """Update description when navigation changes."""
        self._update_tool_description()

    def _handle_selection(self, option_id: str) -> None:
        """Process a menu selection."""
        if not self.config:
            return

        if option_id.startswith("cat:"):
            cat_name = option_id[4:]
            for cat in self.config.categories:
                if cat.name == cat_name:
                    self.current_category = cat
                    if cat.has_subcategories:
                        self.current_view = "subcategories"
                    else:
                        self.current_view = "tools"
                    self._populate_menu()
                    return

        elif option_id.startswith("sub:"):
            sub_name = option_id[4:]
            if self.current_category:
                for sub in self.current_category.subcategories:
                    if sub.name == sub_name:
                        self.current_subcategory = sub
                        self.current_view = "tools"
                        self._populate_menu()
                        return

        elif option_id.startswith("tool:"):
            tool_name = option_id[5:]
            tools = []
            if self.current_subcategory:
                tools = self.current_subcategory.tools
            elif self.current_category:
                tools = self.current_category.tools

            for tool in tools:
                if tool.name == tool_name:
                    self._execute_tool(tool)
                    return

    @work(thread=True)
    def _execute_tool(self, tool: Tool) -> None:
        """Execute a tool command in background."""
        self.call_from_thread(
            self.notify,
            f"Running: {tool.name}...",
            title="Executing",
            severity="information",
        )

        command = resolve_command(tool.command, self.script_root)

        # For GUI tools (msc, exe launchers), just open them
        gui_extensions = [".msc", ".exe"]
        is_gui = any(command.strip().lower().endswith(ext) for ext in gui_extensions)
        # Also check for simple exe names without path
        is_gui = is_gui or command.strip().lower() in [
            "taskmgr.exe", "msinfo32.exe", "dfrgui.exe", "cleanmgr.exe",
            "devmgmt.msc", "eventvwr.msc", "services.msc", "diskmgmt.msc",
            "mdsched.exe",
        ]

        if is_gui:
            try:
                subprocess.Popen(
                    command,
                    shell=True,
                    creationflags=subprocess.CREATE_NEW_CONSOLE
                    if "powershell" in command.lower()
                    else 0,
                )
                self.call_from_thread(
                    self.notify,
                    f"{tool.name} launched.",
                    title="Done",
                    severity="information",
                )
            except Exception as e:
                self.call_from_thread(
                    self.notify,
                    f"Error: {e}",
                    title="Failed",
                    severity="error",
                )
            return

        # For console tools, capture output
        try:
            # PowerShell scripts or commands that need a console
            if "powershell" in command.lower() or "-File" in command:
                proc = subprocess.Popen(
                    command,
                    shell=True,
                    creationflags=subprocess.CREATE_NEW_CONSOLE,
                )
                proc.wait()
                self.call_from_thread(
                    self.notify,
                    f"{tool.name} completed.",
                    title="Done",
                    severity="information",
                )
            else:
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300,
                )
                output = result.stdout + result.stderr
                if output.strip():
                    self.call_from_thread(
                        self.push_screen,
                        ToolOutputScreen(f"📋 {tool.name}", output),
                    )
                else:
                    self.call_from_thread(
                        self.notify,
                        f"{tool.name} completed.",
                        title="Done",
                        severity="information",
                    )

        except subprocess.TimeoutExpired:
            self.call_from_thread(
                self.notify,
                f"{tool.name} timed out.",
                title="Timeout",
                severity="warning",
            )
        except Exception as e:
            self.call_from_thread(
                self.notify,
                f"Error: {e}",
                title="Failed",
                severity="error",
            )

    # ── Actions ──────────────────────────────────────────────

    def action_go_back(self) -> None:
        """Navigate back in the menu hierarchy."""
        if self.command_mode:
            self._hide_command_input()
            return

        if self.current_view == "tools":
            if self.current_subcategory:
                self.current_subcategory = None
                self.current_view = "subcategories"
            else:
                self.current_category = None
                self.current_view = "categories"
            self._populate_menu()

        elif self.current_view == "subcategories":
            self.current_category = None
            self.current_view = "categories"
            self._populate_menu()

        # At categories level, do nothing (don't exit)

    def action_enter_selection(self) -> None:
        """Enter the currently highlighted selection (right arrow)."""
        opt_list = self.query_one("#tool-list", OptionList)
        if opt_list.highlighted is not None and opt_list.option_count > 0:
            option = opt_list.get_option_at_index(opt_list.highlighted)
            self._handle_selection(str(option.id))

    def action_request_exit(self) -> None:
        """Show exit confirmation."""
        self.push_screen(ExitConfirmScreen(), callback=self._on_exit_decision)

    def _on_exit_decision(self, should_exit: bool) -> None:
        if should_exit:
            self.exit()

    def action_wallpaper(self) -> None:
        """Run the wallpaper update script."""
        if not self.config:
            return

        # Look for wallpaper hotkey in config
        wallpaper_cmd = self.config.hotkey_map.get("W", "")
        if wallpaper_cmd:
            resolved = resolve_command(wallpaper_cmd, self.script_root)
            subprocess.Popen(
                resolved,
                shell=True,
                creationflags=subprocess.CREATE_NEW_CONSOLE,
            )
            self.notify("Wallpaper script launched.", title="Wallpaper")
        else:
            # Try direct script path
            script_path = os.path.join(
                self.script_root, "sfu-tools", "Set-Lockscreen.ps1"
            )
            if os.path.exists(script_path):
                subprocess.Popen(
                    [
                        "powershell",
                        "-NoProfile",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-File",
                        script_path,
                    ],
                    creationflags=subprocess.CREATE_NEW_CONSOLE,
                )
                self.notify("Wallpaper script launched.", title="Wallpaper")
            else:
                self.notify(
                    "Wallpaper script not found.",
                    title="Error",
                    severity="error",
                )

    def action_deep_freeze(self) -> None:
        """Toggle Deep Freeze."""
        toggle_script = os.path.join(
            self.script_root, "sfu-tools", "Toggle-DeepFreeze.ps1"
        )
        if os.path.exists(toggle_script):
            # Get current DF status from cached sysinfo
            df_status = "Unknown"
            if self.sys_info:
                df_status = self.sys_info.deep_freeze
            self.push_screen(
                DeepFreezeScreen(self.script_root, df_status),
                callback=self._on_df_done,
            )
        else:
            self.notify(
                "Deep Freeze toggle script not found.",
                title="Error",
                severity="error",
            )

    def _on_df_done(self, result) -> None:
        """Refresh sysinfo after Deep Freeze toggle."""
        if result:
            self.refresh_sysinfo()

    def action_help(self) -> None:
        """Show help screen."""
        if self.config:
            self.push_screen(HelpScreen(self.config))

    def on_key(self, event) -> None:
        """Intercept / key before OptionList consumes it."""
        if event.character == "/" and not self.command_mode:
            event.prevent_default()
            event.stop()
            self._show_command_input()

    def action_command_palette(self) -> None:
        """Show the command input."""
        self._show_command_input()

    def action_check_updates(self) -> None:
        """Manually check for updates."""
        self.check_updates_on_start()

    # ── Command Input ────────────────────────────────────────

    def _show_command_input(self) -> None:
        """Show the command input bar."""
        container = self.query_one("#command-input-container")
        container.styles.display = "block"
        self.command_mode = True
        inp = self.query_one("#command-input", Input)
        inp.value = ""
        self.set_timer(0.1, lambda: inp.focus())

    def _hide_command_input(self) -> None:
        """Hide the command input bar."""
        container = self.query_one("#command-input-container")
        container.styles.display = "none"
        self.command_mode = False
        self.set_timer(0.1, self._focus_menu)

    @on(Input.Submitted, "#command-input")
    def on_command_submitted(self, event: Input.Submitted) -> None:
        """Handle slash command submission."""
        self._hide_command_input()
        command_text = event.value.strip().lstrip("/")

        if not command_text or not self.config:
            return

        self._execute_slash_command(command_text)

    def _execute_slash_command(self, command_name: str) -> None:
        """Execute a slash command."""
        if not self.config:
            return

        cmd = self.config.commands.get(command_name)
        if not cmd:
            self.notify(
                f"Unknown command: /{command_name}\nType /help for available commands.",
                title="Command Not Found",
                severity="warning",
            )
            return

        action = cmd.action

        if action == "show-help":
            self.push_screen(HelpScreen(self.config))
        elif action == "show-credits":
            self.push_screen(CreditsScreen(self.config))
        elif action == "show-debug":
            self.push_screen(DebugScreen(self.config, self.script_root))
        elif action == "show-version":
            self.notify(
                f"v{self.config.version}", title="Version", severity="information"
            )
        elif action == "check-update":
            self.notify("Checking for updates...", title="Update")
            self.check_updates_on_start()
        elif action == "run-script":
            script_path = resolve_command(cmd.script, self.script_root)
            if os.path.exists(script_path):
                subprocess.Popen(
                    [
                        "powershell",
                        "-NoProfile",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-File",
                        script_path,
                    ],
                    creationflags=subprocess.CREATE_NEW_CONSOLE,
                )
                self.notify(f"Script launched: {command_name}", title="Running")
            else:
                self.notify(
                    f"Script not found: {script_path}",
                    title="Error",
                    severity="error",
                )
        elif action == "run-command":
            subprocess.Popen(
                cmd.command,
                shell=True,
                creationflags=subprocess.CREATE_NEW_CONSOLE,
            )
            self.notify(f"Launched: {command_name}", title="Running")
        elif action == "exit":
            self.action_request_exit()
        else:
            self.notify(
                f"Unknown action: {action}",
                title="Error",
                severity="error",
            )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Entry point
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _set_console_size(width: int = 100, height: int = 42):
    """Set Windows console window size for optimal TUI display."""
    if sys.platform != "win32":
        return
    
    try:
        import ctypes
        from ctypes import wintypes
        
        # Get handle to console
        kernel32 = ctypes.windll.kernel32
        STD_OUTPUT_HANDLE = -11
        handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
        
        # Define SMALL_RECT and COORD structures
        class COORD(ctypes.Structure):
            _fields_ = [("X", wintypes.SHORT), ("Y", wintypes.SHORT)]
        
        class SMALL_RECT(ctypes.Structure):
            _fields_ = [
                ("Left", wintypes.SHORT),
                ("Top", wintypes.SHORT),
                ("Right", wintypes.SHORT),
                ("Bottom", wintypes.SHORT),
            ]
        
        # Set buffer size first (must be >= window size)
        buffer_size = COORD(width, height + 100)  # Extra buffer for scrollback
        kernel32.SetConsoleScreenBufferSize(handle, buffer_size)
        
        # Set window size
        window_rect = SMALL_RECT(0, 0, width - 1, height - 1)
        kernel32.SetConsoleWindowInfo(handle, True, ctypes.byref(window_rect))
        
        # Set buffer again to exact window size (removes extra scrollback)
        buffer_size = COORD(width, height)
        kernel32.SetConsoleScreenBufferSize(handle, buffer_size)
        
    except Exception:
        pass  # Fail silently if console resize doesn't work


def main():
    """Entry point for the MTCP application."""
    # Set optimal console size for TUI
    _set_console_size(100, 42)
    
    app = MTCPApp()
    app.run()


if __name__ == "__main__":
    main()
