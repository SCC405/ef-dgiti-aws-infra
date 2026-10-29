"""Genera la escena del diagrama: recorrido con zoom suave por docs/arquitectura.png.

Uso:  python diagram_tour.py <arquitectura.png> <salida.mp4>
Las regiones están en coordenadas de la imagen mostrada a 2000 px de ancho
(se escalan al tamaño real). Cada paso: (segundo_de_inicio, region).
"""

import subprocess
import sys

from PIL import Image
from rec import FFMPEG

W, H, FPS = 1920, 944, 15
ASPECT = W / H
MOVE = 2.5  # segundos de transición entre regiones

# (cx, cy, ancho) en coordenadas de la imagen a 2000 px
REGIONES = {
    "todo": (1000, 911, 3708),
    "entrada": (1150, 560, 1950),       # usuarios -> IGW -> ALB, capa pública
    "vpc": (1235, 1175, 2100),          # tres capas en dos zonas
    "asg": (993, 1190, 1000),           # Auto Scaling Group con EC2 en 1a y 1b
    "datos": (1545, 1520, 850),         # RDS principal + réplica
    "seguridad": (1300, 1350, 1500),    # SG-APP y SG-DB encadenados
    "soporte": (1548, 410, 950),        # SSM, CloudWatch, EBS
    "cicd": (400, 1335, 900),           # flujo de despliegue
}

GUION = [
    (0, "todo"),
    (5, "entrada"),
    (18, "vpc"),
    (29, "asg"),
    (39, "datos"),
    (49, "seguridad"),
    (59, "soporte"),
    (66, "cicd"),
    (75, "todo"),
]
DURACION = 80


def ease(t: float) -> float:
    return t * t * (3 - 2 * t)


def region_en(t: float, escala: float):
    actual = GUION[0]
    for paso in GUION:
        if paso[0] <= t:
            actual = paso
    i = GUION.index(actual)
    destino = REGIONES[actual[1]]
    if i == 0:
        caja = destino
    else:
        origen = REGIONES[GUION[i - 1][1]]
        p = ease(min(1.0, (t - actual[0]) / MOVE))
        caja = tuple(o + (d - o) * p for o, d in zip(origen, destino, strict=False))
    cx, cy, w = (v * escala for v in caja)
    h = w / ASPECT
    return cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2


def main() -> None:
    img = Image.open(sys.argv[1]).convert("RGB")
    escala = img.width / 2000
    # Lienzo blanco amplio para que las cajas que salen del borde no fallen.
    pad = img.width
    lienzo = Image.new("RGB", (img.width + 2 * pad, img.height + 2 * pad), "white")
    lienzo.paste(img, (pad, pad))

    cmd = [
        FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", sys.argv[2],
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for n in range(DURACION * FPS):
        x0, y0, x1, y1 = region_en(n / FPS, escala)
        frame = lienzo.crop((round(x0 + pad), round(y0 + pad), round(x1 + pad), round(y1 + pad)))
        proc.stdin.write(frame.resize((W, H), Image.LANCZOS).tobytes())
    proc.stdin.close()
    proc.wait()


if __name__ == "__main__":
    main()
