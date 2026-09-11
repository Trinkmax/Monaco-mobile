# `store/` — todo lo que se pega o se sube a las tiendas

Generado el 10/sep/2026. Acá está el material de las dos fichas: textos listos para
copiar, capturas y gráficos con las medidas exactas que pide cada tienda. **Nada de esto
entra en la app**: es material de publicación.

```
store/
├── app-store.md          Ficha de App Store Connect (nombre, textos, keywords, edad, notas del revisor)
├── play-store.md         Ficha de Play Console (título, descripciones, IARC, público, acceso)
├── privacy-labels.md     App Privacy de Apple, respuesta por respuesta
├── data-safety.md        Seguridad de los datos de Play, respuesta por respuesta
├── app-store/
│   └── icon-1024.png     1024×1024 RGB sin alfa (por si App Store Connect lo pide suelto)
├── play/
│   ├── icon-512.png          512×512 PNG de 32 bits (Play le aplica su máscara redondeada)
│   └── feature-graphic.png   1024×500 sin alfa — OBLIGATORIO para publicar la ficha
└── capturas/
    ├── ios-6.9/          6 PNG de 1320×2868 sin alfa (iPhone 17 Pro Max = tamaño 6.9")
    └── play/             los mismos 6, a 1080×2160 (relación 2:1 exacta)
```

---

## Regenerar las capturas

Las pinta `integration_test/store_shots_test.dart` con la app real y providers
overrideados: **sin login, sin red y con una persona ficticia** ("Martín",
351 555-0123). Inicio, Sucursales y Premios salen con el dock Liquid Glass porque en la
app viven dentro del `ShellRoute`; Bienvenida, el wizard y Mi categoría salen sin dock
porque en la app tampoco lo tienen.

```bash
cd Monaco-mobile
xcrun simctl boot 0E8B6324-7F0B-4713-9EA7-623C915DC70E   # iPhone 17 Pro Max, iOS 26.1
QA_SHOTS_DIR=store/capturas/ios-6.9 flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/store_shots_test.dart \
  -d 0E8B6324-7F0B-4713-9EA7-623C915DC70E
```

**El simulador tiene que ser un iPhone 17 Pro Max**: su pantalla es 440×956 pt @3x =
1320×2868 px, que es exactamente el tamaño 6.9" que pide App Store Connect. Con otro
modelo las capturas salen de otra medida y la ficha las rechaza.

Si salen todas iguales (la pantalla de lanzamiento con la M), el simulador quedó con una
instancia vieja: `xcrun simctl shutdown <udid>` y volver a bootear.

**Verificá el contenido, no el tamaño del archivo.** Un `flutter drive` incremental puede
servir una build vieja sin decir nada: pasó el 10/9/2026 con la tira "Listos para usar",
que siguió mostrando un premio después de agregar el segundo. Abrí los PNG y mirálos.

### Post-proceso (las capturas salen con canal alfa; App Store no lo acepta)

```bash
cd Monaco-mobile/store/capturas
# 1) aplanar el alfa de las de iOS (quedan 1320×2868 RGB)
for f in ios-6.9/*.png; do
  magick "$f" -background '#0A0A0A' -alpha remove -alpha off -strip "PNG24:$f"
done
# 2) derivar las de Play (1080×2160, relación 2:1 exacta)
for f in ios-6.9/*.png; do
  magick "$f" -resize x2160 -background '#0A0A0A' -gravity center \
    -extent 1080x2160 -alpha off -strip "PNG24:play/$(basename $f)"
done
# 3) verificar
for f in ios-6.9/*.png play/*.png; do
  magick identify -format "%f %wx%h %[channels]\n" "$f"
done
```

Play rechaza una captura cuyo lado mayor supere el doble del menor, y **ningún teléfono
moderno cumple** (iPhone 17 Pro Max 2,17; Pixel 7 Pro 2,17; Pixel 8 2,22). Por eso la
variante de Play va escalada a 2160 de alto y centrada sobre #0A0A0A —el mismo fondo de
la app, así que el relleno no se ve— hasta llegar a 1080 de ancho.

## Regenerar los gráficos

```bash
cd Monaco-mobile
# Gráfico de la función de Play (1024×500, obligatorio)
magick -size 1024x500 xc:'#0A0A0A' \
  \( assets/images/monaco_wordmark.png -resize 614x \) -gravity center -geometry +0-45 -composite \
  -font assets/fonts/Poppins-Medium.ttf -pointsize 30 -kerning 4 -fill '#9A9A9A' \
  -gravity center -annotate +0+95 'Turnos · Puntos · Premios' \
  -alpha off -strip PNG24:store/play/feature-graphic.png

# Ícono de la ficha de Play (512×512, PNG de 32 bits)
magick assets/brand/app_icon.png -resize 512x512 -alpha set -background none -strip \
  PNG32:store/play/icon-512.png

# Ícono 1024 para App Store (sin alfa)
magick assets/brand/app_icon.png -resize 1024x1024 -alpha off -strip \
  PNG24:store/app-store/icon-1024.png
```

El ícono va **full-bleed y con las esquinas rectas**: las dos tiendas aplican su propia
máscara (Play la redondea, iOS le pone el vidrio de Liquid Glass). Redondearlo a mano
deja un halo.

## Medir los textos

Los límites de las tiendas son duros y el editor no siempre avisa. Para contar:

```bash
# caracteres y bytes de un campo (App Store mide keywords en BYTES, no en caracteres)
python3 -c "s=open('/dev/stdin').read().strip(); print(len(s),'chars /',len(s.encode()),'bytes')" <<'EOF'
<pegar el texto acá>
EOF
```

Medidos el 10/9/2026: nombre 20/30 · subtítulo 24/30 · promocional 163/170 ·
descripción 2.058/4.000 · keywords 90/100 bytes · notas del revisor 2.107/4.000 bytes ·
descripción breve de Play 74/80.

## Lo que falta y no es código

Está en `ENTREGA.md` y en las dos fichas, pero lo más urgente para poder enviar:

1. **Deployar el dashboard**: `https://monacobarber.vercel.app/soporte` y
   `/eliminar-cuenta` dan **404** al 10/9/2026 (las páginas están en el repo, sin
   deployar). Apple pide una Support URL que funcione y Play pide la URL de borrado de
   cuenta en Seguridad de los datos.
2. **Registrar el nombre "Monaco Barber Studio"** en App Store Connect: "Monaco" a secas
   está tomado (`com.getmeback.monaco`).
3. Completar `RESPONSABLE` (razón social, CUIT, domicilio) en
   `MonacoSmartBarber/src/app/soporte/contacto.tsx`: hoy son placeholders y se pintan en
   ámbar en las páginas legales.
