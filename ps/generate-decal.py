#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""
Gera arquivos de decal (.vtf + .vmt) para o plugin map-decals a partir de uma
imagem, ja gravando nos dois lugares necessarios:

    materials/decals/<sub>/<nome>.vtf|.vmt   -> servidor (PrecacheDecal)
    fastdl/materials/decals/<sub>/<nome>.*   -> download do cliente (FastDL)

O VTF sai sempre na versao 7.4 (o L4D2 rejeita 7.5).

Requisitos (uma vez):
    py -m pip install pillow srctools

Uso (Windows, use "py -3" p/ evitar o stub da Microsoft Store):
    py -3 ps/generate-decal.py <imagem> <nome> [opcoes]

Exemplos:
    py -3 ps/generate-decal.py assets/motd.jpeg motd --fit stretch
    py -3 ps/generate-decal.py logo.png logo_time --sub l4d2br --shader unlit
    py -3 ps/generate-decal.py spray.png grafite --shader modulate --fit pad

Depois de gerar, registre o nome em:
    addons/sourcemod/configs/map-decals/decals.cfg
(o script imprime o trecho pronto pra colar)
"""

import argparse
import os
import sys

try:
    from PIL import Image
    from srctools.vtf import VTF, ImageFormats, VTFFlags
except ImportError:
    sys.exit("Faltam dependencias. Rode:  py -m pip install pillow srctools")

# raiz do repo = pasta acima de /ps
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def next_pow2(n):
    p = 1
    while p < n:
        p <<= 1
    return p


def parse_size(spec, img):
    """Retorna (W, H) potencias de 2. 'auto' deriva da imagem (cap 1024)."""
    if spec and spec.lower() != "auto":
        w, h = spec.lower().split("x")
        return int(w), int(h)
    w, h = img.size
    cap = 1024
    return min(next_pow2(w), cap), min(next_pow2(h), cap)


def fit_image(img, size, mode):
    """Encaixa a imagem no canvas. 'stretch' distorce; 'pad' preserva proporcao
    com fundo transparente (letterbox)."""
    if mode == "stretch":
        return img.resize(size, Image.LANCZOS)
    # pad: preserva aspecto, centraliza, fundo transparente
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    src = img.copy()
    src.thumbnail(size, Image.LANCZOS)
    canvas.paste(src, ((size[0] - src.width) // 2, (size[1] - src.height) // 2), src)
    return canvas


def make_vmt(relpath, shader, translucent, scale):
    # $decalscale controla o tamanho na parede (menor = menor). Tamanho do decal
    # ~= dimensoes da textura (px) * $decalscale. Sem ele, o padrao (1.0) fica enorme.
    if shader == "modulate":
        # spray/multiply: branco fica invisivel, escuro "mancha" a parede
        return (
            "DecalModulate\n{\n"
            '\t"$basetexture" "%s"\n'
            '\t"$decal" 1\n'
            '\t"$decalscale" %s\n'
            '\t"$vertexcolor" 1\n'
            '\t"$vertexalpha" 1\n'
            "}\n" % (relpath, scale)
        )
    head = "UnlitGeneric" if shader == "unlit" else "LightmappedGeneric"
    lines = ["%s\n{" % head, '\t"$basetexture" "%s"' % relpath,
             '\t"$decal" 1', '\t"$decalscale" %s' % scale]
    if translucent:
        lines.append('\t"$translucent" 1')
    lines.append("}\n")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description="Gera .vtf + .vmt para o plugin map-decals (L4D2).")
    ap.add_argument("imagem", help="caminho da imagem (png/jpg). png com alpha p/ transparencia")
    ap.add_argument("nome", help="nome do decal (sem espaco/acento); usado no !paintdecal e no decals.cfg")
    ap.add_argument("--sub", default="l4d2br", help="subpasta em decals/ (default: l4d2br)")
    ap.add_argument("--size", default="auto", help="'auto' ou WxH em potencias de 2 (ex.: 1024x512)")
    ap.add_argument("--fit", choices=["pad", "stretch"], default="pad",
                    help="pad = preserva proporcao com fundo transparente (default); stretch = estica")
    ap.add_argument("--shader", choices=["lit", "unlit", "modulate"], default="lit",
                    help="lit=LightmappedGeneric (default, recebe luz do mapa); "
                         "unlit=UnlitGeneric (sempre brilhante); modulate=spray/multiply")
    ap.add_argument("--scale", default="0.15",
                    help="$decalscale: tamanho na parede (menor = menor). default 0.15. "
                         "escala linear: 0.075 = metade, 0.30 = dobro")
    args = ap.parse_args()

    src_path = args.imagem if os.path.isabs(args.imagem) else os.path.join(REPO, args.imagem)
    if not os.path.isfile(src_path):
        sys.exit("Imagem nao encontrada: %s" % src_path)

    img = Image.open(src_path).convert("RGBA")
    W, H = parse_size(args.size, img)
    if W & (W - 1) or H & (H - 1):
        sys.exit("Dimensoes precisam ser potencia de 2 (ex.: 256, 512, 1024). Recebi %dx%d" % (W, H))

    fitted = fit_image(img, (W, H), args.fit)

    # tem transparencia? (padding ou alpha do png) -> precisa $translucent
    alpha = fitted.getchannel("A")
    translucent = alpha.getextrema()[0] < 255

    relpath = "decals/%s/%s" % (args.sub, args.nome)

    # VTF 7.4, RGBA8888, todos os mips preenchidos (senao fica preto a distancia)
    vtf = VTF(W, H, version=(7, 4), fmt=ImageFormats.RGBA8888)
    for mip in range(vtf.mipmap_count):
        mw, mh = max(1, W >> mip), max(1, H >> mip)
        vtf.get(mipmap=mip).copy_from(fitted.resize((mw, mh), Image.LANCZOS).tobytes(),
                                      ImageFormats.RGBA8888)

    vmt = make_vmt(relpath, args.shader, translucent, args.scale)

    dests = [
        os.path.join(REPO, "materials", "decals", args.sub),
        os.path.join(REPO, "fastdl", "materials", "decals", args.sub),
    ]
    for d in dests:
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, args.nome + ".vtf"), "wb") as f:
            vtf.save(f)
        with open(os.path.join(d, args.nome + ".vmt"), "w", newline="\n") as f:
            f.write(vmt)

    print("OK  %dx%d  fit=%s  shader=%s  translucent=%s  (VTF 7.4)" %
          (W, H, args.fit, args.shader, translucent))
    for d in dests:
        print("  ->", os.path.join(d, args.nome + ".vtf"))
    print("\nRegistre no addons/sourcemod/configs/map-decals/decals.cfg:")
    print('\t"%s"\n\t{\n\t\t"path"\t"%s"\n\t}' % (args.nome, relpath))


if __name__ == "__main__":
    main()
