import ctypes
import os
import sys
from typing import Optional
from psutil import Process, NoSuchProcess

import psutil


def getPIDByUDPPort(port: int) -> Optional[int]:
    for conn in psutil.net_connections(kind='udp'):
        if conn.laddr and conn.laddr.port == port:
            return conn.pid
    return None


def getProcessNameByPID(pid: int) -> Optional[str]:
    if not psutil.pid_exists(pid):
        return None
    try:
        return Process(pid).name()
    except NoSuchProcess:
        return None


def ensureAdmin():
    if ctypes.windll.shell32.IsUserAnAdmin():
        return

    script = os.path.abspath(sys.argv[0])
    params = " ".join([f'"{arg}"' for arg in sys.argv[1:]])

    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, f'"{script}" {params}', None, 1
    )
    sys.exit(0)
