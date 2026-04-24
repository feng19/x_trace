/**
 * Shared mapping of trace log types to their Tailwind dot color classes.
 * Used by log_list.svelte and type_filter_panel.svelte.
 */
export const TYPE_DOT_COLORS = {
  call:          "bg-blue-600 dark:bg-blue-800",
  return_to:     "bg-blue-300 dark:bg-blue-600",
  return_from:   "bg-cyan-400 dark:bg-cyan-200",
  exception_from:"bg-red-500 dark:bg-red-400",
  send:          "bg-violet-500 dark:bg-violet-400",
  send_to_non_existing_process: "bg-violet-300 dark:bg-violet-600",
  receive:       "bg-indigo-500 dark:bg-indigo-400",
  spawn:         "bg-green-500 dark:bg-green-400",
  exit:          "bg-rose-500 dark:bg-rose-400",
  link:          "bg-amber-500 dark:bg-amber-400",
  unlink:        "bg-amber-300 dark:bg-amber-600",
  getting_linked:   "bg-amber-500 dark:bg-amber-400",
  getting_unlinked: "bg-amber-300 dark:bg-amber-600",
  register:      "bg-teal-500 dark:bg-teal-400",
  unregister:    "bg-teal-300 dark:bg-teal-600",
  in:            "bg-gray-500 dark:bg-gray-400",
  out:           "bg-gray-400 dark:bg-gray-500",
  gc_start:      "bg-orange-500 dark:bg-orange-400",
  gc_end:        "bg-orange-300 dark:bg-orange-600",
};

export function getDotClass(type) {
  return TYPE_DOT_COLORS[type] || "bg-secondary";
}
