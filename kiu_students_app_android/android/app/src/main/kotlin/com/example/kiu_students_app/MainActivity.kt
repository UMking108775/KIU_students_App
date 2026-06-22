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
                        // Inner page margin (CSS px). The raster fallback needs it to
                        // reinstate the page margins; the vector path gets margins
                        // from the HTML's @page rule instead.
                        val marginPx = call.argument<Int>("marginPx") ?: 36
                        if (htmlPath == null || outputPath == null) {
                            result.error("ARGS", "htmlPath and outputPath are required", null)
                        } else {
                            htmlToPdf(htmlPath, outputPath, pageWidthPx, pageHeightPx, marginPx, result)
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
        marginPx: Int,
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
                                        val rok = renderRaster(view, outputPath, pageWidthPx, pageHeightPx, marginPx, density)
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

    /// Raster fallback (used only when the vector print framework hangs/fails on a
    /// budget device). Lays the WebView out at its full height and slices the
    /// CONTENT into page-sized bitmaps that mirror the continuous model's geometry:
    ///
    ///  - each PDF page is the full sheet (pageWidthPx × pageHeightPx),
    ///  - the writable area is inset by `marginPx` on all four sides, so every page
    ///    gets the same margins the editor and the vector PDF have, and
    ///  - the content is sliced every `contentHeightPx` (= pageHeightPx − 2·margin),
    ///    NOT every sheet height — so a slice never eats the margins or cuts off a
    ///    line that the next page should start with.
    ///
    /// The left/right margins come for free: the export body is `contentWidthPx`
    /// wide and centred (`margin:0 auto`) inside a `pageWidthPx`-wide viewport, so
    /// the side whitespace is part of what we draw. The top/bottom margins are the
    /// white bands left above and below the clipped writable area.
    private fun renderRaster(
        view: WebView,
        outputPath: String,
        pageWidthPx: Int,
        pageHeightPx: Int,
        marginPx: Int,
        density: Float,
    ): Boolean {
        return try {
            val viewWidthDev = (pageWidthPx * density).roundToInt().coerceAtLeast(1)
            val totalCss = view.contentHeight // CSS px of the laid-out content
            if (totalCss <= 0) return false
            val totalDev = (totalCss * density).roundToInt().coerceAtLeast(1)
            view.layout(0, 0, viewWidthDev, totalDev)

            // CSS px -> PostScript points (72 pt/in, 96 CSS px/in).
            val pxToPt = 72.0 / 96.0
            val pageWPt = pageWidthPx * pxToPt
            val pageHPt = pageHeightPx * pxToPt
            val marginPt = marginPx * pxToPt
            val contentHeightPx = (pageHeightPx - 2 * marginPx).coerceAtLeast(1)
            val contentHPt = contentHeightPx * pxToPt

            // device px -> points: maps the full-width device-px view onto the page.
            val scale = (pageWPt / viewWidthDev).toFloat()
            val sliceDev = contentHeightPx * density // one content slice, in device px

            val pages = ceil(totalCss.toDouble() / contentHeightPx).toInt().coerceAtLeast(1)
            val document = PdfDocument()
            for (k in 0 until pages) {
                val pageInfo = PdfDocument.PageInfo.Builder(
                    pageWPt.roundToInt(), pageHPt.roundToInt(), k + 1
                ).create()
                val pdfPage = document.startPage(pageInfo)
                val canvas: Canvas = pdfPage.canvas

                canvas.save()
                // Paint only the writable band; the margins stay white.
                canvas.clipRect(
                    RectF(0f, marginPt.toFloat(), pageWPt.toFloat(), (marginPt + contentHPt).toFloat())
                )
                canvas.translate(0f, marginPt.toFloat())          // top margin
                canvas.scale(scale, scale)                        // device px -> points
                canvas.translate(0f, -(k * sliceDev).toFloat())   // k-th content slice
                view.draw(canvas)
                canvas.restore()

                document.finishPage(pdfPage)
            }

            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            FileOutputStream(outFile).use { fos -> document.writeTo(fos) }
            document.close()
            Log.d(tag, "renderRaster wrote $pages pages (margin=$marginPx, sliceCss=$contentHeightPx)")
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
