# Publicar Monaco en App Store y Google Play — guía paso a paso

> Escrita el 10 de septiembre de 2026 para una primera publicación. Cada paso dice
> **dónde** se hace (qué sitio, qué menú), **qué** poner y **cómo verificar** que quedó bien.
> Los comandos se corren desde `Monaco-mobile/` en esta Mac.
>
> Orden recomendado: **Parte 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7**. Las partes 1 y 2 (cuentas)
> tienen esperas de días: arrancalas hoy y seguí con el resto mientras se aprueban.

---

## Parte 0 — Qué ya está hecho y qué falta (resumen)

**Hecho en el repo (código, config nativa, assets, textos):** ver `ENTREGA.md` §"Nativo y tiendas".
Compila en release para iOS (Xcode 26.3, SDK iOS 26) y Android (targetSdk 36, 16 KB, AAB).
Capturas, ícono 512, feature graphic y todos los textos de las fichas están en `store/`.

**Lo que sólo podés hacer vos (cuentas, credenciales, decisiones):**

| # | Qué | Dónde | Bloquea |
|---|---|---|---|
| 1 | Apple Developer Program (USD 99/año) | developer.apple.com | TODO iOS |
| 2 | Cuenta de Google Play Console (USD 25 una vez) | play.google.com/console | TODO Android |
| 3 | Keystore de Android (`scripts/crear-keystore.sh`) | esta Mac | subir a Play |
| 4 | Proyecto Firebase + `flutterfire configure` + APNs key + `FCM_SERVICE_ACCOUNT_JSON` | console.firebase.google.com | push (opcional para publicar) |
| 5 | Google Sign-In: 3 clients OAuth + REVERSED_CLIENT_ID + secret `GOOGLE_CLIENT_IDS` | console.cloud.google.com + Supabase | botón "Continuar con Google" — **opcional para la primera versión**: sin él, el botón no aparece y iOS entra con Apple + teléfono, Android con teléfono |
| 6 | Sign in with Apple: capability en el App ID + secret `APPLE_BUNDLE_IDS` (+ key .p8 para revocar) | developer.apple.com + Supabase | botón "Continuar con Apple" (obligatorio si hay Google) |
| 7 | Secrets `AUTH_TEST_PHONES=1100000000=123456` y `OTP_PEPPER` | Supabase → Edge Functions → Secrets | cuenta demo del revisor |
| 8 | Completar los datos del responsable y **deployar el dashboard** con las cinco páginas legales | MonacoSmartBarber | URLs de las fichas |
| 9 | Decidir: nombre en tiendas ("Monaco Barber Studio"), países, seña apagada durante la revisión | — | ficha |

Sobre el punto 8, para que no quede en "ya está en el repo": las páginas
`/privacidad`, `/terminos`, `/soporte`, `/eliminar-cuenta` y `/arrepentimiento` existen en
`MonacoSmartBarber/src/app/`, pero **`/soporte` y `/eliminar-cuenta` daban 404 en
`monacobarber.vercel.app` el 10/9/2026**: están escritas y sin deployar. Apple pide una Support URL
que funcione y Play pide la URL de borrado de cuenta en Seguridad de los datos, así que sin ese
deploy las dos fichas se traban. Y hay que completar `RESPONSABLE` (razón social, CUIT, domicilio)
en `MonacoSmartBarber/src/app/soporte/contacto.tsx`: hoy son placeholders y las páginas los pintan
en ámbar, o sea que el revisor los ve.

Chequeo automático de buena parte de lo anterior, antes de subir:

```bash
./scripts/preflight-tiendas.sh
```

Falla con ✗ y el motivo en cada ítem que falte. Hasta que dé todo ✓, no subas nada. Lo que **no**
puede chequear solo, y tenés que verificar vos: que las páginas legales estén realmente publicadas
(punto 8), que la cuenta demo `1100000000` entre de verdad desde la app (punto 7) y que el push
llegue a un teléfono (Parte 4).

---

## Antes de empezar — dónde quedó el trabajo y cómo publicar las páginas

Todo lo de esta entrega está commiteado en una rama llamada **`publicacion-tiendas`**, en los tres
repos (`Monaco-mobile`, `MonacoSmartBarber` y la carpeta raíz `MSB_FULL`). **No está en `main` a
propósito**: en `MonacoSmartBarber`, un push a `main` deploya a producción solo (Vercel), y el
sistema está en uso en los locales. Nada de la rama llega a producción hasta que vos la juntes con
`main`.

**Lo que YA está en producción** (se aplicó el 10/9/2026, no hay que hacer nada): el arreglo del
borrado de cuenta en la base, las funciones `client-auth` y `delete-client-account` nuevas, y la
cuenta demo del revisor cargada.

**Lo que NO está en producción y la ficha necesita**: las páginas `/soporte` y `/eliminar-cuenta`
(hoy dan 404) y la política de privacidad nueva. Para publicarlas:

1. Completá los datos del responsable en
   `MonacoSmartBarber/src/app/soporte/contacto.tsx` (razón social, CUIT y domicilio: hoy dicen
   `[RAZÓN SOCIAL]`, `[CUIT]`, `[DOMICILIO LEGAL…]`).
2. **Hacelo con el local cerrado** (después de las 21). El cambio no toca el panel del barbero, el
   kiosko ni la fila, pero cualquier deploy es un deploy.
3. En la Terminal:
   ```bash
   cd ~/MSB_FULL/MonacoSmartBarber
   git checkout main
   git merge publicacion-tiendas
   git push origin main        # esto deploya: Vercel tarda 2–3 minutos
   ```
4. Verificá que las cinco páginas respondan (tiene que decir 200 en las cinco):
   ```bash
   for u in privacidad terminos soporte eliminar-cuenta arrepentimiento; do
     printf "%-16s " $u; curl -s -o /dev/null -w "%{http_code}\n" https://monacobarber.vercel.app/$u
   done
   ```
5. Abrí el panel del barbero en una tablet y fijate que la fila muestre a los clientes.
6. **Si algo se ve mal, volvé atrás en un minuto sin tocar código**: vercel.com → el proyecto →
   *Deployments* → el deploy anterior → *⋯* → **Promote to Production** (o *Instant Rollback*).
   Eso restaura la versión previa al instante; después se revisa con calma.

Para la app y la carpeta raíz no hay apuro ni riesgo (no deployan nada), pero conviene juntarlas
igual para no perder el trabajo: `git checkout main && git merge publicacion-tiendas && git push`
dentro de `Monaco-mobile` y dentro de `MSB_FULL`.

---

## Parte 1 — Cuenta de Apple Developer (empezá hoy: tarda 1 a 3 días, o semanas si es empresa)

1. Entrá a <https://developer.apple.com/programs/enroll/> con el Apple ID que va a ser dueño de la app
   (recomendado: uno del negocio, con verificación en dos pasos activada, no uno personal prestado).
2. Elegí el tipo:
   - **Individual**: se aprueba en 24–48 h. Verificación de identidad desde la app "Apple Developer"
     del iPhone (te pide DNI y una selfie). En la tienda aparece tu nombre como "vendedor".
   - **Organización**: aparece la razón social como vendedor. Exige número **D-U-N-S** (gratis, se pide
     en <https://developer.apple.com/enroll/duns-lookup/>, tarda hasta 30 días hábiles), sitio web
     y una persona con "autoridad legal para firmar". Sirve también para Play (organización).
3. Pagá los USD 99. Cuando llegue el mail "Welcome to the Apple Developer Program", seguí.
4. **Xcode → Settings (⌘,) → Accounts → +** → tu Apple ID.
   **Si te inscribiste como *Individual* con el mismo Apple ID que ya usabas gratis, NO aparece un
   Team nuevo: el que tenías (`A3WAXVR55Z`) pasa a ser el del programa pago y conserva su ID.** En
   ese caso no hay nada que cambiar en el proyecto — es lo que pasó el 14/9/2026. Confirmalo en
   developer.apple.com → Account → **Membership details** (ahí figuran Team ID, tipo de programa y
   vencimiento). Sólo si el ID que ves ahí es distinto del que tiene el proyecto, corré:
   ```bash
   sed -i '' 's/A3WAXVR55Z/TU_TEAM_ID/g' ios/Runner.xcodeproj/project.pbxproj
   ```
5. En <https://developer.apple.com/account/resources/identifiers/list> → **Identifiers → +**:
   - *App IDs → App → Continue*. Description `Monaco`, Bundle ID **Explicit**
     `com.monacobarber.monacoMobile`.
   - Capabilities: tildá **Push Notifications** y **Sign in with Apple** (en Sign in with Apple
     → Edit → "Enable as a primary App ID"). Register.
6. **Keys → +**: nombre `Monaco APNs`, tildá *Apple Push Notifications service (APNs)* → Continue →
   Register → **Download** (el `.p8` se baja UNA sola vez: guardalo con backup). Anotá el **Key ID**
   y tu **Team ID** (arriba a la derecha). Lo vas a subir a Firebase (Parte 4).
7. **Keys → +** otra vez: nombre `Monaco Sign in with Apple`, tildá *Sign in with Apple* →
   Configure → Primary App ID = `com.monacobarber.monacoMobile` → Save → Register → Download.
   Este `.p8` + Key ID + Team ID van a los secrets `APPLE_PRIVATE_KEY`, `APPLE_KEY_ID`,
   `APPLE_TEAM_ID` de la edge function `client-auth` (Parte 6) para poder revocar el acceso
   cuando un cliente borra su cuenta (Apple lo exige).
8. Abrí `ios/Runner.xcworkspace` en Xcode → target Runner → **Signing & Capabilities** → tildá
   *Automatically manage signing* y elegí el Team. Xcode crea el perfil de aprovisionamiento solo.
   Si dice "Provisioning profile doesn't include the Sign in with Apple / Push entitlement", volvé
   al paso 5 y verificá que las dos capabilities están tildadas en el App ID.

---

## Parte 2 — Cuenta de Google Play Console (empezá hoy)

1. <https://play.google.com/console/signup> con una cuenta de Google del negocio.
2. Tipo de cuenta:
   - **Personal**: USD 25, DNI + verificación de mail y teléfono. **Restricción importante**: para
     publicar en producción una cuenta personal nueva tiene que correr primero una **prueba cerrada
     con al menos 12 testers durante 14 días seguidos** y después pedir "acceso a producción"
     (Google lo revisa en hasta 7 días). O sea, mínimo **3 semanas** entre la primera subida y la
     publicación. Empezá la prueba cerrada apenas tengas el AAB (Parte 7).
   - **Organización**: exige D-U-N-S y muestra públicamente dirección y teléfono del negocio en la
     ficha. No tiene el requisito de los 12 testers.
3. Completá la verificación de identidad cuando te la pida (puede tardar 1–3 días).

---

## Parte 3 — Firmar Android (5 minutos, una sola vez en la vida de la app)

El keystore es la llave con la que se firma la app. **Si se pierde, no se puede actualizar la app**
(con Play App Signing, Google guarda la llave "de firma" y vos la "de subida": perder la de subida
se arregla con un reset por soporte, pero es un trámite).

```bash
./scripts/crear-keystore.sh
```

Crea `~/.monaco-keys/monaco-release.jks`, escribe `android/key.properties` (ignorado por git) y
te imprime el **SHA-1** y **SHA-256** del certificado. Guardá el `.jks` y las contraseñas en un
gestor de contraseñas y hacé un backup fuera de la Mac. Copiá el SHA-1: lo necesitás en la Parte 5.

Verificación: `./scripts/preflight-tiendas.sh` tiene que mostrar ✓ en "key.properties".

---

## Parte 4 — Firebase (push). Opcional para publicar, pero conviene hacerlo antes

Sin esto la app funciona y se puede publicar: la sección de notificaciones del sistema **no se
muestra** (no aparece apagada ni con un "no disponible" — un interruptor que no hace nada se lee
como una app a medias), pero no llegan recordatorios de turno ni campañas. El mismo `flutterfire
configure` prende **Crashlytics**, que es como vas a enterarte de los errores que le pasan a la
app en el teléfono de un cliente: hasta que Firebase exista, la app no reporta nada a ningún lado.

1. <https://console.firebase.google.com> → **Crear proyecto** → nombre `Monaco` → Google Analytics:
   podés desactivarlo (no se usa).
2. Instalá las herramientas (una vez):
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. Desde `Monaco-mobile/`:
   ```bash
   flutterfire configure --project=<id-del-proyecto> \
       --platforms=ios,android \
       --ios-bundle-id=com.monacobarber.monacoMobile \
       --android-package-name=com.monacobarber.monaco_mobile
   ```
   Eso reescribe `lib/firebase_options.dart` (sin los `PLACEHOLDER`), deja
   `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist`. Abrí Xcode y verificá
   que `GoogleService-Info.plist` esté dentro del target Runner (si está en gris/sin tilde, arrastralo
   al grupo Runner con "Add to targets: Runner").
4. Firebase → ⚙ **Project settings → Cloud Messaging → Apple app configuration → APNs
   Authentication Key → Upload**: el `.p8` de la Parte 1 paso 6, con su Key ID y el Team ID.
5. Firebase → ⚙ **Project settings → Service accounts → Generate new private key** → se baja un
   JSON. Cargalo como secret de la edge function `send-push`:
   ```bash
   supabase login
   supabase secrets set --project-ref gzsfoqpxvnwmvngfoqqk \
     FCM_SERVICE_ACCOUNT_JSON="$(cat ~/Downloads/monaco-xxxx-firebase-adminsdk-xxxx.json)"
   ```
   (o desde <https://supabase.com/dashboard/project/gzsfoqpxvnwmvngfoqqk/functions> → Secrets).
6. Firebase → ⚙ **Project settings → Your apps → Android app → Add fingerprint**: pegá el SHA-1
   (y SHA-256) del keystore de la Parte 3 y, más adelante, el de Play App Signing (Parte 7).
7. Probá: `flutter run --release` en tu iPhone (con el Team pago ya firma push) → Perfil →
   activá notificaciones → desde `/dashboard/app-movil` → Notificaciones mandá una campaña de prueba.

---

## Parte 5 — "Continuar con Google" (Google Cloud, 15 minutos)

> **Se puede publicar sin esto** (decidido el 18/9/2026 para no atar la revisión de Apple a Google
> Cloud). Con los dos client IDs vacíos la app **no dibuja** el botón de Google: en iOS se entra con
> Apple + teléfono y en Android sólo con teléfono, y la guideline 4.8 se cumple igual (Sign in with
> Apple es obligatorio sólo si hay *otro* login de terceros). El preflight lo marca como ⚠, no como
> ✗. Lo que **no** se puede es dejarlo a medias: o los dos client IDs + el URL scheme del `Info.plist`
> + el secret `GOOGLE_CLIENT_IDS`, o ninguno. Cuando se haga, va en una actualización (2.0.1).

Usamos el **mismo proyecto de Google Cloud que creó Firebase** (Firebase crea uno con el mismo id).

1. <https://console.cloud.google.com> → seleccioná el proyecto `Monaco` (arriba).
2. **APIs y servicios → Pantalla de consentimiento de OAuth** (ahora "Google Auth Platform →
   Branding"): tipo **Externo**, nombre de la app `Monaco Barber Studio`, mail de soporte, logo
   (`store/play/icon-512.png`), dominio autorizado `monacobarber.vercel.app`, links a
   `https://monacobarber.vercel.app/privacidad` y `/terminos`. Guardá. En **Audience** pasá el
   estado de "Testing" a **In production** (con los permisos básicos email/perfil NO hace falta
   verificación y no aparece la pantalla de "app no verificada"; si queda en Testing, sólo los
   usuarios de prueba pueden entrar).
3. **APIs y servicios → Credenciales → Crear credenciales → ID de cliente de OAuth**, tres veces:
   - Tipo **iOS**: nombre `Monaco iOS`, Bundle ID `com.monacobarber.monacoMobile`. Al crearlo
     te muestra el **Client ID** (`123-abc.apps.googleusercontent.com`) y el **iOS URL scheme**
     (`com.googleusercontent.apps.123-abc`, que es el mismo id invertido).
   - Tipo **Android**: nombre `Monaco Android (subida)`, package `com.monacobarber.monaco_mobile`,
     SHA-1 = el del keystore (Parte 3). Creá **otro** igual con el SHA-1 de **debug**
     (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`)
     para que funcione en `flutter run`, y **otro más** con el SHA-1 de **Play App Signing** cuando
     lo tengas (Parte 7, paso 6). Sin este último, Google no anda en la app instalada desde Play.
   - Tipo **Aplicación web**: nombre `Monaco server`. Es el "serverClientId": sin él Android no
     emite `id_token`.
4. Pegá los valores:
   - `ios/Runner/Info.plist`: reemplazá `com.googleusercontent.apps.PLACEHOLDER-REEMPLAZAR` por el
     iOS URL scheme del client de iOS (está marcado con "⚠️ PLACEHOLDER").
   - `.env.release` (copiá `.env.release.example`): `GOOGLE_IOS_CLIENT_ID=<client id de iOS>` y
     `GOOGLE_SERVER_CLIENT_ID=<client id Web>`. Los scripts de build los pasan como `--dart-define`.
   - Supabase → Edge Functions → Secrets:
     `GOOGLE_CLIENT_IDS=<ios>,<android-subida>,<android-debug>,<android-play>,<web>` (los cinco,
     separados por coma, sin espacios).
5. Verificación: `./scripts/preflight-tiendas.sh` → ✓ en Google; y en el teléfono, "Continuar con
   Google" tiene que abrir la hoja de Google y volver a la app.

---

## Parte 6 — "Continuar con Apple" + secrets de la cuenta demo (10 minutos)

Apple exige ofrecer Sign in with Apple si ofrecemos Google (guideline 4.8) y que funcione.

1. Supabase → Edge Functions → Secrets (o `supabase secrets set …`):
   ```
   APPLE_BUNDLE_IDS=com.monacobarber.monacoMobile
   APPLE_TEAM_ID=<Team ID>
   APPLE_KEY_ID=<Key ID de la key "Sign in with Apple" de la Parte 1 paso 7>
   APPLE_PRIVATE_KEY=<contenido del .p8, con los saltos de línea>
   AUTH_TEST_PHONES=1100000000=123456
   OTP_PEPPER=<32 caracteres al azar: openssl rand -hex 16>
   SIGNUP_TOKEN_SECRET=<otros 32: openssl rand -hex 16>
   ```
   Para `APPLE_PRIVATE_KEY` por CLI: `supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"`.

   Los tres de Apple (`APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`) **sí hacen falta y ya
   están programados** (10/9/2026). Sirven para lo que Apple exige desde junio de 2022: que al
   borrar la cuenta, Monaco desaparezca de *Ajustes → tu Apple ID → Iniciar sesión con Apple*. El
   circuito ya está armado de punta a punta — la app manda el código de autorización, la función
   `client-auth` lo canjea en el momento por un token de larga vida, y `delete-client-account` lo
   usa para revocar el acceso antes de borrar. Sin estos tres secretos ese último paso se saltea en
   silencio (se anota en el log y el borrado sigue: nadie se queda sin poder darse de baja), pero la
   app le queda listada al cliente para siempre y eso es motivo de rechazo por la 5.1.1(v).

   El `.p8` de *Sign in with Apple* es el de la Parte 1 paso 7 — **no** el de APNs del paso 6: son
   dos claves distintas y cada una sirve para una sola cosa.
2. Verificación: `./scripts/preflight-tiendas.sh` → ✓ en la línea de Apple (`client-auth · apple`).
   **La cuenta demo no la chequea el script**: probala vos desde la app, con el teléfono
   `1100000000` y el código `123456`. Es la que van a usar los revisores de Apple y Google, NO
   recibe WhatsApp (el código es fijo), y si no entra, Apple rechaza por la 2.1 — que es el motivo
   de rechazo más común de todos. Probá también, con esa misma cuenta, **eliminar la cuenta desde
   Perfil**: si quedara con una seña de Mercado Pago pagada sin resolver, el borrado se rechaza a
   propósito (hay que cancelar el turno primero) y el revisor vería una app que no deja borrar la
   cuenta, que es rechazo por la 5.1.1(v).

   **La cuenta demo ya viene cargada con qué mostrar** (10/9/2026): categoría Oro, 2.000 puntos y
   tres avisos en la bandeja. Así el revisor abre el Home y ve la tarjeta dorada, el progreso hacia
   Platinum y premios que puede canjear de verdad, en vez de una app en cero que se lee como si no
   funcionara. Está hecho **sin inventar cortes**: no hay ninguna visita falsa, así que la
   facturación, las comisiones y las estadísticas del negocio no se tocan. Se apoya en
   `client_loyalty_state.preview_until`, que hace que el programa de fidelización se vea encendido
   **sólo para ese cliente** aunque en el resto de Monaco siga apagado.

   Si el revisor borra la cuenta demo (es lo que hay que probar), se borra de verdad. Para
   recrearla: volvé a entrar con `1100000000` desde la app —eso la crea de nuevo— y después corré
   `MonacoSmartBarber/supabase/seeds/demo_reviewer.sql`, que es idempotente y trae la explicación
   de cada línea y de cómo revertirla.

---

## Parte 7 — Compilar y subir

### 7.1 Preflight

```bash
./scripts/preflight-tiendas.sh --ios   # sólo iOS: no exige el keystore de Android
./scripts/preflight-tiendas.sh         # las dos tiendas
flutter test                           # todo en verde
```

Los ⚠ no frenan el build pero hay que leerlos: "Firebase con PLACEHOLDER" significa sin push ni
Crashlytics, y "Google apagado" significa sin botón de Google.

### 7.2 Subir la versión

`pubspec.yaml` → `version: 2.0.0+20`. El `+20` es el **build number**: cada subida a App Store
Connect o a Play necesita uno **mayor** que el anterior (21, 22, …). El `2.0.0` es la versión visible.

### 7.3 Compilar los dos artefactos

```bash
./scripts/build-release.sh ios       # sólo el IPA (para mandar Apple primero)
./scripts/build-release.sh           # AAB + IPA, obfuscados
```

Deja `build/app/outputs/bundle/release/app-release.aab` y `build/ios/ipa/Monaco.ipa`
(más los símbolos en `build/symbols/<version>/`, guardalos: sirven para leer crashes).

**Copiá `build/symbols/<version>/` a donde tengas el keystore, apenas termina el build.** Los
binarios salen ofuscados, así que un error de la app en Crashlytics llega ilegible y sólo se
traduce con los símbolos de **ese** build (los de la `2.0.0+20` no sirven para la `+21`). `build/`
está ignorada por git y cualquier `flutter clean` se los lleva: si se pierden, los crashes de esa
versión quedan sin leer para siempre.

### 7.4 iOS — subir a App Store Connect

1. <https://appstoreconnect.apple.com> → **Apps → + → New App**:
   - Platforms: iOS. Name: **Monaco Barber Studio** ("Monaco" a secas ya está tomado en el App
     Store). Primary language: Spanish (Mexico) (es el español latino que ofrece Apple).
     Bundle ID: `com.monacobarber.monacoMobile`. SKU: `monaco-mobile`. User Access: Full.
2. Subir el build: instalá **Transporter** desde la Mac App Store, abrilo con tu Apple ID,
   arrastrá `build/ios/ipa/Monaco.ipa` → **Deliver**. (Alternativa: Xcode → Window → Organizer →
   el archive → Distribute App → App Store Connect → Upload.) Tarda 10–30 min en "procesarse".
3. **TestFlight** (recomendado antes de mandar a revisión): pestaña TestFlight → el build → Internal
   Testing → + grupo "Monaco" → agregá tu mail (y el de los barberos con Apple ID) → cada uno instala
   la app **TestFlight** en su iPhone y acepta la invitación. Probá TODO: entrar con teléfono,
   Google, Apple, reservar, cancelar, canjear, borrar cuenta.
4. Completar la ficha (pestaña **App Store**), copiando de `store/app-store.md`:
   - **App Information**: Subtitle, Category (primaria Lifestyle), Content Rights (No), **Age Rating
     → Edit**: respondé el cuestionario nuevo (las respuestas están en `store/app-store.md`;
     resultado esperado 4+).
   - **Pricing and Availability**: Free; Availability → sólo Argentina (o los países que quieras).
   - **App Privacy → Get Started**: Privacy Policy URL `https://monacobarber.vercel.app/privacidad`
     y las categorías de datos exactamente como dice `store/privacy-labels.md`.
   - **Version 2.0.0**: Screenshots 6.9" (arrastrá las 6 de `store/capturas/ios-6.9/`, ya con la
     medida exacta que pide Apple; si hay que rehacerlas, se regeneran con
     `integration_test/store_shots_test.dart` — receta en `store/README.md`), Promotional
     Text, Description, Keywords, Support URL `https://monacobarber.vercel.app/soporte`, Marketing URL
     (opcional), Version, Copyright `2026 Monaco Barber Studio`.
   - **Build**: + → elegí el build subido.
   - **App Review Information**: Sign-in required **ON** → User name `1100000000`, Password `123456`;
     Contact: tu nombre, teléfono y mail; **Notes**: pegá el texto de `store/app-store.md` → "Notas
     para el revisor" (explica el código fijo, el modo invitado, qué sucursal usar para reservar).
   - **Version Release**: "Manually release this version" (así elegís el día que sale).
   - Export Compliance: ya está declarado en el Info.plist (no usa cifrado no exento).
   - **Agreements**: en Business/Agreements aceptá el "Paid Apps Agreement"? NO hace falta (la app es
     gratis); sí aceptá el Free Apps si te lo pide. En **Compliance → Digital Services Act**: si no
     vas a vender en la Unión Europea, declará que no distribuís ahí (la app no se muestra en la UE).
5. **Add for Review → Submit to App Review**. La primera revisión tarda entre 24 h y 3 días.
   Los estados se ven en la app **App Store Connect** del iPhone (activá notificaciones).
6. Si rechazan: en Resolution Center te dicen la guideline y un screenshot. Se contesta ahí mismo
   y se resube. Los motivos más comunes para esta app y cómo evitarlos ya están cubiertos (modo
   invitado, borrado de cuenta, Sign in with Apple, cuenta demo).
7. Aprobada → **Release this version**. Aparece en el App Store en unas horas.

### 7.5 Android — subir a Google Play

1. <https://play.google.com/console> → **Crear app**: nombre **Monaco Barber Studio**, idioma
   predeterminado **Español (Latinoamérica)**, App, Gratis, aceptá las declaraciones.
2. Panel → **Configurar tu app** (lista de tareas; todas obligatorias):
   - **Política de privacidad**: `https://monacobarber.vercel.app/privacidad`.
   - **Acceso a la app**: "Toda o parte de la funcionalidad está restringida" → Agregar instrucciones:
     teléfono `1100000000`, código `123456`, y el texto de `store/play-store.md` → "App access".
   - **Anuncios**: No. **Clasificación de contenido**: cuestionario IARC (respuestas en
     `store/play-store.md`). **Público objetivo**: 18 o más. **Apps de noticias**: No.
     **Apps de seguimiento de contactos de COVID**: No. **Seguridad de los datos**: completá
     exactamente lo de `store/data-safety.md` (incluida la URL de borrado
     `https://monacobarber.vercel.app/eliminar-cuenta`). **Apps gubernamentales**: No.
     **Funciones financieras**: "no ofrece funciones financieras". **Salud**: No.
   - **Categoría y datos de contacto**: Categoría *Belleza*; mail de contacto; sitio
     `https://monacobarber.vercel.app/soporte`.
   - **Ficha de Play Store**: título, descripción breve y completa de `store/play-store.md`; ícono
     `store/play/icon-512.png`; feature graphic `store/play/feature-graphic.png`; capturas de
     teléfono: las de `store/capturas/play/` (mínimo 2, hasta 8).
3. **Pruebas → Pruebas internas → Crear versión**: subí `app-release.aab`. La primera vez Play te
   pregunta por la firma: aceptá **Play App Signing** (recomendado: Google guarda la llave de firma).
   Notas de la versión: "Primera versión". Guardar → Revisar → Iniciar lanzamiento. Agregá tu mail
   en "Testers" y abrí el link de opt-in desde el teléfono: instalás desde Play en minutos.
4. **Play App Signing SHA-1**: Configuración → **Integridad de la app → Firma de apps** → copiá el
   SHA-1 del "Certificado de clave de firma de la app" → creá el client OAuth de Android con ese
   SHA-1 (Parte 5 paso 3) y agregalo también en Firebase (Parte 4 paso 6). Sin esto, "Continuar con
   Google" falla en la app instalada desde Play (anda en la de `flutter run` y no en la de la tienda,
   que es un clásico).
5. **Si la cuenta es personal**: **Pruebas → Pruebas cerradas → Crear pista** → subí el mismo AAB
   → testers: creá una lista con 12+ mails de Gmail (barberos, familia, amigos) → cada uno acepta
   el link de opt-in e instala. Tienen que quedar inscriptos **14 días seguidos** (no hace falta que
   abran la app todos los días, pero que no se den de baja). Cumplidos los 14 días: Panel →
   **Solicitar acceso a producción** → cuestionario → Google responde en hasta 7 días.
6. **Producción → Crear versión** → subí el AAB (puede ser el mismo) → Países: Argentina →
   Revisar → **Iniciar lanzamiento en producción**. La revisión de una app nueva tarda entre 1 y
   7 días. Estado en la campana del Console y por mail.

---

## Parte 8 — Después de publicar

- **Actualizaciones**: subí el build number (`+21`), `./scripts/build-release.sh`, subí el IPA por
  Transporter y el AAB en Producción → Crear versión. Apple revisa cada actualización (suele ser
  más rápido que la primera); Play también.
- **Crashes**: con Firebase configurado, Crashlytics recibe los errores automáticamente
  (Firebase → Crashlytics). Los símbolos de las builds obfuscadas quedan en `build/symbols/`.
- **Reseñas**: App Store Connect → Ratings and Reviews; Play Console → Calificaciones y reseñas.
  Contestar mejora la posición.
- **Renovaciones**: Apple cobra USD 99 cada año (si vence, la app se despublica); Play no vence.
- **Nunca** pierdas: el keystore `.jks` y sus contraseñas, los `.p8` de Apple, el JSON de la
  service account de Firebase. Están todos fuera del repo a propósito.

---

## Apéndice A — Comandos que vas a usar

```bash
./scripts/preflight-tiendas.sh                 # ¿está todo listo para subir?
./scripts/preflight-tiendas.sh --sin-red       # ídem, sin consultar a Supabase (avión, sin internet)
./scripts/crear-keystore.sh                    # llave de Android (una sola vez)
./scripts/build-release.sh                     # AAB + IPA de producción
./scripts/build-release.sh --dry               # muestra qué iba a compilar, sin compilar
flutter run --release                          # probar en un iPhone/Android conectado
flutter test                                   # tests (417, todos tienen que pasar)
dart analyze lib/ test/ integration_test/      # análisis estático (tiene que decir "No issues found")
```

## Apéndice B — Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Textos de la ficha de App Store, cuestionario de edad, notas para el revisor | `store/app-store.md` |
| Textos de la ficha de Play, IARC, "App access" | `store/play-store.md` |
| Etiquetas de privacidad de Apple | `store/privacy-labels.md` |
| Formulario Data safety de Play | `store/data-safety.md` |
| Capturas iPhone 6.9" (1320×2868) | `store/capturas/ios-6.9/` |
| Capturas para Play (1080×2160) | `store/capturas/play/` |
| Ícono 512 y feature graphic de Play | `store/play/` |
| Variables de build (`--dart-define`) | `.env.release` (copiar de `.env.release.example`) |
| Regenerar las capturas (iPhone 17 Pro Max) | `integration_test/store_shots_test.dart` — receta en `store/README.md` |
| Firma Android | `~/.monaco-keys/monaco-release.jks` + `android/key.properties` |
| Política de privacidad / términos / soporte / borrar cuenta / arrepentimiento | `https://monacobarber.vercel.app/{privacidad,terminos,soporte,eliminar-cuenta,arrepentimiento}` |

## Apéndice C — Errores típicos de la primera vez

| Síntoma | Causa | Solución |
|---|---|---|
| "The App Name you entered is already being used" | "Monaco" está tomado | usar "Monaco Barber Studio" |
| Transporter: "Missing Compliance" | export compliance | ya está en Info.plist; si igual lo pide, responder "No" a cifrado propio |
| Apple rechaza por 2.1 "no pudimos entrar" | secrets `AUTH_TEST_PHONES`/`OTP_PEPPER` sin cargar | Parte 6 y probar la cuenta demo antes de enviar |
| Apple rechaza por 4.8 | Sign in with Apple no funciona | `APPLE_BUNDLE_IDS` + capability en el App ID |
| Google Sign-In anda en `flutter run` y no en la app de Play | falta el SHA-1 de Play App Signing en el client OAuth | Parte 7.5 paso 4 |
| Play: "el paquete está firmado en modo debug" | falta `android/key.properties` | Parte 3 |
| Play: "No se pudo enviar a producción" (cuenta personal) | falta la prueba cerrada de 14 días | Parte 7.5 paso 5 |
| Push no llega en iPhone | falta la APNs key en Firebase o el Team gratuito | Parte 4 paso 4 + Parte 1 |
| `Personal development teams do not support Push Notifications` | Team gratuito | Parte 1 paso 4 |
