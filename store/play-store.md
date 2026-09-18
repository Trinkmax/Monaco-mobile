# Google Play Console — ficha de Monaco (para copiar y pegar)

Actualizado el 10/sep/2026. Idioma de la ficha: **Español (Latinoamérica) — es-419**
(Play no tiene es-AR; es-419 es el que corresponde). Si se agrega un segundo idioma,
que sea "Español (España)" con el mismo texto, no una traducción distinta.

---

## 1. Ficha de Play Store (Store listing)

| Campo | Valor |
|---|---|
| **Nombre de la app** (≤30) | `Monaco Barber Studio` — 20 caracteres |
| **Categoría** | Belleza (`Beauty`) |
| **Etiquetas** (hasta 5) | Barbería · Belleza · Reserva de citas · Programas de fidelidad · Estilo de vida |
| **Email de contacto** | `studios.sys.work@gmail.com` |
| **Teléfono** (opcional) | `+54 9 351 769-1830` |
| **Sitio web** | `https://monacobarberstudio.com` |
| **Política de privacidad** | `https://monacobarber.vercel.app/privacidad` |

El título es el mismo que en App Store a propósito: Play no exige nombre único, pero
publicar "Monaco" a secas compite con la app homónima de una clínica y no dice qué es.

### Descripción breve (≤80)

```
Turnos, fila en vivo, puntos y premios de las barberías Monaco en Córdoba.
```

### Descripción completa (≤4000)

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

---

## 2. Gráficos

| Recurso | Archivo | Requisito de Play |
|---|---|---|
| Ícono de la ficha | `store/play/icon-512.png` | 512×512, PNG de 32 bits, ≤1 MB. **Esquinas rectas: Play aplica su propia máscara redondeada** |
| Gráfico de la función (obligatorio) | `store/play/feature-graphic.png` | 1024×500, PNG de 24 bits o JPEG, sin transparencia |
| Capturas de teléfono (mín. 2, máx. 8) | `store/capturas/play/*.png` | 1080×2160, PNG de 24 bits sin alfa. **Relación exactamente 2:1** |

**Por qué las capturas de Play no son las mismas que las de App Store**: Play rechaza
una captura cuyo lado mayor supere el doble del menor, y un iPhone 17 Pro Max da
2868/1320 = 2,17 (un Pixel 7 Pro, 2,17; un Pixel 8, 2,22). Las de `capturas/play/` son
la misma captura escalada a 2160 de alto y centrada sobre un fondo #0A0A0A hasta llegar
a 1080 de ancho: el fondo de la app también es #0A0A0A, así que el relleno no se ve.

Orden sugerido: `02_inicio`, `04_turno`, `03_sucursales`, `05_premios`, `06_categoria`,
`01_bienvenida`. Con seis capturas de 1080 px de ancho la app queda elegible para las
promociones de Play (piden 4 o más).

---

## 3. Contenido de la app

### Acceso a la app (App access)

**"Todas las funciones o parte de ellas están restringidas"** → agregar estas
instrucciones:

```
Nombre de la instrucción: Cuenta de demostración (login por código)

Usuario: 1100000000
Contraseña: 123456

Pasos:
1. La bienvenida son tres pantallas de presentación: tocar "Continuar" dos veces. En la tercera aparecen las opciones de ingreso.
2. Tocar "Usar mi número de teléfono", ingresar el número 1100000000 y tocar Continuar.
3. El código de verificación es 123456. Es un número de prueba: el servidor no envía ningún mensaje de WhatsApp y el código es fijo.
4. Si se usa "Continuar con Google", después se pide un teléfono: ingresar el mismo 1100000000 y el mismo código 123456.

Sin cuenta: en la tercera pantalla de bienvenida, "Seguir mirando" entra como invitado y deja ver el inicio, las sucursales con la fila en vivo y la vidriera de premios.

Para probar una reserva conviene elegir la sucursal Caseros o Rondeau: ahí el turno se confirma sin ningún pago. La sucursal Paraná pide una seña por Mercado Pago y abre el navegador.

La cuenta se puede borrar desde Perfil > Eliminar mi cuenta.
```

### Anuncios

**No, la app no contiene anuncios.**

### Clasificación de contenido (cuestionario IARC)

| Pregunta | Respuesta |
|---|---|
| Categoría de la app | Utilidad, productividad, comunicación u otra (no es un juego) |
| Violencia | No |
| Sexualidad | No |
| Lenguaje inapropiado | No |
| Sustancias controladas (drogas, alcohol, tabaco) | No |
| Juegos de azar / apuestas | No |
| ¿Permite a los usuarios interactuar o intercambiar contenido? | No |
| ¿Comparte la ubicación del usuario con otros usuarios? | No |
| ¿Permite comprar bienes digitales? | No |
| ¿Muestra contenido generado por usuarios? | No |
| Miedo / contenido perturbador | No |
| ¿Es una app de noticias? | No |

Resultado esperado: **Para todos / Everyone (PEGI 3, ESRB Everyone)**.

### Público objetivo y contenido

- **Grupos de edad**: `18 y más`. La app es de una barbería: no está diseñada para
  menores y declarar 13+ o menos activa la política de Familias (obliga a un montón de
  requisitos extra y a la revisión de Diseñada para Familias).
- **¿Atrae a los niños?** No.
- **Diseñada para Familias**: No.

### Seguridad de los datos

Ver `store/data-safety.md` (respuesta por respuesta).

### Otras declaraciones

| Declaración | Respuesta |
|---|---|
| App gubernamental | No |
| Apps financieras | "Mi app no ofrece funciones financieras" — la seña es el pago de un servicio a través de Mercado Pago, no un producto financiero |
| Salud | No |
| ID de publicidad (Advertising ID) | **No se usa.** La app no incluye ningún SDK de publicidad; si Play detecta el permiso `com.google.android.gms.permission.AD_ID` por alguna dependencia transitiva, hay que declararlo o removerlo con `tools:node="remove"` |
| Permisos de acceso especiales | Ninguno (nada de `MANAGE_EXTERNAL_STORAGE`, `SMS`, `QUERY_ALL_PACKAGES`) |
| COVID-19 / seguimiento de contactos | No |

---

## 4. Precio, distribución y versión

- **Gratis**, sin compras en la aplicación. La seña de Mercado Pago **no** va por
  facturación de Play: Play exime expresamente los bienes y servicios físicos —un corte
  de pelo es un servicio prestado en persona—, así que usar Google Play Billing para eso
  sería el error, no lo contrario.
- **Países**: Argentina.
- **Formato**: Android App Bundle (`flutter build appbundle --release`), firmado con el
  keystore de `android/key.properties` (ver `ENTREGA.md`) y con Play App Signing.
- `targetSdk` viene heredado de Flutter 3.38.4 (**36**), que es lo que Play exige para
  cualquier subida desde el 31/8/2026.
- **Novedades de esta versión** (≤500):

```
Primera versión de la app de Monaco Barber Studio: turnos online, fila en vivo de cada sucursal, puntos, categorías y premios.
```
