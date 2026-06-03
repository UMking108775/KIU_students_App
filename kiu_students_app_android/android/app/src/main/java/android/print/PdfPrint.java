package android.print;

import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

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

    private final PrintAttributes printAttributes;

    public PdfPrint(PrintAttributes printAttributes) {
        this.printAttributes = printAttributes;
    }

    public void print(final PrintDocumentAdapter adapter,
                      final File dir,
                      final String fileName,
                      final CallbackPrint callback) {
        adapter.onLayout(null, printAttributes, null,
            new PrintDocumentAdapter.LayoutResultCallback() {
                @Override
                public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                    final ParcelFileDescriptor pfd = getOutputFile(dir, fileName);
                    if (pfd == null) {
                        callback.onFailure("Could not open the output file.");
                        return;
                    }
                    adapter.onWrite(new PageRange[]{PageRange.ALL_PAGES}, pfd,
                        new CancellationSignal(),
                        new PrintDocumentAdapter.WriteResultCallback() {
                            @Override
                            public void onWriteFinished(PageRange[] pages) {
                                try { pfd.close(); } catch (Exception ignored) {}
                                if (pages != null && pages.length > 0) {
                                    callback.success(new File(dir, fileName).getAbsolutePath());
                                } else {
                                    callback.onFailure("No pages were written.");
                                }
                            }

                            @Override
                            public void onWriteFailed(CharSequence error) {
                                try { pfd.close(); } catch (Exception ignored) {}
                                callback.onFailure(error != null ? error.toString() : "Write failed.");
                            }
                        });
                }

                @Override
                public void onLayoutFailed(CharSequence error) {
                    callback.onFailure(error != null ? error.toString() : "Layout failed.");
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
