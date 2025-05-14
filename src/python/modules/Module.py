import functools
from abc import ABC, abstractmethod
from typing import final

import keyboard
from pydivert import Packet, WinDivert


class Module(ABC):
    def __init__(self, divert: WinDivert, key: str):
        self._divert = divert
        self._key = key
        self._enabled = False

        self.sendPacket = functools.partial(WinDivert.send, divert, recalculate_checksum=False)

    @staticmethod
    @abstractmethod
    def isTargetPacket(packet: Packet) -> bool:
        ...

    @final
    def sendPacket(self, packet: Packet) -> None:
        raise NotImplementedError()

    @final
    def update(self, packet: Packet) -> None:
        if self._key is None:
            if self._enabled:
                self._enabled = False
                self.onDisabled()
            return

        if keyboard.is_pressed(self._key):
            if not self._enabled:
                self._enabled = True
                self.onEnabled()

            if self.isTargetPacket(packet):
                self.onUpdate(packet)
                return
        elif self._enabled:
            self._enabled = False
            self.onDisabled()
        self.sendPacket(packet)

    def onUpdate(self, packet: Packet) -> None:
        ...

    def onEnabled(self) -> None:
        ...

    def onDisabled(self) -> None:
        ...
