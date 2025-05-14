import os
import traceback

from pydivert import Packet, WinDivert

from modules.Backtrack import Backtrack
from utils import SystemUtils


def main():
    SystemUtils.ensureAdmin()

    with WinDivert("udp") as w:
        module = Backtrack(w, "G")

        print("Started!")
        while True:
            packet: Packet = w.recv()
            module.update(packet)


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        traceback.print_exception(e)
    os.system("pause")
