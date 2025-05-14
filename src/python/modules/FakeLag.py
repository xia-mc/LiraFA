import time
from collections import deque

from pydivert import Packet, WinDivert

from .Module import Module
from utils import SystemUtils


class FakeLag(Module):
    def __init__(self, divert: WinDivert, key: str, fakeLagMs: int = 100):
        super().__init__(divert, key)
        self._fakeLagMs: int = fakeLagMs
        self._delayedPackets: deque[tuple[int, Packet]] = deque()

    @staticmethod
    def isTargetPacket(packet: Packet) -> bool:
        pid: int
        if not packet.is_outbound:
            return False
        pid = SystemUtils.getPIDByUDPPort(packet.src_port)
        if pid is None:
            return False
        return SystemUtils.getProcessNameByPID(pid) == "cs2.exe"

    def onEnabled(self) -> None:
        print(f"Start fakeLag ({self._fakeLagMs}ms).")

    def onDisabled(self) -> None:
        print(f"Released {len(self._delayedPackets)} packets.")
        for data in self._delayedPackets:
            self.sendPacket(data[1])
        self._delayedPackets.clear()

    def onUpdate(self, packet: Packet) -> None:
        curTime = int(time.time() * 1000)
        delayed: deque = self._delayedPackets
        delayed.append((curTime, packet))

        if len(delayed) > 0:
            packetTime, packet = delayed[0]

            if curTime - packetTime < self._fakeLagMs:
                return

            self.onDisabled()
            return
