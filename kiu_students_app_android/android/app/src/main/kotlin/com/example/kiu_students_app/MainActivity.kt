package com.example.kiu_students_app

import android.print.PdfPrint
import android.print.PrintAttributes
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.kiu.assignment/pdf"

    // Held so the off-screen WebView isn't garbage-collected mid-print.
    private var printWebView: WebView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "htmlToPdf" -> {
                        val htmlPath = call.argument<String>("htmlPath")
                        val outputPath = call.argument<String>("outputPath")
                        // Page geometry in mils (1/1000 inch); default to A4.
                        val widthMils = call.argument<Int>("widthMils") ?: 8268
                        val heightMils = call.argument<Int>("heightMils") ?: 11693
                        val marginMils = call.argument<Int>("marginMils") ?: 472
                        if (htmlPath == null || outputPath == null) {
                            result.error("ARGS", "htmlPath and outputPath are required", null)
                        } else {
                            htmlToPdf(htmlPath, outputPath, widthMils, heightMils, marginMils, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Loads the HTML file in an off-screen WebView (full Chromium shaping for
    /// Urdu/Pashto Nastaliq) and prints it to a real, paginated PDF at
    /// [outputPath] using the platform print framework.
    private fun htmlToPdf(
        htmlPath: String,
        outputPath: String,
        widthMils: Int,
        heightMils: Int,
        marginMils: Int,
        result: MethodChannel.Result,
    ) {
        // WebView must be created/driven on the UI thread.
        runOnUiThread {
            try {
                val webView = WebView(this)
                printWebView = webView
                webView.settings.javaScriptEnabled = false
                webView.settings.allowFileAccess = true

                // The WebView must be attached to the view tree, otherwise the
                // print adapter never finishes laying out and the call hangs.
                // A 1×1 off-screen view is enough — printing re-lays-out to the
                // page size regardless of the on-screen size.
                val container = findViewById<ViewGroup>(android.R.id.content)
                webView.layoutParams = ViewGroup.LayoutParams(1, 1)
                container.addView(webView)

                webView.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String) {
                        // Give layout/fonts a moment to settle, then print.
                        view.postDelayed({
                            writePdf(view, outputPath, widthMils, heightMils, marginMils, result)
                        }, 400)
                    }
                }
                webView.loadUrl("file://$htmlPath")
            } catch (e: Exception) {
                detachWebView()
                result.error("PRINT", e.message, null)
            }
        }
    }

    private fun detachWebView() {
        (printWebView?.parent as? ViewGroup)?.removeView(printWebView)
        printWebView = null
    }

    private fun writePdf(
        view: WebView,
        outputPath: String,
        widthMils: Int,
        heightMils: Int,
        marginMils: Int,
        result: MethodChannel.Result,
    ) {
        var finished = false
        fun finish(action: () -> Unit) {
            if (finished) return
            finished = true
            detachWebView()
            action()
        }

        try {
            val adapter = view.createPrintDocumentAdapter("assignment")
            // Page sized to the phone width (passed from Dart) so the PDF wraps
            // like the on-screen preview. Margins applied here by the framework.
            val mediaSize = PrintAttributes.MediaSize(
                "kiu_page", "KIU Page", widthMils, heightMils
            )
            val margins = PrintAttributes.Margins(
                marginMils, marginMils, marginMils, marginMils
            )
            val attributes = PrintAttributes.Builder()
                .setMediaSize(mediaSize)
                .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
                .setMinMargins(margins)
                .build()

            val outFile = File(outputPath)
            val dir = outFile.parentFile ?: filesDir

            PdfPrint(attributes).print(
                adapter,
                dir,
                outFile.name,
                object : PdfPrint.CallbackPrint {
                    override fun success(absolutePath: String) {
                        finish { result.success(absolutePath) }
                    }

                    override fun onFailure(message: String) {
                        finish { result.error("PRINT", message, null) }
                    }
                }
            )
        } catch (e: Exception) {
            finish { result.error("PRINT", e.message, null) }
        }
    }
}
