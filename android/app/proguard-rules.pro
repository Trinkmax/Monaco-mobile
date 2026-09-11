# Reglas propias de R8/ProGuard para el build de release.
# El plugin de Flutter ya aplica flutter_proguard_rules.pro (engine + embedding);
# acá van sólo las de los plugins que lo piden.

# ── flutter_local_notifications ───────────────────────────────────────────────
# El plugin deserializa con **GSON por reflexión** los detalles de la notificación
# (el `NotificationDetails` que viaja de Dart a Android). R8 renombra esos campos y
# GSON, que los busca por nombre, deja de encontrarlos: la notificación revienta o
# llega vacía SÓLO en release, que es donde nadie mira.
#
# Ojo con el comentario que estaba acá antes: decía "sin esto las notificaciones
# programadas se rompen". **Esta app no programa ninguna** — no usa `zonedSchedule`
# ni `periodicallyShow`; el único uso es `show()` para pintar el push que llega con
# la app en primer plano (`lib/core/push/push_service.dart`), y los recordatorios de
# turno los manda el servidor por FCM. La regla igual hace falta: el que necesita
# GSON es ese `show()`. Si algún día se agenda algo en el teléfono, además de esto
# hay que volver a declarar los receivers y `RECEIVE_BOOT_COMPLETED` en el manifest.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ── Firebase Messaging / Google Play services: traen sus propias consumer
#    rules; no hace falta nada extra. ──────────────────────────────────────────
