"""System information gathering for MTCP TUI."""

import os
import platform
import socket
import subprocess
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class SystemInfo:
    """Container for system information displayed in the header."""
    hostname: str = "Unknown"
    domain: str = ""
    model: str = "Unknown"
    os_name: str = "Unknown"
    os_build: str = ""
    boot_time: str = ""
    uptime: str = ""
    motherboard: str = "Unknown"
    ram_gb: float = 0.0
    net_type: str = "Unknown"
    net_ip: str = "No IP"
    net_status: str = "Disconnected"
    deep_freeze: str = "Not Installed"
    df_color: str = "grey"
    # Extended info
    cpu_name: str = "Unknown"
    cpu_cores: int = 0
    cpu_threads: int = 0
    gpu_name: str = "Unknown"
    disk_total_gb: float = 0.0
    disk_free_gb: float = 0.0
    username: str = "Unknown"
    bios_version: str = "Unknown"

    @property
    def hostname_display(self) -> str:
        if self.domain and self.domain.upper() != "WORKGROUP":
            return f"{self.hostname} ({self.domain})"
        return self.hostname

    @property
    def os_display(self) -> str:
        if self.os_build:
            return f"{self.os_name} ({self.os_build})"
        return self.os_name

    @property
    def ram_display(self) -> str:
        return f"{self.ram_gb} GB"

    @property
    def net_display(self) -> str:
        return f"{self.net_type} ({self.net_ip}) - {self.net_status}"

    @property
    def cpu_display(self) -> str:
        if self.cpu_cores and self.cpu_threads:
            return f"{self.cpu_name} ({self.cpu_cores}C/{self.cpu_threads}T)"
        return self.cpu_name

    @property
    def disk_display(self) -> str:
        if self.disk_total_gb > 0:
            used = self.disk_total_gb - self.disk_free_gb
            return f"{used:.0f}/{self.disk_total_gb:.0f} GB used ({self.disk_free_gb:.0f} GB free)"
        return "Unknown"


def get_system_info(df_path: str = r"C:\Windows\SysWOW64\DFC.exe") -> SystemInfo:
    """Gather system information using WMI and other Windows APIs."""
    info = SystemInfo()
    
    # Get current username
    info.username = os.environ.get("USERNAME", "Unknown")

    try:
        import pythoncom
        import wmi

        # Initialize COM for this thread (worker threads need their own apartment)
        pythoncom.CoInitialize()
        try:
            c = wmi.WMI()

            # Computer system
            for cs in c.Win32_ComputerSystem():
                info.hostname = os.environ.get("COMPUTERNAME", cs.Name)
                info.domain = cs.Domain or ""
                info.model = f"{cs.Manufacturer} {cs.Model}".strip()
                info.ram_gb = round(int(cs.TotalPhysicalMemory) / (1024**3), 1)

            # OS
            for os_info in c.Win32_OperatingSystem():
                info.os_name = os_info.Caption.strip()
                info.os_build = os_info.BuildNumber
                boot_dt = _parse_wmi_datetime(os_info.LastBootUpTime)
                if boot_dt:
                    info.boot_time = boot_dt.strftime("%Y-%m-%d %H:%M:%S")
                    delta = datetime.now() - boot_dt
                    days = delta.days
                    hours, remainder = divmod(delta.seconds, 3600)
                    minutes = remainder // 60
                    info.uptime = f"{days}d {hours}h {minutes}m"

            # Motherboard
            for board in c.Win32_BaseBoard():
                sn = board.SerialNumber or "N/A"
                info.motherboard = f"{board.Product} (S/N: {sn})"
            
            # CPU
            for cpu in c.Win32_Processor():
                name = cpu.Name.strip()
                # Shorten common names
                name = name.replace("Intel(R) Core(TM) ", "Intel ")
                name = name.replace("AMD Ryzen ", "Ryzen ")
                name = name.replace(" CPU", "")
                name = name.replace(" Processor", "")
                name = name.replace("  ", " ")
                info.cpu_name = name[:35] if name else "Unknown"
                info.cpu_cores = cpu.NumberOfCores or 0
                info.cpu_threads = cpu.NumberOfLogicalProcessors or 0
                break  # Only first CPU
            
            # GPU
            for gpu in c.Win32_VideoController():
                name = gpu.Name or "Unknown"
                # Shorten common names
                name = name.replace("NVIDIA ", "")
                name = name.replace("AMD ", "")
                name = name.replace("Intel(R) ", "Intel ")
                name = name.replace("Graphics", "").strip()
                info.gpu_name = name[:35] if name else "Unknown"
                break  # Only first GPU
            
            # BIOS
            for bios in c.Win32_BIOS():
                info.bios_version = bios.SMBIOSBIOSVersion or "Unknown"
                break

            # Explicitly release COM objects before CoUninitialize
            del c
        finally:
            pythoncom.CoUninitialize()

    except ImportError:
        # WMI not available, use fallback
        info.hostname = os.environ.get("COMPUTERNAME", platform.node())
        info.os_name = platform.platform()
        info.ram_gb = _get_ram_fallback()
    
    # Disk info via psutil (faster than WMI)
    try:
        import psutil
        disk = psutil.disk_usage("C:\\")
        info.disk_total_gb = round(disk.total / (1024**3), 1)
        info.disk_free_gb = round(disk.free / (1024**3), 1)
    except Exception:
        pass

    # Network
    _populate_network(info)

    # Deep Freeze
    _check_deep_freeze(info, df_path)

    return info


def _parse_wmi_datetime(wmi_dt: str) -> Optional[datetime]:
    """Parse WMI datetime format like '20260211103045.123456-480'."""
    try:
        dt_str = wmi_dt.split(".")[0]
        return datetime.strptime(dt_str, "%Y%m%d%H%M%S")
    except Exception:
        return None


def _get_ram_fallback() -> float:
    """Get RAM size without WMI."""
    try:
        import psutil
        return round(psutil.virtual_memory().total / (1024**3), 1)
    except ImportError:
        return 0.0


def _populate_network(info: SystemInfo) -> None:
    """Populate network information."""
    try:
        # Get IP address
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))
            info.net_ip = s.getsockname()[0]
        except Exception:
            info.net_ip = "No IP"
        finally:
            s.close()

        # Check internet
        try:
            socket.getaddrinfo("www.google.com", 80, socket.AF_INET)
            info.net_status = "Connected"
        except socket.gaierror:
            info.net_status = "Disconnected"

        # Detect connection type via PowerShell (fast)
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and "
                 "$_.InterfaceDescription -notmatch 'Virtual|Loopback|Bluetooth' } | "
                 "Select-Object -ExpandProperty InterfaceDescription"],
                capture_output=True, text=True, timeout=5
            )
            adapters = result.stdout.strip().split("\n")
            types = []
            for a in adapters:
                a = a.strip()
                if not a:
                    continue
                if any(w in a.lower() for w in ["wi-fi", "wireless", "802.11"]):
                    if "WiFi" not in types:
                        types.append("WiFi")
                elif any(w in a.lower() for w in ["ethernet", "lan", "gigabit"]):
                    if "Ethernet" not in types:
                        types.append("Ethernet")
            if types:
                info.net_type = " + ".join(types)
        except Exception:
            pass

    except Exception:
        pass


def _check_deep_freeze(info: SystemInfo, df_path: str) -> None:
    """Check Deep Freeze status."""
    if not os.path.exists(df_path):
        info.deep_freeze = "Not Installed"
        info.df_color = "grey"
        return

    try:
        result = subprocess.run(
            [df_path, "get", "/ISFROZEN"],
            capture_output=True, timeout=5
        )
        if result.returncode == 1:
            info.deep_freeze = "FROZEN"
            info.df_color = "cyan"
        elif result.returncode == 0:
            info.deep_freeze = "THAWED"
            info.df_color = "red"
        else:
            info.deep_freeze = f"Unknown ({result.returncode})"
            info.df_color = "yellow"
    except Exception:
        info.deep_freeze = "Error"
        info.df_color = "yellow"


@dataclass
class LiveMetrics:
    """Live system metrics for monitoring display."""
    cpu_percent: float = 0.0
    cpu_name: str = "CPU"
    cpu_cores: int = 0
    memory_percent: float = 0.0
    memory_used_gb: float = 0.0
    memory_total_gb: float = 0.0
    disk_percent: float = 0.0
    disk_used_gb: float = 0.0
    disk_total_gb: float = 0.0
    net_online: bool = False
    net_sent_rate: float = 0.0  # KB/s
    net_recv_rate: float = 0.0  # KB/s


_last_net_io = None
_last_net_time = None
_cached_cpu_name = None


def get_live_metrics() -> LiveMetrics:
    """Get current live system metrics."""
    global _last_net_io, _last_net_time, _cached_cpu_name
    
    metrics = LiveMetrics()
    
    try:
        import psutil
        
        # CPU (non-blocking, uses interval=None for instant reading)
        metrics.cpu_percent = psutil.cpu_percent(interval=None)
        metrics.cpu_cores = psutil.cpu_count(logical=True)
        
        # Get CPU name (cached)
        if _cached_cpu_name is None:
            try:
                import subprocess
                result = subprocess.run(
                    ["powershell", "-NoProfile", "-Command",
                     "(Get-CimInstance Win32_Processor).Name"],
                    capture_output=True, text=True, timeout=3
                )
                name = result.stdout.strip()
                # Shorten common names
                name = name.replace("Intel(R) Core(TM) ", "")
                name = name.replace("AMD Ryzen ", "Ryzen ")
                name = name.replace(" CPU", "")
                name = name.replace(" Processor", "")
                _cached_cpu_name = name[:20] if name else "CPU"
            except Exception:
                _cached_cpu_name = "CPU"
        metrics.cpu_name = _cached_cpu_name
        
        # Memory
        mem = psutil.virtual_memory()
        metrics.memory_percent = mem.percent
        metrics.memory_used_gb = round(mem.used / (1024**3), 1)
        metrics.memory_total_gb = round(mem.total / (1024**3), 1)
        
        # Disk (C: drive)
        try:
            disk = psutil.disk_usage("C:\\")
            metrics.disk_percent = disk.percent
            metrics.disk_used_gb = round(disk.used / (1024**3), 1)
            metrics.disk_total_gb = round(disk.total / (1024**3), 1)
        except Exception:
            pass
        
        # Network status check
        try:
            import socket
            socket.setdefaulttimeout(1)
            socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 53))
            metrics.net_online = True
        except Exception:
            metrics.net_online = False
        
        # Network rate calculation
        import time
        current_time = time.time()
        net_io = psutil.net_io_counters()
        
        if _last_net_io is not None and _last_net_time is not None:
            time_delta = current_time - _last_net_time
            if time_delta > 0:
                bytes_sent = net_io.bytes_sent - _last_net_io.bytes_sent
                bytes_recv = net_io.bytes_recv - _last_net_io.bytes_recv
                metrics.net_sent_rate = (bytes_sent / 1024) / time_delta  # KB/s
                metrics.net_recv_rate = (bytes_recv / 1024) / time_delta  # KB/s
        
        _last_net_io = net_io
        _last_net_time = current_time
        
    except ImportError:
        pass
    
    return metrics
