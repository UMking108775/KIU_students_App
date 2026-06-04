package com.example.kiu_students_app

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.print.PdfPrint
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.ceil
import kotlin.math.roundToInt

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.kiu.assignment/pdf"
    private val tag = "KiuPdf"

    // Held so the off-screen WebView isn't garbage-collected mid-render.
    private var printWebView: WebView? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "htmlToPdf" -> {
                        val htmlPath = call.argument<String>("htmlPath")
                        val outputPath = call.argument<String>("outputPath")
                        // Page geometry in CSS px (the editor's sheet size).
                        val pageWidthPx = call.argument<Int>("pageWidthPx") ?: 360
                        val pageHeightPx = call.argument<Int>("pageHeightPx") ?: 480
                        if (htmlPath == null || outputPath == null) {
                            result.error("ARGS", "htmlPath and outputPath are required", null)
                        } else {
                            htmlToPdf(htmlPath, outputPath, pageWidthPx, pageHeightPx, result)
                        }
                    }
                    "readClipboard" -> readClipboard(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun readClipboard(result: MethodChannel.Result) {
        val map = HashMap<String, String?>()
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = clipboard.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val item = clip.getItemAt(0)
                map["html"] = item.htmlText
                map["text"] = item.coerceToText(this)?.toString()
            }
            result.success(map)
        } catch (e: Exception) {
            Log.e(tag, "readClipboard error", e)
            result.success(map)
        }
    }

    /// Loads the HTML in an off-screen WebView and renders it to a PDF. Tries the
    /// print framework first (vector, selectable text, exact CSS pages); if that
    /// hangs/fails on a budget device, falls back to a canvas renderer that
    /// slices the page at the EXACT `.page` boundaries (no mid-line cuts).
    private fun htmlToPdf(
        htmlPath: String,
        outputPath: String,
        pageWidthPx: Int,
        pageHeightPx: Int,
        result: MethodChannel.Result,
    ) {
        Log.d(tag, "htmlToPdf: wPx=$pageWidthPx hPx=$pageHeightPx html=$htmlPath")
        runOnUiThread {
            var answered = false
            fun safeResult(action: () -> Unit) {
                if (answered) return
                answered = true
                action()
            }

            try {
                val density = resources.displayMetrics.density
                val viewWidthPx = (pageWidthPx * density).roundToInt().coerceAtLeast(1)
                val viewHeightPx = (pageHeightPx * density).roundToInt().coerceAtLeast(1)

                val webView = WebView(this)
                printWebView = webView
                webView.settings.javaScriptEnabled = true // raster fallback measures pages
                webView.settings.allowFileAccess = true
                webView.settings.useWideViewPort = true
                webView.settings.loadWithOverviewMode = false
                // Software layer so WebView.draw() captures content for the raster path.
                webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null)

                val container = findViewById<ViewGroup>(android.R.id.content)
                webView.layoutParams = ViewGroup.LayoutParams(viewWidthPx, viewHeightPx)
                webView.translationX = -100000f
                container.addView(webView)

                val handler = Handler(Looper.getMainLooper())
                val pageTimeout = Runnable {
                    Log.e(tag, "onPageFinished timeout (30s)")
                    detachWebView()
                    safeResult { result.error("TIMEOUT", "PDF rendering timed out.", null) }
                }
                handler.postDelayed(pageTimeout, 30_000)

                webView.webViewClient = object : WebViewClient() {
                    private var started = false
                    override fun onPageFinished(view: WebView, url: String) {
                        if (started) return
                        started = true
                        handler.removeCallbacks(pageTimeout)
                        // Let the embedded fonts settle, then render.
                        view.postDelayed({
                            renderVector(view, outputPath, pageWidthPx, pageHeightPx,
                                onDone = { ok ->
                                    if (ok) {
                                        detachWebView()
                                        safeResult { result.success(outputPath) }
                                    } else {
                                        // Vector path failed — fall back to raster.
                                        Log.w(tag, "vector failed -> raster fallback")
                                        val rok = renderRaster(view, outputPath, pageWidthPx, pageHeightPx, density)
                                        detachWebView()
                                        safeResult {
                                            if (rok) result.success(outputPath)
                                            else result.error("PRINT", "Could not render the PDF.", null)
                                        }
                                    }
                                })
                        }, 700)
                    }

                    override fun onReceivedError(
                        view: WebView, request: WebResourceRequest?, error: WebResourceError?
                    ) {
                        if (request?.isForMainFrame == true) {
                            handler.removeCallbacks(pageTimeout)
                            detachWebView()
                            safeResult {
                                result.error("LOAD", "Could not load page: ${error?.description}", null)
                            }
                        }
                    }
                }
                webView.loadUrl("file://$htmlPath")
            } catch (e: Exception) {
                Log.e(tag, "htmlToPdf error", e)
                detachWebView()
                safeResult { result.error("PRINT", e.message, null) }
            }
        }
    }

    /// Vector path: drives the WebView's PrintDocumentAdapter straight to a PDF
    /// using a custom page size that equals the editor's sheet. Calls [onDone]
    /// with success/failure (no system dialog). CSS @page is `margin:0` and the
    /// padding lives in `.page`, so the print attributes carry no extra margin.
    private fun renderVector(
        view: WebView,
        outputPath: String,
        pageWidthPx: Int,
        pageHeightPx: Int,
        onDone: (Boolean) -> Unit,
    ) {
        try {
            val widthMils = (pageWidthPx * 1000.0 / 96.0).roundToInt()
            val heightMils = (pageHeightPx * 1000.0 / 96.0).roundToInt()
            val mediaSize = PrintAttributes.MediaSize(
                "kiu_page", "KIU Assignment Page", widthMils, heightMils
            )
            val attrs = PrintAttributes.Builder()
                .setMediaSize(mediaSize)
                .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                .build()

            val adapter: PrintDocumentAdapter = view.createPrintDocumentAdapter("assignment")
            val out = File(outputPath)
            val dir = out.parentFile ?: filesDir
            val pdfPrint = PdfPrint(attrs)
            pdfPrint.print(adapter, dir, out.name, object : PdfPrint.CallbackPrint {
                override fun success(absolutePath: String) {
                    Log.d(tag, "renderVector success: $absolutePath")
                    onDone(File(outputPath).exists())
                }
                override fun onFailure(message: String) {
                    Log.e(tag, "renderVector failure: $message")
                    onDone(false)
                }
            })
        } catch (e: Exception) {
            Log.e(tag, "renderVector error", e)
            onDone(false)
        }
    }

    /// Raster fallback: lays the WebView out at its full height and slices it into
    /// page-sized bitmaps. The slice height equals one CSS page, so breaks land at
    /// page boundaries (the `.page` boxes are stacked at multiples of the page
    /// height) instead of cutting through a line of text.
    private fun renderRaster(
        view: WebView,
        outputPath: String,
        pageWidthPx: Int,
        pageHeightPx: Int,
        density: Float,
    ): Boolean {
        return try {
            val viewWidthPx = (pageWidthPx * density).roundToInt().coerceAtLeast(1)
            val totalCss = view.contentHeight // CSS px
            if (totalCss <= 0) return false
            val totalDevPx = (totalCss * density).roundToInt()
            view.layout(0, 0, viewWidthPx, totalDevPx)

            val pageWidthPt = (pageWidthPx * 72.0 / 96.0)
            val pageHeightPt = (pageHeightPx * 72.0 / 96.0)
            val sliceDevPx = pageHeightPx * density           // one page in device px
            val pages = ceil(totalCss.toDouble() / pageHeightPx).toInt().coerceAtLeast(1)
            // Uniform scale: maps the device-px view onto the point-sized page.
            val scale = (pageWidthPt / viewWidthPx).toFloat()

            val document = PdfDocument()
            for (k in 0 until pages) {
                val pageInfo = PdfDocument.PageInfo.Builder(
                    pageWidthPt.roundToInt(), pageHeightPt.roundToInt(), k + 1
                ).create()
                val pdfPage = document.startPage(pageInfo)
                val canvas: Canvas = pdfPage.canvas
                val srcTop = (k * sliceDevPx)
                canvas.save()
                canvas.clipRect(RectF(0f, 0f, pageWidthPt.toFloat(), pageHeightPt.toFloat()))
                canvas.scale(scale, scale)
                canvas.translate(0f, -srcTop)
                view.draw(canvas)
                canvas.restore()
                document.finishPage(pdfPage)
            }

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            FileOutputStream(outFile).use { fos -> document.writeTo(fos) }
            document.close()
            Log.d(tag, "renderRaster wrote $pages pages")
            true
        } catch (e: Exception) {
            Log.e(tag, "renderRaster error", e)
            false
        }
    }

    private fun detachWebView() {
        (printWebView?.parent as? ViewGroup)?.removeView(printWebView)
        printWebView = null
    }
}
