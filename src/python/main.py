import functools
import os
import traceback
from collections import deque
from typing import Callable

import keyboard
from pydivert import Packet, WinDivert

from utils import SystemUtils


def isTargetPacket(packet: Packet) -> bool:
    assert packet.tcp is None
    assert packet.udp is not None
    if not packet.is_outbound:
        return False
    if packet.is_loopback:
        return False
    pid = SystemUtils.getPIDByUDPPort(packet.src_port)
    if pid is None:
        return False
    return SystemUtils.getProcessNameByPID(pid) == "cs2.exe"


def main():
    SystemUtils.ensureAdmin()

    blink: bool = False
    delayedPackets: deque[Packet] = deque()

    with WinDivert("udp") as w:
        sendPacket: Callable[[Packet], None] = functools.partial(WinDivert.send, w, recalculate_checksum=False)

        print("Started!")
        for packet in w:
            if keyboard.is_pressed("G"):
                if not blink:
                    print("Start blink.")
                    blink = True

                if not isTargetPacket(packet):
                    sendPacket(packet)
                    continue
                delayedPackets.append(packet)
            elif blink:
                print(f"Blinked {len(delayedPackets)} packets.")
                for p in delayedPackets:
                    sendPacket(p)
                delayedPackets.clear()
                sendPacket(packet)
                blink = False
            else:
                sendPacket(packet)


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        traceback.print_exception(e)
    os.system("pause")
