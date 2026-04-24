/**
 * IndexedDB-based log persistence for x_trace.
 *
 * Replaces localStorage to avoid the ~5 MB quota limit.
 * IndexedDB typically allows 50 MB+ and writes asynchronously.
 *
 * Database: "x-trace-db", version 1
 * Object Store: "logs" (keyPath: "time")
 */

const DB_NAME = "x-trace-db";
const DB_VERSION = 1;
const STORE_NAME = "logs";
const MAX_STORED_LOGS = 1500;
const LEGACY_STORAGE_KEY = "x-trace-logs";

/** @type {IDBDatabase | null} */
let _db = null;
let _persistRequested = false;

/**
 * Request persistent storage so the browser won't automatically evict
 * IndexedDB data under storage pressure. This is a no-op if the API
 * is unavailable or the user/browser denies the request.
 * Called once on first DB open.
 */
async function requestPersistentStorage() {
  if (_persistRequested) return;
  _persistRequested = true;
  try {
    if (navigator.storage && navigator.storage.persist) {
      const granted = await navigator.storage.persist();
      console.log(`Persistent storage ${granted ? "granted" : "denied"}`);
    }
  } catch (err) {
    console.warn("Failed to request persistent storage:", err);
  }
}

/**
 * Open (or create) the IndexedDB database.
 * Reuses a cached connection on subsequent calls.
 * Also requests persistent storage on first open.
 * @returns {Promise<IDBDatabase>}
 */
function openDB() {
  if (_db) return Promise.resolve(_db);

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "time" });
      }
    };

    request.onsuccess = (event) => {
      _db = event.target.result;
      // Reset cache if the connection closes unexpectedly
      _db.onclose = () => { _db = null; };
      // Request persistent storage (fire-and-forget)
      requestPersistentStorage();
      resolve(_db);
    };

    request.onerror = (event) => {
      console.error("IndexedDB open error:", event.target.error);
      reject(event.target.error);
    };
  });
}

/**
 * Strip transient/UI-only fields before persisting a log entry.
 * @param {object} log
 * @returns {object}
 */
function stripTransient(log) {
  const { _details_loading, _expanded, ...rest } = log;
  return rest;
}

/**
 * Load all persisted logs, sorted by time ascending.
 * @returns {Promise<object[]>}
 */
export async function loadLogs() {
  try {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readonly");
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();

      request.onsuccess = () => {
        const logs = request.result || [];
        // Sort ascending by time (keyPath)
        logs.sort((a, b) => a.time - b.time);
        resolve(logs);
      };

      request.onerror = () => {
        console.error("IndexedDB getAll error:", request.error);
        reject(request.error);
      };
    });
  } catch (err) {
    console.error("loadLogs failed:", err);
    return [];
  }
}

/**
 * Persist a full array of logs (bulk replace).
 * Clears the store first, then writes all entries.
 * Strips transient fields and caps at MAX_STORED_LOGS.
 * @param {object[]} logs
 * @returns {Promise<void>}
 */
export async function saveLogs(logs) {
  try {
    const db = await openDB();
    const toStore = logs.slice(-MAX_STORED_LOGS).map(stripTransient);

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);

      // Clear existing entries first
      store.clear();

      for (const log of toStore) {
        store.put(log);
      }

      tx.oncomplete = () => resolve();
      tx.onerror = () => {
        console.error("IndexedDB saveLogs tx error:", tx.error);
        reject(tx.error);
      };
    });
  } catch (err) {
    console.error("saveLogs failed:", err);
  }
}

/**
 * Append a single log entry. More efficient than rewriting the entire array.
 * Also enforces MAX_STORED_LOGS by deleting the oldest entries if needed.
 * @param {object} log
 * @param {number} currentCount - Current total number of logs in memory
 * @returns {Promise<void>}
 */
export async function appendLog(log, currentCount) {
  try {
    const db = await openDB();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);

      store.put(stripTransient(log));

      // If we're over the limit, trim the oldest entries
      if (currentCount > MAX_STORED_LOGS) {
        const countRequest = store.count();
        countRequest.onsuccess = () => {
          const total = countRequest.result;
          if (total > MAX_STORED_LOGS) {
            const excess = total - MAX_STORED_LOGS;
            const cursorReq = store.openCursor();
            let deleted = 0;
            cursorReq.onsuccess = (e) => {
              const cursor = e.target.result;
              if (cursor && deleted < excess) {
                cursor.delete();
                deleted++;
                cursor.continue();
              }
            };
          }
        };
      }

      tx.oncomplete = () => resolve();
      tx.onerror = () => {
        console.error("IndexedDB appendLog tx error:", tx.error);
        reject(tx.error);
      };
    });
  } catch (err) {
    console.error("appendLog failed:", err);
  }
}

/**
 * Update a single log entry in-place (e.g. after loading details).
 * Strips transient fields before writing.
 * @param {object} log
 * @returns {Promise<void>}
 */
export async function updateLog(log) {
  try {
    const db = await openDB();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);

      store.put(stripTransient(log));

      tx.oncomplete = () => resolve();
      tx.onerror = () => {
        console.error("IndexedDB updateLog tx error:", tx.error);
        reject(tx.error);
      };
    });
  } catch (err) {
    console.error("updateLog failed:", err);
  }
}

/**
 * Clear all stored logs.
 * @returns {Promise<void>}
 */
export async function clearLogs() {
  try {
    const db = await openDB();

    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);
      const request = store.clear();

      tx.oncomplete = () => resolve();
      tx.onerror = () => {
        console.error("IndexedDB clearLogs tx error:", tx.error);
        reject(tx.error);
      };
    });
  } catch (err) {
    console.error("clearLogs failed:", err);
  }
}

/**
 * One-time migration: move logs from localStorage to IndexedDB,
 * then remove the localStorage key so this won't run again.
 * @returns {Promise<void>}
 */
export async function migrateFromLocalStorage() {
  try {
    const raw = localStorage.getItem(LEGACY_STORAGE_KEY);
    if (!raw) return; // Nothing to migrate

    const logs = JSON.parse(raw);
    if (Array.isArray(logs) && logs.length > 0) {
      await saveLogs(logs);
    }

    // Remove legacy key so migration doesn't run again
    localStorage.removeItem(LEGACY_STORAGE_KEY);
    console.log(`Migrated ${logs.length} logs from localStorage to IndexedDB`);
  } catch (err) {
    console.error("Migration from localStorage failed:", err);
    // Still try to remove the key to avoid repeated failures
    try { localStorage.removeItem(LEGACY_STORAGE_KEY); } catch (_) {}
  }
}
