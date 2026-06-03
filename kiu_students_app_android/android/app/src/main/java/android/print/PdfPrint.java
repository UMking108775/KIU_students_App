package android.print;

import android.os.CancellationSignal;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.File;

/**
 * Drives a {@link PrintDocumentAdapter} (e.g. from a WebView) straight to a PDF
 * file, with no system print dialog.
 *
 * This lives in the {@code android.print} package on purpose: the framework's
 * {@code LayoutResultCallback} / {@code WriteResultCallback} have package-private
 * constructors, so they can only be subclassed from within this package.
 */
public class PdfPrint {

    public interface CallbackPrint {
        void success(String absolutePath);
        void onFailure(String message);
    }

    private static final String TAG = "KiuPdf";
    /** Safety timeout (ms) for the print adapter callbacks. */
    private static final long TIMEOUT_MS = 30_000;

    private final PrintAttributes printAttributes;

    public PdfPrint(PrintAttributes printAttributes) {
        this.printAttributes = printAttributes;
    }

    public void print(final PrintDocumentAdapter adapter,
                      final File dir,
                      final String fileName,
                      final CallbackPrint callback) {

        // Guard against double callback invocations (e.g. timeout + late success).
        final boolean[] done = {false};
        final CallbackPrint safe = new CallbackPrint() {
            @Override
            public void success(String absolutePath) {
                synchronized (done) {
                    if (done[0]) return;
                    done[0] = true;
                }
                callback.success(absolutePath);
            }

            @Override
            public void onFailure(String message) {
                synchronized (done) {
                    if (done[0]) return;
                    done[0] = true;
                }
                callback.onFailure(message);
            }
        };

        final Handler handler = new Handler(Looper.getMainLooper());

        // Safety timeout: if onLayout never calls back, fail gracefully.
        final Runnable layoutTimeout = () -> {
            Log.e(TAG, "onLayout timeout (" + TIMEOUT_MS + "ms)");
            safe.onFailure("PDF layout timed out. Please try again.");
        };
        handler.postDelayed(layoutTimeout, TIMEOUT_MS);

        Log.d(TAG, "PdfPrint.onLayout start");
        adapter.onLayout(null, printAttributes, null,
            new PrintDocumentAdapter.LayoutResultCallback() {
                @Override
                public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                    handler.removeCallbacks(layoutTimeout);
                    Log.d(TAG, "onLayoutFinished -> onWrite");
                    final ParcelFileDescriptor pfd = getOutputFile(dir, fileName);
                    if (pfd == null) {
                        safe.onFailure("Could not open the output file.");
                        return;
                    }

                    // Safety timeout for the write phase.
                    final Runnable writeTimeout = () -> {
                        Log.e(TAG, "onWrite timeout (" + TIMEOUT_MS + "ms)");
                        try { pfd.close(); } catch (Exception ignored) {}
                        safe.onFailure("PDF writing timed out. Please try again.");
                    };
                    handler.postDelayed(writeTimeout, TIMEOUT_MS);

                    adapter.onWrite(new PageRange[]{PageRange.ALL_PAGES}, pfd,
                        new CancellationSignal(),
                        new PrintDocumentAdapter.WriteResultCallback() {
                            @Override
                            public void onWriteFinished(PageRange[] pages) {
                                handler.removeCallbacks(writeTimeout);
                                Log.d(TAG, "onWriteFinished pages=" + (pages == null ? "null" : pages.length));
                                try { pfd.close(); } catch (Exception ignored) {}
                                if (pages != null && pages.length > 0) {
                                    safe.success(new File(dir, fileName).getAbsolutePath());
                                } else {
                                    safe.onFailure("No pages were written.");
                                }
                            }

                            @Override
                            public void onWriteFailed(CharSequence error) {
                                handler.removeCallbacks(writeTimeout);
                                Log.e(TAG, "onWriteFailed: " + error);
                                try { pfd.close(); } catch (Exception ignored) {}
                                safe.onFailure(error != null ? error.toString() : "Write failed.");
                            }

                            @Override
                            public void onWriteCancelled() {
                                handler.removeCallbacks(writeTimeout);
                                Log.e(TAG, "onWriteCancelled");
                                try { pfd.close(); } catch (Exception ignored) {}
                                safe.onFailure("PDF writing was cancelled.");
                            }
                        });
                }

                @Override
                public void onLayoutFailed(CharSequence error) {
                    handler.removeCallbacks(layoutTimeout);
                    Log.e(TAG, "onLayoutFailed: " + error);
                    safe.onFailure(error != null ? error.toString() : "Layout failed.");
                }

                @Override
                public void onLayoutCancelled() {
                    handler.removeCallbacks(layoutTimeout);
                    Log.e(TAG, "onLayoutCancelled");
                    safe.onFailure("PDF layout was cancelled.");
                }
            }, null);
    }

    private ParcelFileDescriptor getOutputFile(File dir, String fileName) {
        if (!dir.exists()) {
            dir.mkdirs();
        }
        try {
            final File file = new File(dir, fileName);
            file.createNewFile();
            return ParcelFileDescriptor.open(file,
                ParcelFileDescriptor.MODE_CREATE
                    | ParcelFileDescriptor.MODE_TRUNCATE
                    | ParcelFileDescriptor.MODE_READ_WRITE);
        } catch (Exception e) {
            return null;
        }
    }
}
