package com.monacobarber.monaco_mobile

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity (no FlutterActivity): local_auth exige una
 * FragmentActivity para mostrar el BiometricPrompt. Con FlutterActivity el
 * plugin devolvía `no_fragment_activity` y la huella fallaba en silencio.
 */
class MainActivity : FlutterFragmentActivity()
