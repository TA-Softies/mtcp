# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec file for MTCP

import os
import sys

block_cipher = None

# Get the directory containing this spec file
spec_dir = os.path.dirname(os.path.abspath(SPEC))
mtcp_dir = os.path.join(spec_dir, 'mtcp')
icon_path = os.path.join(mtcp_dir, 'icons', 'MTCP.ico')

a = Analysis(
    [os.path.join(mtcp_dir, '__main__.py')],
    pathex=[spec_dir],
    binaries=[],
    datas=[
        (os.path.join(mtcp_dir, 'theme.tcss'), 'mtcp'),
        (os.path.join(mtcp_dir, 'icons', 'MTCP.ico'), 'mtcp/icons'),
        (os.path.join(mtcp_dir, 'icons', 'MTCP.png'), 'mtcp/icons'),
        (os.path.join(spec_dir, 'sfu-tools'), 'sfu-tools'),
    ],
    hiddenimports=[
        'textual',
        'textual.app',
        'textual.widgets',
        'textual.containers',
        'textual.screen',
        'textual.binding',
        'textual.reactive',
        'textual.widgets.option_list',
        'textual.css',
        'textual.css.parse',
        'textual.css.stylesheet',
        'rich',
        'rich.console',
        'rich.text',
        'rich.markup',
        'psutil',
        'wmi',
        'win32com',
        'win32com.client',
        'pythoncom',
        'pywintypes',
        'mtcp',
        'mtcp.app',
        'mtcp.screens',
        'mtcp.sysinfo',
        'mtcp.tools',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='MTCP',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # Console app for TUI
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=icon_path if os.path.exists(icon_path) else None,
)
