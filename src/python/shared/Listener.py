from typing import Optional

from win32file import ReadFile, WriteFile
from win32pipe import CreateNamedPipe, PIPE_ACCESS_DUPLEX, PIPE_TYPE_MESSAGE, PIPE_WAIT, ConnectNamedPipe, SetNamedPipeHandleState, \
    PIPE_NOWAIT


class Listener:
    def __init__(self):
        self._pipe: object = CreateNamedPipe(
            r'\\.\pipe\LiraFABackend',
            PIPE_ACCESS_DUPLEX,
            PIPE_TYPE_MESSAGE | PIPE_WAIT,
            1, 65536, 65536, 0, None
        )

    def connect(self) -> None:
        ConnectNamedPipe(self._pipe, None)
        SetNamedPipeHandleState(self._pipe, PIPE_NOWAIT, None, None)

    def read(self) -> Optional[bytes]:
        try:
            _, data = ReadFile(self._pipe, 4096)
            return data
        except (IOError, Exception):
            return None

    def write(self, data: bytes) -> None:
        WriteFile(self._pipe, data)
