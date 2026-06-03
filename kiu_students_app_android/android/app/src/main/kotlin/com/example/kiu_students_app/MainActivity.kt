package com.example.kiu_students_app

import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.util.Log
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

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.kiu.assignment/pdf"
    private val tag = "KiuPdf"

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
                    "readClipboard" -> {
                        readClipboard(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Reads the system clipboard and returns BOTH its HTML (if the source put
    /// any on the clipboard, e.g. MS Word / Google Docs / a web page) and its
    /// plain text (always available, e.g. the Markdown an AI app copies). The
    /// Dart side picks: rich HTML when present, otherwise the plain text is
    /// converted from Markdown. Reading natively is reliable, unlike the
    /// WebView's own JS clipboard access, which Android often blocks.
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

    /// Loads the HTML file in an off-screen WebView and renders it to a PDF
    /// using android.graphics.pdf.PdfDocument (direct canvas draw).
    ///
    /// This BYPASSES the PrintDocumentAdapter entirely because on some devices
    /// (e.g. TECNO/MediaTek), the adapter's onWrite callback never fires,
    /// causing an infinite hang.
    private fun htmlToPdf(
        htmlPath: String,
        outputPath: String,
        widthMils: Int,
        heightMils: Int,
        marginMils: Int,
        result: MethodChannel.Result,
    ) {
        Log.d(tag, "htmlToPdf: w=$widthMils h=$heightMils m=$marginMils html=$htmlPath")
        runOnUiThread {
            var answered = false
            fun safeResult(action: () -> Unit) {
                if (answered) return
                answered = true
                action()
            }

            try {
                val webView = WebView(this)
                printWebView = webView
                webView.settings.javaScriptEnabled = false
                webView.settings.allowFileAccess = true
                webView.settings.useWideViewPort = true
                webView.settings.loadWithOverviewMode = true

                // Convert mils to points (1 point = 1/72 inch, 1 mil = 1/1000 inch).
                val pageWidthPt = (widthMils * 72.0 / 1000.0).toInt()
                val pageHeightPt = (heightMils * 72.0 / 1000.0).toInt()
                val marginPt = (marginMils * 72.0 / 1000.0).toInt()
                val contentWidthPt = pageWidthPt - 2 * marginPt
                val contentHeightPt = pageHeightPt - 2 * marginPt

                // Layout the WebView at the content width (in pixels at 72 dpi).
                // We use the content width so text wraps to match the page.
                val container = findViewById<ViewGroup>(android.R.id.content)
                webView.layoutParams = ViewGroup.LayoutParams(contentWidthPt, contentHeightPt)
                webView.translationX = -100000f
                container.addView(webView)

                val handler = Handler(Looper.getMainLooper())

                val pageTimeout = Runnable {
                    Log.e(tag, "onPageFinished timeout (30s)")
                    detachWebView()
                    safeResult {
                        result.error("TIMEOUT", "PDF rendering timed out. Please try again.", null)
                    }
                }
                handler.postDelayed(pageTimeout, 30_000)

                webView.webViewClient = object : WebViewClient() {
                    private var started = false
                    override fun onPageFinished(view: WebView, url: String) {
                        Log.d(tag, "onPageFinished (started=$started)")
                        if (started) return
                        started = true
                        handler.removeCallbacks(pageTimeout)
                        // Give fonts time to load, then render.
                        view.postDelayed({
                            renderPdf(
                                view, outputPath,
                                pageWidthPt, pageHeightPt,
                                marginPt, contentWidthPt, contentHeightPt,
                            ) { success, msg ->
                                detachWebView()
                                safeResult {
                                    if (success) result.success(msg)
                                    else result.error("PRINT", msg, null)
                                }
                            }
                        }, 1000)
                    }

                    override fun onReceivedError(
                        view: WebView,
                        request: WebResourceRequest?,
                        error: WebResourceError?
                    ) {
                        Log.e(tag, "onReceivedError: ${error?.description}")
                        if (request?.isForMainFrame == true) {
                            handler.removeCallbacks(pageTimeout)
                            detachWebView()
                            safeResult {
                                result.error("LOAD", "Could not load page: ${error?.description}", null)
                            }
                        }
                    }
                }
                Log.d(tag, "loadUrl")
                webView.loadUrl("file://$htmlPath")
            } catch (e: Exception) {
                Log.e(tag, "htmlToPdf error", e)
                detachWebView()
                safeResult { result.error("PRINT", e.message, null) }
            }
        }
    }

    /// Renders the WebView content directly to a PDF using
    /// android.graphics.pdf.PdfDocument. This draws the WebView canvas onto
    /// each PDF page, paginating by the page height.
    ///
    /// This is fundamentally more reliable than PrintDocumentAdapter because
    /// it doesn't depend on async callbacks that may never fire on budget devices.
    private fun renderPdf(
        view: WebView,
        outputPath: String,
        pageWidthPt: Int,
        pageHeightPt: Int,
        marginPt: Int,
        contentWidthPt: Int,
        contentHeightPt: Int,
        callback: (success: Boolean, message: String) -> Unit,
    ) {
        try {
            // Measure the full content height of the WebView.
            val scale = view.scale
            val totalContentHeight = (view.contentHeight * scale).toInt()
            Log.d(tag, "renderPdf: contentHeight=${view.contentHeight} scale=$scale totalPx=$totalContentHeight pageContent=${contentHeightPt}")

            if (totalContentHeight <= 0) {
                callback(false, "No content to export.")
                return
            }

            // Force the WebView to lay out at the full content height so we can
            // draw the entire page in one go (WebView only renders the visible
            // portion by default).
            view.layout(0, 0, contentWidthPt, totalContentHeight)

            val document = PdfDocument()
            var pageNum = 1
            var yOffset = 0

            while (yOffset < totalContentHeight) {
                val pageInfo = PdfDocument.PageInfo.Builder(
                    pageWidthPt, pageHeightPt, pageNum
                ).create()
                val page = document.startPage(pageInfo)
                val canvas: Canvas = page.canvas

                // Translate for margins, then translate UP by the current offset
                // so the correct slice of content is drawn.
                canvas.save()
                canvas.translate(marginPt.toFloat(), marginPt.toFloat() - yOffset.toFloat())
                // Clip to the content area so we don't draw into the margin area
                // from the previous/next page.
                canvas.clipRect(
                    RectF(0f, yOffset.toFloat(), contentWidthPt.toFloat(), (yOffset + contentHeightPt).toFloat())
                )
                view.draw(canvas)
                canvas.restore()

                document.finishPage(page)
                yOffset += contentHeightPt
                pageNum++
            }

            // Write the PDF to disk.
            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            FileOutputStream(outFile).use { fos ->
                document.writeTo(fos)
            }
            document.close()

            Log.d(tag, "renderPdf: wrote ${pageNum - 1} pages to $outputPath")
            callback(true, outputPath)
        } catch (e: Exception) {
            Log.e(tag, "renderPdf error", e)
            callback(false, e.message ?: "PDF rendering failed.")
        }
    }

    private fun detachWebView() {
        (printWebView?.parent as? ViewGroup)?.removeView(printWebView)
        printWebView = null
    }
}
