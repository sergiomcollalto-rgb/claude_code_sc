"""Renderiza o Reels "Disciplina, motivação, obsessão".

Vídeo vertical 1080x1920, preto e branco, uma palavra por vez na tela.

Uso:
    python3 render.py            # gera saida/reels_obsessao.mp4

B-roll: coloque os vídeos em clips/ com os nomes shot1.mp4 ... shot6.mp4
(veja SHOTS abaixo). Se um clip não existir, entra um placeholder cinza
com o nome da cena, pra servir de guia de edição.

Fonte: coloque o arquivo da Advercase em fonts/ (qualquer .otf ou .ttf).
Sem ele, o script usa a Unbounded (candidatas/) como substituta.
"""

import glob
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1080, 1920, 30

# Duração por tipo de palavra (segundos)
CURTA, NORMAL, CHAVE, PAUSA = 0.26, 0.34, 0.85, 0.35

# (texto, cena, palavras-chave)
FRASES = [
    ("Disciplina é se obrigar.", 1, {"disciplina"}),
    ("Motivação é querer.", 2, {"motivação"}),
    ("Obsessão é não conseguir parar.", 3, {"obsessão", "parar"}),
    ("A disciplina te tira da cama.", 4, set()),
    ("A motivação vai e vem.", 4, set()),
    ("A obsessão fica.", 4, {"fica"}),
    ("Eu sou pai.", 5, {"pai"}),
    ("Trabalho quando a casa dorme.", 5, {"dorme"}),
    ("E não é sacrifício.", 6, {"sacrifício"}),
    ("É obsessão.", 6, {"obsessão"}),
    ("Por eles.", 6, {"eles"}),
]

SHOTS = {
    1: "B-ROLL 1 · alarme de madrugada, pai levanta, café",
    2: "B-ROLL 2 · escrevendo roteiro, olhar focado",
    3: "B-ROLL 3 · gravando conteúdo, ring light, noite",
    4: "B-ROLL 4 · mãos no teclado, tela, edição",
    5: "B-ROLL 5 · filho no colo enquanto trabalha",
    6: "B-ROLL 6 · porta do quarto do filho, fecha o notebook",
}


def fonte_principal():
    achadas = sorted(glob.glob(os.path.join(ROOT, "fonts", "*.[ot]tf")))
    if achadas:
        return achadas[0], True
    return os.path.join(ROOT, "candidatas", "Unbounded.ttf"), False


def montar_timeline():
    """Devolve [(palavra, inicio, fim, chave)] e a duração de cada cena."""
    palavras, cenas, t = [], {}, 0.0
    for texto, cena, chaves in FRASES:
        inicio_frase = t
        tokens = texto.split()
        for i, tok in enumerate(tokens):
            limpa = tok.strip(".,").lower()
            chave = limpa in chaves
            dur = CHAVE if chave else (CURTA if len(limpa) <= 2 else NORMAL)
            if i == len(tokens) - 1:
                dur += PAUSA
            palavras.append((tok.strip(".,").upper(), t, t + dur, chave))
            t += dur
        cenas[cena] = cenas.get(cena, 0) + (t - inicio_frase)
    return palavras, cenas, t


def segmento_cena(n, dur, saida, fonte_label):
    clip = os.path.join(ROOT, "clips", f"shot{n}.mp4")
    if os.path.exists(clip):
        entrada = ["-stream_loop", "-1", "-i", clip]
        vf = (f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
              "hue=s=0,eq=contrast=1.25:brightness=-0.06,noise=alls=8:allf=t,"
              f"vignette=PI/4,fps={FPS}")
    else:
        entrada = ["-f", "lavfi", "-i", f"color=c=0x1c1c1c:s={W}x{H}:r={FPS}"]
        label = SHOTS[n].replace(":", r"\:")
        vf = ("noise=alls=8:allf=t,vignette=PI/3,"
              f"drawtext=fontfile={fonte_label}:text='{label}':fontcolor=0x8a8a8a:"
              "fontsize=34:x=(w-tw)/2:y=170")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *entrada, "-t", f"{dur:.3f}",
                    "-vf", vf, "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-r", str(FPS), saida], check=True)


def main():
    fonte, eh_advercase = fonte_principal()
    fonte_label = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
    palavras, cenas, total = montar_timeline()

    os.makedirs(os.path.join(ROOT, "saida"), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        lista = os.path.join(tmp, "lista.txt")
        with open(lista, "w") as f:
            for n in sorted(cenas):
                seg = os.path.join(tmp, f"cena{n}.mp4")
                segmento_cena(n, cenas[n], seg, fonte_label)
                f.write(f"file '{seg}'\n")
        base = os.path.join(tmp, "base.mp4")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0",
                        "-i", lista, "-c", "copy", base], check=True)

        filtros = []
        for i, (palavra, ini, fim, chave) in enumerate(palavras):
            arq = os.path.join(tmp, f"w{i}.txt")
            with open(arq, "w") as f:
                f.write(palavra)
            # fontes largas: limita o tamanho pra palavra caber em ~86% da largura
            tamanho = min(150 if chave else 112, int(W * 0.86 / (len(palavra) * 0.86)))
            filtros.append(
                f"drawtext=fontfile={fonte}:textfile={arq}:expansion=none:"
                f"fontsize={tamanho}:fontcolor=white:x=(w-tw)/2:y=(h-th)/2:"
                f"shadowcolor=black@0.6:shadowx=0:shadowy=6:"
                f"enable='between(t,{ini:.3f},{fim:.3f})'")
        saida = os.path.join(ROOT, "saida", "reels_obsessao.mp4")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", base,
                        "-vf", ",".join(filtros), "-c:v", "libx264", "-crf", "26", "-preset", "slow",
                        "-pix_fmt", "yuv420p", "-movflags", "+faststart", saida], check=True)

    print(f"OK: {saida}")
    print(f"Duração: {total:.1f}s | Fonte: {os.path.basename(fonte)}"
          + ("" if eh_advercase else " (substituta, falta a Advercase)"))
    for n in sorted(cenas):
        print(f"  cena {n}: {cenas[n]:.1f}s  {SHOTS[n]}")


if __name__ == "__main__":
    main()
