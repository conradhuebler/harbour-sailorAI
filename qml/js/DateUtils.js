.pragma library

// DateUtils.js – date bucketing for list grouping
// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>

// Returns a stable section key for a unix-ms timestamp:
//   "today" | "yesterday" | "this_week" | "last_week"
//   | "month:YYYY-MM" (any older entry, grouped by calendar month)
//   | "older" if the timestamp is missing/invalid
// Week boundary is Monday (ISO).
// Pure data — translation happens in the calling QML so qsTr() works.
function getDateSectionKey(timestamp) {
    if (!timestamp || timestamp <= 0) return "older"

    var d = new Date(timestamp)
    if (isNaN(d.getTime())) return "older"

    var now = new Date()
    var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var yesterday = new Date(today.getTime() - 86400000)

    // Monday as week start: getDay() returns 0=Sun..6=Sat, shift so Mon=0.
    var daysSinceMonday = (today.getDay() + 6) % 7
    var thisWeekStart = new Date(today.getTime() - daysSinceMonday * 86400000)
    var lastWeekStart = new Date(thisWeekStart.getTime() - 7 * 86400000)

    var t = d.getTime()
    if (t >= today.getTime())          return "today"
    if (t >= yesterday.getTime())      return "yesterday"
    if (t >= thisWeekStart.getTime())  return "this_week"
    if (t >= lastWeekStart.getTime())  return "last_week"

    var pad = function(n) { return n < 10 ? "0" + n : String(n) }
    return "month:" + d.getFullYear() + "-" + pad(d.getMonth() + 1)
}
