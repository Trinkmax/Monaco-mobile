# Reglas propias de R8/ProGuard para el build de release.
# El plugin de Flutter ya aplica flutter_proguard_rules.pro (engine + embedding);
# acá van sólo las de los plugins que lo piden.

# ── flutter_local_notifications (serializa con GSON; sin esto las
#    notificaciones programadas se rompen en release) ───────────────────────
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
