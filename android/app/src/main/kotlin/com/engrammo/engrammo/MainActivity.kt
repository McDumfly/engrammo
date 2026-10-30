package com.engrammo.engrammo

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Széltől szélig: a rendszer ne húzzon vékony sötét elválasztó
        // vonalat az app alja és a kilépősáv találkozásához.
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 28) {
            window.navigationBarDividerColor = Color.TRANSPARENT
        }
    }
}
