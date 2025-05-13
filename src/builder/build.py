import os
import shutil
import subprocess
from pathlib import Path
from subprocess import Popen

import FileUtils

PROJECT_PATH: Path = Path(__file__).parent.parent.parent
SRC_DIR = PROJECT_PATH / "src" / "lua"
RESOURCES_DIR = PROJECT_PATH / "src" / "resources"
BUILD_DIR = PROJECT_PATH / "build"
OBFUSCATOR = Path("D:/Prometheus/cli.lua").absolute()
CONFIG_PATH = (PROJECT_PATH / "src" / "builder" / "config.lua").absolute()


def main():
    print("Starting...")
    FileUtils.ensureDirectoryEmpty(BUILD_DIR)
    shutil.copytree(SRC_DIR, BUILD_DIR, dirs_exist_ok=True)

    # find files
    sourceFiles: list[Path] = []

    def find(files: list[Path], directory: Path) -> None:
        for d in directory.iterdir():
            if d.is_dir():
                find(directory)
                continue
            if d.suffix == ".lua":
                files.append(d.absolute())

    find(sourceFiles, BUILD_DIR)

    # obf
    for sourceFile in sourceFiles:
        process = Popen(
            ["luajit", str(OBFUSCATOR), "--config", str(CONFIG_PATH), "--out", str(sourceFile), str(sourceFile)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="UTF-8",
            bufsize=1,
            universal_newlines=True
        )
        print(f"Compile command: {' '.join(process.args)}")
        for out in process.communicate():
            if out is None or len(out) == 0:
                continue
            print(out.strip())

    # copy
    shutil.copytree(RESOURCES_DIR, BUILD_DIR, dirs_exist_ok=True)

    print("Compile successfully!")


if __name__ == '__main__':
    main()
