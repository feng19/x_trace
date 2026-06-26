import { writable } from "svelte/store";

// Tracks whether this LiveView hook is currently connected to the server.
// Set from flash.svelte via the live hook's disconnected/reconnected callbacks
// (hook-level, so it also fires when the LiveView process remounts while the
// socket stays up). Consumers react to the disconnected->connected transition.
export const connectionStore = writable(true);
