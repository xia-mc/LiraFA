import functools
from abc import ABC, abstractmethod
from typing import final

import keyboard
from pydivert import Packet, WinDivert

from shared.Logger import LOGGER


class Module(ABC):
    def __init__(self, divert: WinDivert, key: str | None):
        self._divert = divert
        self._key = key
        self._lastPressed = False
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
    def update(self, packet: Packet) -> bool:
        if self._key is not None:
            if keyboard.is_pressed(self._key):
                if not self._lastPressed:
                    self.toggle()
                self._lastPressed = True
            else:
                self._lastPressed = False
        else:
            self._lastPressed = False

        if self._enabled and self.isTargetPacket(packet):
            return self.onUpdate(packet)
        return True

    @final
    def toggle(self) -> bool:
        return self.enable() or self.disable()

    @final
    def enable(self) -> bool:
        if not self._enabled:
            self._enabled = True
            self.onEnabled()
            LOGGER.debug(f"{self.__class__.__name__} Enabled.")
            return True
        return False

    @final
    def disable(self) -> bool:
        if self._enabled:
            self._enabled = False
            self.onDisabled()
            LOGGER.debug(f"{self.__class__.__name__} Disabled.")
            return True
        return False

    def onUpdate(self, packet: Packet) -> bool:
        ...

    def onEnabled(self) -> None:
        ...

    def onDisabled(self) -> None:
        ...
