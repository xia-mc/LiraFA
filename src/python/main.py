import os
import sys

if hasattr(sys, "_MEIPASS"):
    # noinspection PyProtectedMember
    os.add_dll_directory(sys._MEIPASS)

import time
import traceback
import typing

from pydivert import Packet, WinDivert

from modules.Backtrack import Backtrack
from modules.FakeLag import FakeLag
from modules.Module import Module
from shared.Listener import Listener
from shared.Logger import LOGGER
from shared import Logger
from utils import SystemUtils


SPLASH = r"""
.____     .__
|    |    |__|_______ _____
|    |    |  |\_  __ \\__  \
|    |___ |  | |  | \/ / __ \_
|_______ \|__| |__|   (____  /
        \/                 \/
          Lira 1.7
       xia__mc, 2025.
"""


def handleListener(listener: Listener, modules: dict[str, Module]) -> None:
    raw: bytes | None = listener.read()
    if raw is None:
        return

    try:
        datas = raw.decode("utf-8").split("\n")
    except UnicodeDecodeError:
        return

    if len(datas) == 0:
        return

    for dataStr in datas:
        data = dataStr.split(" ")
        if len(data) == 0:
            continue
        if len(data[0]) == 0:
            continue

        op = data[0]
        if op == "enable":
            if len(data) != 2:
                continue
            module = modules.get(data[1])
            module.enable()
        elif op == "disable":
            if len(data) != 2:
                continue
            module = modules.get(data[1])
            module.disable()
        elif op == "Backtrack":
            if len(data) != 2:
                continue
            try:
                value = int(data[1])
            except ValueError:
                continue
            typing.cast(Backtrack, modules["Backtrack"]).backtrackMs = value
        elif op == "FakeLag":
            if len(data) != 2:
                continue
            try:
                value = int(data[1])
            except ValueError:
                continue
            typing.cast(FakeLag, modules["FakeLag"]).fakeLagMs = value


def main():
    SystemUtils.ensureAdmin()

    LOGGER.info("Setup Windows Kernel Driver (WinDivert)...")
    WinDivert.register()
    time.sleep(1)
    if not WinDivert.is_registered():
        LOGGER.critical("Failed to setup WinDivert.")
        return

    LOGGER.info("Lira Backend Started! You can load the Lira.lua now.")
    listener = Listener()
    LOGGER.info("Waiting for client...")
    listener.connect()
    LOGGER.info("Client connected!")

    with WinDivert("udp") as w:
        modules: dict[str, Module] = {
            "FakeLag": FakeLag(w, None),
            "Backtrack": Backtrack(w, None)
        }

        while True:
            handleListener(listener, modules)

            packet: Packet = w.recv()
            for module in modules.values():
                if not module.update(packet):
                    break
            w.send(packet, recalculate_checksum=False)


if __name__ == '__main__':
    print(SPLASH)

    try:
        Logger.init()
        try:
            main()
        except Exception as e:
            LOGGER.error(*traceback.format_exception(e))
    except Exception as e:
        traceback.print_exception(e)
    os.system("pause")
