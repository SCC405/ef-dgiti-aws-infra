"""Recorta la página de Chrome de una grabación de pantalla completa.

Cuando la extensión está actuando, Chrome muestra una barra de depuración de 56 px que
empuja la página hacia abajo, y un resaltado naranja en los bordes. En cada cuadro se
detecta si la barra está y se recorta la misma zona de la página, así no "salta".

Uso:  python process.py <entrada_1920x1080.mp4> <salida.mp4> [--max-hold SEGUNDOS]
--max-hold acorta las esperas: si la pantalla no cambia durante más de SEGUNDOS,
el resto de esa pausa se descarta (las esperas propias de la grabación).
"""

import subprocess
import sys

import numpy as np
from rec import FFMPEG

FPS = 15
SRC_W, SRC_H = 1920, 1080
PAGE_TOP, BANNER_H, PAGE_BOTTOM = 88, 56, 1032
MARGIN = 34  # resaltado naranja de la extensión (lados y abajo)
TOP_MARGIN = 4  # arriba casi nada: ahí está la barra de AWS con el ID de cuenta
OUT_W = SRC_W - 2 * MARGIN                                       # 1852
OUT_H = PAGE_BOTTOM - PAGE_TOP - BANNER_H - TOP_MARGIN - MARGIN  # 850
BANNER_RGB = np.array([79, 52, 58])
STATIC_DIFF = 0.4  # diferencia media (0-255) por debajo de la cual dos cuadros son "iguales"


def has_banner(frame: np.ndarray) -> bool:
    muestra = frame[100, 900:1020].astype(int)
    return bool(np.abs(muestra - BANNER_RGB).max() < 12)


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    max_hold = None
    if "--max-hold" in sys.argv:
        max_hold = int(float(sys.argv[sys.argv.index("--max-hold") + 1]) * FPS)

    dec = subprocess.Popen(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", src,
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE,
    )
    enc = subprocess.Popen(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{OUT_W}x{OUT_H}", "-r", str(FPS), "-i", "-",
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", dst],
        stdin=subprocess.PIPE,
    )
    size = SRC_W * SRC_H * 3
    leidos = escritos = quietos = 0
    previo = None
    while True:
        buf = dec.stdout.read(size)
        if len(buf) < size:
            break
        leidos += 1
        frame = np.frombuffer(buf, np.uint8).reshape(SRC_H, SRC_W, 3)
        y0 = PAGE_TOP + (BANNER_H if has_banner(frame) else 0) + TOP_MARGIN
        pagina = np.ascontiguousarray(frame[y0:y0 + OUT_H, MARGIN:MARGIN + OUT_W])

        if max_hold is not None:
            muestra = pagina[::8, ::8].astype(np.int16)
            if previo is not None and np.abs(muestra - previo).mean() < STATIC_DIFF:
                quietos += 1
                if quietos > max_hold:
                    continue
            else:
                quietos = 0
            previo = muestra

        enc.stdin.write(pagina.tobytes())
        escritos += 1
    enc.stdin.close()
    enc.wait()
    dec.wait()
    print(f"{dst}: {leidos / FPS:.1f} s -> {escritos / FPS:.1f} s")


if __name__ == "__main__":
    main()
