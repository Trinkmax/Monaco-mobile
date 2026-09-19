# Respuesta al pedido de información de App Review (19/sep/2026)

Guideline 2.1 – Information Needed – New App Submission. No es un rechazo por un defecto:
Apple lo manda a toda cuenta nueva ("limited App Review history"). Se contesta con el
texto de abajo + un video, y se **reenvía el mismo build 21**.

Dónde va cada cosa:
1. App Store Connect → Distribution → App Review → el mensaje → **Reply to App Review** →
   pegar el texto de "Respuesta" y adjuntar el video (clip).
2. iOS App 2.0.0 → **Edit** → App Review Information → **Notes**: reemplazar por las Notes
   nuevas de `app-store.md` §4 (Apple pidió que quede ahí "for reference on future
   submissions") → **Attachment**: el mismo video → Save.
3. Arriba: **Resubmit to App Review**.

## Respuesta (pegar tal cual en "Reply to App Review")

```
Hello, thank you for reviewing Monaco Barber Studio. Here is the requested information (also added to the Notes of App Review Information).

1. SCREEN RECORDING
Attached to this message and to App Review Information: recorded on a physical iPhone 14 Pro Max running the latest iOS. It starts at app launch and shows the typical flow: the welcome screens, guest mode, phone login with the demo account, the live queue of the branches, the rewards catalog, booking an appointment and cancelling it, the deposit screen of the one branch that requires it (cancelled without paying), account deletion, and registration again.

2. PURPOSE AND AUDIENCE
Monaco Barber Studio is a barbershop with three locations in Córdoba, Argentina, and this is the app for its customers (general public). Problem it solves: customers used to book by phone or WhatsApp and had no way to know how long the wait was at each shop. The app lets them book an appointment in three taps, see the live queue status of every branch before leaving home, earn loyalty points on every haircut, redeem them for rewards, and get reminders. All content is in Spanish.

3. SETUP AND ACCESS
Demo account (fixed code, no WhatsApp/SMS is sent): user name 1100000000, code 123456.
- Welcome: tap "Continuar" twice; the third screen shows the sign-in options.
- Tap "Usar mi número de teléfono", enter 1100000000, tap Continuar, enter 123456. If a name is requested, type any name.
- "Continuar con Apple" also works: after Apple's sheet, enter the same phone 1100000000 and code 123456.
- Guest mode: "Seguir mirando" on the third welcome screen; the sign-in wall appears only on personal actions.
- Booking: Turnos > Reservar > branch Caseros or Rondeau (no payment) > service > day and time > Confirmar. Cancel from Turnos > the appointment > Cancelar turno.
- Account deletion: Perfil > Eliminar cuenta > confirm (also at https://monacobarber.vercel.app/eliminar-cuenta).
The demo account has the Gold tier, 2,000 points and 3 notifications so every screen shows content. No sample files are needed.

4. EXTERNAL SERVICES
Supabase (database, authentication, edge functions); Vercel (backend API); Meta WhatsApp Cloud API (sends the login code, appointment confirmations and reminders by WhatsApp); Firebase Cloud Messaging (push notifications) and Firebase Crashlytics (crash reports); Mercado Pago (payment processor for the optional deposit, opened in the system browser via SFSafariViewController - card data never enters the app); Sign in with Apple; Google Sign-In (disabled in this build). No AI services, no advertising, no tracking SDKs.
There are no in-app purchases. The only payment is a deposit (5% of the price) that one branch requires to confirm an online booking for a haircut performed in person at the shop, per guideline 3.1.3(e). The reviewer does not need to pay: Caseros and Rondeau confirm without a deposit.

5. REGIONAL DIFFERENCES
None. The app is available only in Argentina and functions identically everywhere. The deposit is a per-branch business setting, not a regional difference.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. A barbershop is not a regulated industry. All names, logos and photos belong to Monaco Barber Studio; the app is published by studiOS (Ignacio Baldovino) on behalf of the business owner, with his authorization. A letter of authorization can be provided on request.

Additional notes: user content (ratings and comments after a visit) goes privately to the business and is never shown to other users, so there is no public user-generated content. The app is intended for the general public (the shop's customers), not for employees, so public distribution on the App Store is the intended channel.

Thank you.
```

## Guion del video (iPhone real, sin cortes, 3–4 minutos)

Ajustes → Centro de control → agregar "Grabación de pantalla". Cerrar la app del todo.
Iniciar la grabación desde el Centro de control y recién ahí abrir Monaco.

1. Bienvenida: pasar las tres láminas con "Continuar".
2. "Seguir mirando" → Home de invitado → tocar "Reservar turno" → aparece el muro de login →
   "Usar mi número de teléfono" → 1100000000 → 123456 → Home con la tarjeta Oro.
3. Pestaña Sucursales (fila en vivo). Pestaña Premios (scrollear la grilla).
4. Turnos → Reservar → Caseros → un servicio → un día y horario → Confirmar → ver el turno
   confirmado → abrirlo → Cancelar turno.
5. Turnos → Reservar → Paraná → servicio → horario → aparece la hoja de la seña → leer un
   segundo → "Ahora no". (Muestra la única función paga sin pagar.)
6. Perfil → Eliminar cuenta → confirmar → vuelve a la bienvenida con el toast.
7. "Usar mi número de teléfono" → 1100000000 → 123456 → nombre "Apple Review" → Home.
   Detener la grabación.

Después: correr el seed de la demo (la cuenta se recreó con otro id) y comprimir el video
si pesa más de ~100 MB: `ffmpeg -i in.mov -vf scale=-2:1080 -c:v libx264 -crf 26 -preset
slow -an out.mp4`.
