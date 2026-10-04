package app.opencodemobile

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15+ draws edge-to-edge for apps targeting SDK 35. Opt in on
        // older versions too, so every user gets the same layout and the
        // Flutter side handles the insets the same way. The bar colors are
        // set from Dart (see lib/main.dart).
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
