# App Store Connect — ficha de Monaco (para copiar y pegar)

Actualizado el 10/sep/2026. Todo lo de acá va tal cual en App Store Connect.
Los límites de caracteres están medidos (`store/README.md` explica cómo).

---

## 1. App Information

| Campo | Valor |
|---|---|
| **Name** (≤30) | `Monaco Barber Studio` — 20 caracteres |
| **Subtitle** (≤30) | `Turnos, puntos y premios` — 24 caracteres |
| **Bundle ID** | `com.monacobarber.monacoMobile` (el del proyecto Xcode; en Android el applicationId es `com.monacobarber.monaco_mobile`) |
| **Primary Language** | Español (México) — **no existe español de Argentina** en App Store Connect; es el que Apple usa para Latinoamérica |
| **Primary Category** | Estilo de vida (Lifestyle) |
| **Secondary Category** | Salud y forma física (Health & Fitness) — opcional |
| **Content Rights** | No, salvo los nombres y logos de los comercios con convenio, que se muestran con su acuerdo (hoy ninguno tiene logo cargado) |
| **Age Rating** | 4+ (respuestas en §5) |
| **Copyright** | `2026 Monaco Barber Studio` |

### Por qué el nombre NO es "Monaco" a secas

`Monaco` **ya está tomado en el App Store**: `com.getmeback.monaco`, de Margarita
Kotelnikova, categoría Health & Fitness
(https://apps.apple.com/ar/app/monaco/id6478142134). Verificado el 10/9/2026 contra la
iTunes Search API en los storefronts de Argentina y Estados Unidos; también aparecen
"Monaco Info", "Monaco Expert", "Monaco Bus", "Monaco Bike" y "Yacht Club de Monaco".
Apple exige nombre único a nivel mundial: al crear el registro con "Monaco" devuelve
*"The App Name you entered is already being used"*.

`Monaco Barber Studio` **no tiene ninguna coincidencia** en el App Store (búsqueda
`monaco barber`, 0 resultados en ar y us). Es además la marca real del negocio
(`AppConstants.brandName`).

**El nombre en el ícono del teléfono sigue siendo "Monaco"** (`CFBundleDisplayName` en
`ios/Runner/Info.plist` y `@string/app_name` en Android): el nombre de la ficha y el del
dispositivo son campos distintos y pueden diferir. No hay que tocar el binario.

Plan B si Apple igual objeta por similitud: `Monaco Barber Studio Córdoba`.

### Por qué la categoría secundaria no es "Compras"

En la app no se compra nada: la seña de Mercado Pago es un pago por un servicio del
mundo real, fuera de la app (guideline 3.1.3(e)). Apple no tiene categoría "Belleza";
las apps de peluquería/barbería viven en Estilo de vida, y Salud y forma física es la
secundaria más cercana para cuidado personal. Se puede dejar vacía sin costo.

---

## 2. URLs

| Campo | Valor | Estado |
|---|---|---|
| **Support URL** (obligatoria) | `https://monacobarber.vercel.app/soporte` | **404 al 10/9/2026 — hay que deployar** |
| **Marketing URL** (opcional) | `https://monacobarberstudio.com` | 200, sitio real del negocio |
| **Privacy Policy URL** (obligatoria) | `https://monacobarber.vercel.app/privacidad` | 200 |
| Términos (en la ficha, opcional; en la app ya está enlazado) | `https://monacobarber.vercel.app/terminos` | 200 |
| Borrado de cuenta (Play lo pide como campo; Apple lo revisa dentro de la app) | `https://monacobarber.vercel.app/eliminar-cuenta` | **404 al 10/9/2026 — hay que deployar** |

Si el dueño conecta un dominio propio (p. ej. `app.monacobarberstudio.com`), hay que
cambiar las cuatro URLs acá **y** las que la app abre desde Perfil
(`AppConstants` en `lib/core/utils/constants.dart`).

---

## 3. Textos

### Promotional Text (≤170) — se puede cambiar sin subir una versión nueva

```
Reservá tu turno, mirá la fila en vivo de cada sucursal y sumá puntos en cada corte para canjearlos por descuentos, cortes gratis y beneficios en comercios amigos.
```

### Description (≤4000)

```
Monaco Barber Studio es la app de nuestras barberías en Córdoba. Reservá tu turno, mirá cómo está la fila antes de salir de tu casa, sumá puntos en cada corte y canjealos por premios.

TURNOS EN TRES PASOS
- Elegí sucursal, servicio y horario. Sólo vas a ver los horarios que están realmente libres.
- Podés elegir tu barbero o dejar que te asignemos el que esté disponible ese día.
- Te confirmamos por WhatsApp apenas reservás y te recordamos el turno antes de que llegue.
- Cancelás desde la app, sin tener que llamar a nadie.

LA FILA, EN VIVO
- Mirá el estado de cada sucursal: sin espera, espera corta, movimiento moderado o alta demanda.
- Así elegís a dónde ir y llegás justo cuando te toca, en vez de esperar sentado.

PUNTOS Y CATEGORÍAS
- Cada corte suma puntos.
- Cuanto más venís, más alta es tu categoría —Bronce, Plata, Oro y Platinum— y más puntos sumás por visita.
- En la app ves tu saldo, cuándo vencen tus puntos y cuánto te falta para el próximo nivel.

PREMIOS Y BENEFICIOS
- Canjeá tus puntos por descuentos, cortes gratis y productos de Monaco.
- Sumá los beneficios de los comercios amigos, que son sin costo.
- Cada premio te queda guardado con un código QR: lo mostrás en el local y listo.

INVITÁ A UN AMIGO
- Compartí tu código de invitación: tu amigo entra con un descuento en su primer corte y vos sumás puntos cuando viene.

AVISOS QUE SIRVEN
- Recordatorio de tu turno, premios nuevos y aviso cuando tus puntos están por vencer.
- Vos elegís qué querés recibir desde Perfil.

RESERVA CON SEÑA
- Algunas sucursales piden una seña para confirmar el turno online. Se paga con Mercado Pago, se descuenta del precio final y te explicamos las condiciones antes de pagar.

ENTRAR ES FÁCIL
- Con tu número de teléfono (te mandamos un código por WhatsApp), con Google o con Apple.
- También podés mirar la app sin crear una cuenta.
- Podés borrar tu cuenta desde Perfil cuando quieras.

NUESTRAS SUCURSALES
Caseros, Paraná y Rondeau — Córdoba, Argentina.

Escribinos por WhatsApp al +54 9 351 769-1830 o entrá a monacobarberstudio.com
```

### Keywords (≤100 bytes, separadas por coma, sin espacios)

```
barberia,turnos,corte,peluqueria,cita,puntos,premios,fidelidad,cordoba,barba,reservar,fila
```

Reglas que se respetaron: no se repite ninguna palabra del nombre de la app
("monaco", "barber", "studio") ni de la categoría; sin espacios después de la coma
(cuentan como bytes); sin plurales redundantes; sin acentos (Apple pliega acentos en la
búsqueda y cada `í` cuesta 2 bytes).

### What's New in This Version (primera versión)

```
Primera versión de la app de Monaco Barber Studio: turnos online, fila en vivo, puntos, categorías y premios.
```

---

## 4. App Review Information

**Sign-in required: SÍ.** Cuenta demo (no expira, no manda WhatsApp):

| Campo | Valor |
|---|---|
| User name | `1100000000` |
| Password | `123456` |

**Notes** (≤4000 bytes) — copiar tal cual:

```
La app es de una barbería de Córdoba, Argentina. Todo el contenido está en español.

CÓMO ENTRAR (cuenta de demostración; no hace falta WhatsApp)
1. En la pantalla de bienvenida, tocar "Usar mi número de teléfono".
2. Ingresar el número 1100000000 y tocar Continuar.
3. El código de verificación es 123456. Es un número de prueba: el servidor NO envía ningún mensaje de WhatsApp y el código es fijo.
4. Si en cambio se usa "Continuar con Apple", después de autorizar la app se pide un teléfono: ingresar el mismo 1100000000 y el mismo código 123456.

SIN CUENTA (guideline 5.1.1)
"Seguir mirando" entra como invitado. Sin cuenta se pueden ver el inicio, las sucursales con la fila en vivo, la cartelera y la vidriera de premios. El pedido de cuenta aparece recién al tocar una acción personal (reservar, canjear, ver mis turnos), y siempre con la opción "Ahora no".

PARA PROBAR UNA RESERVA
Elegir la sucursal Caseros o Rondeau: ahí el turno se confirma sin ningún pago. La sucursal Paraná pide una seña por Mercado Pago y abre el navegador; conviene evitarla. El turno se puede cancelar desde Turnos > el turno > Cancelar.

POR QUÉ NO HAY COMPRAS DENTRO DE LA APP
Lo único que se paga es una seña de un corte de pelo, que es un servicio del mundo real prestado en el local. Guideline 3.1.3(e): en ese caso se deben usar métodos de pago distintos de las compras dentro de la app. Se cobra con Mercado Pago, en el navegador del sistema; la app nunca ve los datos de la tarjeta.

BORRAR LA CUENTA (guideline 5.1.1(v))
Perfil > Eliminar mi cuenta, dentro de la app. También desde https://monacobarber.vercel.app/eliminar-cuenta

PERMISOS
- Notificaciones: recordatorios de turno y avisos de premios. Opcional.
- Ubicación aproximada: sólo para ordenar las sucursales por cercanía en el primer paso de la reserva. Es opt-in (se pide al tocar "Ordenar por cercanía") y la app funciona igual sin ella.
- Face ID: opcional, para bloquear el acceso a la app. Se resuelve en el dispositivo.

CONTACTO
WhatsApp +54 9 351 769-1830 - studios.sys.work@gmail.com - monacobarberstudio.com
```

**Contact Information**: nombre, apellido, teléfono en formato internacional
(`+54 9 351 769-1830`) y email del dueño. Lo completa él.

---

## 5. Age Rating — cuestionario nuevo (obligatorio desde el 31/1/2026)

Apple reemplazó el cuestionario viejo y agregó los tramos 13+/16+/18+
(https://developer.apple.com/news/?id=ks775ehf). Respuestas para esta app:

| Pregunta | Respuesta | Por qué |
|---|---|---|
| Violencia (dibujada, realista, sexual, prolongada) | Ninguna | — |
| Contenido sexual o desnudez | Ninguno | — |
| Desnudez con fines educativos/médicos | No | — |
| Blasfemias o humor grosero | Ninguno | — |
| Alcohol, tabaco o drogas | Ninguno | Los convenios con bares que aparecen en Premios los carga el negocio y no promocionan consumo |
| Juegos de azar simulados / apuestas reales | No | No hay ruleta ni sorteos en la app |
| Terror / temas de miedo | Ninguno | — |
| Temas médicos o de tratamiento | No | — |
| **In-app controls (controles parentales)** | No | La app no tiene controles parentales |
| **Capabilities → Unrestricted web access** | **No** | Sólo abre URLs concretas en el navegador del sistema (Mercado Pago, WhatsApp, mapas, política de privacidad). No hay navegador embebido ni entrada de URL libre |
| **Capabilities → User-generated content** | No | Las reseñas y los comentarios van al negocio; ningún usuario ve lo que escribió otro. La cartelera la carga el negocio |
| **Capabilities → Messaging / chat entre usuarios** | No | — |
| **Capabilities → Ubicación compartida con otros usuarios** | No | La ubicación se usa en el dispositivo para ordenar sucursales |
| Compras dentro de la app | No | La seña es un servicio del mundo real, por Mercado Pago |
| Publicidad | No hay | — |

**Resultado esperado: 4+.**

---

## 6. Precio y disponibilidad

- **Precio**: Gratis (Tier 0). Sin compras dentro de la app.
- **Disponibilidad**: Argentina. (Se puede publicar en todos los países sin costo técnico
  —el alta admite otros prefijos telefónicos— pero el negocio son tres locales de
  Córdoba: limitarlo evita descargas que se desinstalan a los dos minutos y reseñas de
  una estrella de gente que no puede usarlo.)
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false` ya está en el Info.plist;
  App Store Connect no vuelve a preguntar.

---

## 7. Capturas (App Previews and Screenshots)

- Tamaño **6.9"** (iPhone 17 Pro Max): `store/capturas/ios-6.9/*.png`, seis archivos de
  **1320×2868**, PNG sin canal alfa.
- Apple pide 6.9" y con eso alcanza: las genera para el resto de los tamaños. Si la
  ficha exige además 6.5", se pueden derivar con `magick <in> -resize 1242x2688! <out>`.
- Orden sugerido en la ficha (la primera es la que se ve en los resultados de búsqueda):

  1. `02_inicio.png` — la tarjeta de puntos, el turno y la fila en vivo: es la app entera en una pantalla.
  2. `04_turno.png` — reservar turno, paso Día y horario.
  3. `03_sucursales.png` — la fila en vivo de las tres sucursales.
  4. `05_premios.png` — premios y beneficios.
  5. `06_categoria.png` — categorías del programa.
  6. `01_bienvenida.png` — la puerta de entrada.

Las capturas salen del simulador con la app real y datos de ejemplo de una persona
**ficticia** ("Martín", 351 555-0123): ver `store/README.md` para regenerarlas.
