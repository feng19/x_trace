// Shared helpers for downloading files from the browser.
// Extracted from duplicated logic in log_list.svelte and settings_local_storage.js.

/**
 * Build a compact YYYYMMDD_HHMMSS timestamp suffix used for download filenames.
 */
export function timestampSuffix() {
  const now = new Date();
  return now.getFullYear().toString() +
    String(now.getMonth() + 1).padStart(2, "0") +
    String(now.getDate()).padStart(2, "0") + "_" +
    String(now.getHours()).padStart(2, "0") +
    String(now.getMinutes()).padStart(2, "0") +
    String(now.getSeconds()).padStart(2, "0");
}

/**
 * Trigger a browser download of the given content as a file.
 */
export function downloadFile(filename, content, mimeType = "application/json") {
  const link = document.createElement("a");
  const file = new Blob([content], { type: mimeType });
  link.href = URL.createObjectURL(file);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}
