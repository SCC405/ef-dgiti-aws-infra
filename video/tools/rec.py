"""Graba la pantalla (solo el área de la página de Chrome) hasta que aparezca el archivo STOP.

Uso:  python rec.py <salida.mp4>
Para detener:  crear el archivo <salida.mp4>.stop
"""

import pathlib
import subprocess
import sys
import time

FFMPEG = (
    r"C:\Users\cifue\AppData\Local\Microsoft\WinGet\Packages"
    r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe"
)


def main() -> None:
    out = pathlib.Path(sys.argv[1])
    stop = out.with_suffix(out.suffix + ".stop")
    stop.unlink(missing_ok=True)

    # Pantalla completa: el recorte de la página (con o sin la barra de depuración)
    # lo hace process.py cuadro por cuadro.
    cmd = [
        FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "gdigrab", "-framerate", "15", "-draw_mouse", "0",
        "-i", "desktop",
        "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18", "-pix_fmt", "yuv420p",
        str(out),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    start = time.time()
    while not stop.exists() and proc.poll() is None:
        time.sleep(0.2)
    if proc.poll() is None:
        proc.communicate(b"q", timeout=30)
    stop.unlink(missing_ok=True)
    print(f"{out.name}: {time.time() - start:.1f} s")


if __name__ == "__main__":
    main()
