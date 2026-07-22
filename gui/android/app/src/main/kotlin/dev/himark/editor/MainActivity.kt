package dev.himark.editor

import android.os.Handler
import android.os.Looper
import com.chaquo.python.PyException
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Hosts the Flutter app and the embedded CPython the compiler runs on.
 *
 * A phone cannot spawn `hejmark emit-json`, so the real compiler is embedded
 * instead (Chaquopy, configured in `app/build.gradle.kts`). Dart reaches it over
 * a MethodChannel rather than FFI, because there is no C ABI to a Python
 * interpreter -- the engine beside it is still FFI, and takes the JSON this
 * returns.
 *
 * This class transports and does not decide. The reply is whatever
 * `himark_compiler` produced — `compile_fragments` for a project's rules,
 * `compile_program` for a whole script — in the same status-line shape
 * `rust/src/ffi.rs` uses, passed through unread; the retry policy lives in
 * `lib/models/bridge.dart`,
 * where it can see every backend at once.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "dev.himark.editor/compiler"
        const val MODULE = "himark_compiler"
    }

    /**
     * Compiling happens off the platform thread. It is milliseconds once the
     * interpreter is warm, but the *first* call starts CPython and imports
     * ANTLR, which is not, and a frozen first keystroke is exactly what the app
     * is otherwise careful to avoid.
     *
     * Single-threaded, so `Python.start` cannot race itself.
     */
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                // The two verbs' compile steps: the project's rules to one
                // floor-AST JSON each, a script to Program JSON. Same
                // transport either way -- a list of sources in, a reply out.
                val function = when (call.method) {
                    "compileFragments" -> "compile_fragments"
                    "compileProgram" -> "compile_program"
                    else -> null
                }
                if (function == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val sources = call.argument<List<String>>("sources") ?: emptyList()
                worker.execute {
                    val reply = compile(function, sources)
                    main.post { result.success(reply) }
                }
            }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    /**
     * Runs [sources] through the embedded compiler, in the status shape.
     * [function] names which lowering: `compile_fragments` for a project's
     * rules, `compile_program` for a whole script.
     *
     * A failure to *start* Python is reported like a failed compile rather than
     * thrown: an APK built without the staged package is a real and easy
     * mistake (as is one built without the engine), and the app should say so
     * in its error line instead of dying.
     */
    private fun compile(function: String, sources: List<String>): String =
        try {
            if (!Python.isStarted()) {
                Python.start(AndroidPlatform(this))
            }
            Python.getInstance()
                .getModule(MODULE)
                .callAttr(function, sources)
                .toString()
        } catch (error: PyException) {
            "err\n${error.message ?: "the embedded compiler failed"}"
        } catch (error: RuntimeException) {
            "err\n${error.message ?: "the embedded compiler is unavailable"}"
        }
}
