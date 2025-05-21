import time
from collections import deque

from pydivert import Packet, WinDivert

from shared.Logger import LOGGER
from .Module import Module
from utils import SystemUtils


class Backtrack(Module):
    def __init__(self, divert: WinDivert, key: str | None, backtrackMs: int = 200):
        super().__init__(divert, key)
        self.backtrackMs: int = backtrackMs
        self._delayedPackets: deque[tuple[int, Packet]] = deque()

    @staticmethod
    def isTargetPacket(packet: Packet) -> bool:
        pid: int
        if packet.is_outbound:
            return False
        pid = SystemUtils.getPIDByUDPPort(packet.dst_port)
        if pid is None:
            return False
        return SystemUtils.getProcessNameByPID(pid) == "cs2.exe"

    def onDisabled(self) -> None:
        LOGGER.debug(f"Backtrack: Released {len(self._delayedPackets)} packets.")
        for data in self._delayedPackets:
            self.sendPacket(data[1])
        self._delayedPackets.clear()

    def onUpdate(self, packet: Packet) -> bool:
        curTime = int(time.time() * 1000)
        delayed: deque = self._delayedPackets
        delayed.append((curTime, packet))

        while len(delayed) > 0:
            packetTime, packet = delayed[0]

            if curTime - packetTime < self.backtrackMs:
                return False

            delayed.popleft()
            self.sendPacket(packet)
        return False
