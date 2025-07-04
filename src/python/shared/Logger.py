from __future__ import annotations

import sys
import time
from enum import IntEnum
from typing import TextIO

import colorama
import tqdm
from colorama import Fore, Style


class LogLevel(IntEnum):
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
    CRITICAL = 4


class Logger:
    UNDERLINE = "\033[4m"
    RESET = "\033[0m"

    def __init__(self, level: LogLevel, file: TextIO | None = None):
        """
        Initialize the Logger with a log level and an optional output file.

        :param level: The minimum log level for messages to be logged.
        :param file: The file to which logs will be written. Defaults to stdout if None.
        """
        self.level = level
        self.__file = file

    def __del__(self):
        """
        Destructor to ensure the file is closed if it was opened.
        """
        if (self.__file is not None) and (not self.__file.closed):
            self.__file.close()
            self.__file = None

    def debug(self, *message: object) -> None:
        """
        Log a debug message.

        :param message: The message(s) to log.
        """
        self.log(LogLevel.DEBUG, *message)

    def info(self, *message: object) -> None:
        """
        Log an info message.

        :param message: The message(s) to log.
        """
        self.log(LogLevel.INFO, *message)

    def warn(self, *message: object) -> None:
        """
        Log a warning message.

        :param message: The message(s) to log.
        """
        self.log(LogLevel.WARN, *message)

    def error(self, *message: object) -> None:
        """
        Log an error message.

        :param message: The message(s) to log.
        """
        self.log(LogLevel.ERROR, *message)

    def critical(self, *message: object) -> None:
        """
        Log a critical message.

        :param message: The message(s) to log.
        """
        self.log(LogLevel.CRITICAL, *message)

    def log(self, level: LogLevel, *message: object) -> None:
        """
        Log a message at a specified log level with color.

        :param level: The log level of the message.
        :param message: The message(s) to log.
        """
        if level >= self.level:
            out = self.getOutput()
            timeStr = time.strftime("%H:%M:%S", time.localtime())

            # Select color based on log level
            color = self._getColor(level)

            with tqdm.tqdm.external_write_mode(file=None, nolock=True):
                for msg in message:
                    out.write(f"{color}[{timeStr}] [{level.name}]: ")
                    out.write(str(msg))
                    out.write(Style.RESET_ALL + "\n")

    def getOutput(self) -> TextIO:
        """
        Get the output stream for logging.

        :return: The file object to which logs will be written, or stdout if no file is provided.
        """
        if self.__file is not None:
            return self.__file
        else:
            return sys.stdout

    @staticmethod
    def _getColor(level: LogLevel) -> str:
        """
        Get the color for the specified log level.

        :param level: The log level for which color is needed.
        :return: The color code as a string.
        """
        if level == LogLevel.DEBUG:
            return Fore.CYAN
        elif level == LogLevel.INFO:
            return Fore.GREEN
        elif level == LogLevel.WARN:
            return Fore.YELLOW
        elif level == LogLevel.ERROR:
            return Fore.RED
        elif level == LogLevel.CRITICAL:
            return Fore.MAGENTA
        else:
            return Fore.WHITE


LOGGER: Logger = Logger(LogLevel.DEBUG)


def init():
    colorama.init(autoreset=True)
