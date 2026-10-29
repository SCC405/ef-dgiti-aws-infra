"""Arma el video final a partir de las escenas procesadas.

Cada escena se escala dentro de una caja de 1920x880, se pone sobre un fondo oscuro de
1920x1080 con una barra superior que dice quién habla y qué se muestra, y se ajusta a su
duración objetivo: si es más corta se congela el último cuadro; si es más larga se acelera.
Al final se concatenan todas, con tarjetas de título entre las partes de cada integrante.

Uso:  python assemble.py
"""

import json
import pathlib
import subprocess

from rec import FFMPEG

FFPROBE = FFMPEG.replace("ffmpeg.exe", "ffprobe.exe")
ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW, OUT, TMP = ROOT / "raw", ROOT, ROOT / "tmp"
FPS = 30
BG = "0x0f1419"
FONT = "C\\:/Windows/Fonts/segoeui.ttf"
FONT_B = "C\\:/Windows/Fonts/segoeuib.ttf"
COLOR = {"Santiago": "0x4fc3f7", "Erick": "0x81c784", "Nicolay": "0xffb74d"}

# (archivo, integrante, rótulo, duración objetivo en segundos)
ESCENAS = json.loads((ROOT / "tools" / "escenas.json").read_text(encoding="utf-8"))


def duracion(path: pathlib.Path) -> float:
    out = subprocess.run(
        [FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())


def texto(nombre: str, contenido: str) -> str:
    f = TMP / f"{nombre}.txt"
    f.write_text(contenido, encoding="utf-8")
    return str(f).replace("\\", "/").replace(":", "\\:")


def tarjeta(i: int, item: dict) -> pathlib.Path:
    dst = TMP / f"{i:02d}-tarjeta.mp4"
    quien = item["quien"]
    t1 = texto(f"{i:02d}-t1", item["titulo"])
    t2 = texto(f"{i:02d}-t2", item.get("subtitulo", ""))
    vf = (
        f"drawtext=fontfile='{FONT_B}':textfile='{t1}':fontsize=76:fontcolor={COLOR.get(quien, 'white')}"
        ":x=(w-tw)/2:y=(h/2)-110,"
        f"drawtext=fontfile='{FONT}':textfile='{t2}':fontsize=40:fontcolor=0xd0d7de"
        ":x=(w-tw)/2:y=(h/2)+10:line_spacing=14,"
        f"fade=t=in:st=0:d=0.4,fade=t=out:st={item['seg'] - 0.4}:d=0.4"
    )
    subprocess.run(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
         "-f", "lavfi", "-i", f"color=c={BG}:s=1920x1080:r={FPS}:d={item['seg']}",
         "-vf", vf, "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", str(dst)],
        check=True,
    )
    return dst


def escena(i: int, item: dict) -> pathlib.Path:
    src = RAW / item["archivo"]
    dst = TMP / f"{i:02d}-escena.mp4"
    real = duracion(src)
    objetivo = item["seg"]
    velocidad = max(1.0, real / objetivo)
    congelar = max(0.0, objetivo - real / velocidad)
    quien = item["quien"]
    rotulo = texto(f"{i:02d}-rotulo", item["rotulo"])
    nombre = texto(f"{i:02d}-nombre", quien.upper())
    vf = (
        f"setpts=PTS/{velocidad:.4f},fps={FPS},"
        "scale=1920:880:force_original_aspect_ratio=decrease,"
        f"pad=1920:1080:(ow-iw)/2:100+(880-ih)/2:color={BG},"
        f"drawbox=x=0:y=0:w=1920:h=96:color={BG}:t=fill,"
        f"drawbox=x=0:y=92:w=1920:h=4:color={COLOR[quien]}:t=fill,"
        f"drawtext=fontfile='{FONT_B}':textfile='{nombre}':fontsize=34:fontcolor={COLOR[quien]}:x=40:y=28,"
        f"drawtext=fontfile='{FONT}':textfile='{rotulo}':fontsize=34:fontcolor=0xe6edf3:x=260:y=28,"
        f"tpad=stop_mode=clone:stop_duration={congelar:.3f},"
        "fade=t=in:st=0:d=0.25"
    )
    subprocess.run(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
         "-vf", vf, "-t", f"{objetivo:.3f}", "-an",
         "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", str(dst)],
        check=True,
    )
    print(f"{item['archivo']:28s} real {real:6.1f}s  x{velocidad:.2f}  +{congelar:5.1f}s congelado -> {objetivo}s")
    return dst


def main() -> None:
    TMP.mkdir(exist_ok=True)
    partes, t = [], 0.0
    linea = []
    for i, item in enumerate(ESCENAS):
        parte = tarjeta(i, item) if item.get("tarjeta") else escena(i, item)
        partes.append(parte)
        linea.append(f"{int(t // 60):02d}:{t % 60:04.1f}  {item['quien']:9s} {item.get('rotulo') or item.get('titulo')}")
        t += item["seg"]
    lista = TMP / "lista.txt"
    lista.write_text("".join(f"file '{p.as_posix()}'\n" for p in partes), encoding="utf-8")
    final = OUT / "EF-DGITI-video-sin-voz.mp4"
    subprocess.run(
        [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
         "-i", str(lista), "-c", "copy", "-movflags", "+faststart", str(final)],
        check=True,
    )
    (OUT / "linea-de-tiempo.txt").write_text("\n".join(linea) + f"\nFIN  {int(t // 60):02d}:{t % 60:04.1f}\n", encoding="utf-8")
    print("\n".join(linea))
    print(f"TOTAL {int(t // 60)}:{t % 60:04.1f} -> {final}")


if __name__ == "__main__":
    main()
