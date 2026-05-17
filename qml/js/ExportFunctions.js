.pragma library

// ExportFunctions.js – formatting utilities for exporting chat data
// Copyright (C) 2024-2026 Conrad Hübler <Conrad.Huebler@gmx.net>

function escapeMarkdown(text) {
    return text.replace(/([\\`*_{}\[\]()\#\+\-!])/g, "\\$1")
}

// Strip characters that don't belong in a filename and collapse whitespace.
function sanitizeFilename(name) {
    var s = (name || "").replace(/[\/\\:*?"<>|]/g, "_")
                        .replace(/\s+/g, "_")
                        .replace(/^_+|_+$/g, "")
                        .substring(0, 100)
    return s.length > 0 ? s : ""
}

// Build a filename base: <sanitized name>_<YYYY-MM-DD>_<HH-MM-SS>. Falls back to
// "chat" if the name is empty so we never end up with leading underscores.
function makeFilenameBase(name) {
    var d = new Date()
    var pad = function(n) { return n < 10 ? "0" + n : String(n) }
    var stamp = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
                + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds())
    var clean = sanitizeFilename(name)
    return (clean.length > 0 ? clean : "chat") + "_" + stamp
}

// Return <dir>/<base>.<ext>, or <dir>/<base>-N.<ext> if already taken.
// existsCheck(path) -> bool is injected so this stays portable to Node tests.
function findFreePath(dir, base, ext, existsCheck) {
    var path = dir + "/" + base + "." + ext
    if (!existsCheck(path)) return path
    for (var i = 1; i < 1000; i++) {
        path = dir + "/" + base + "-" + i + "." + ext
        if (!existsCheck(path)) return path
    }
    return dir + "/" + base + "-" + Date.now() + "." + ext
}

/**
 * Format messages for export
 * @param {array} messages - Array of message objects from app.database.loadMessages()
 * @param {string} format - "markdown" or "text"
 * @returns {string} Formatted conversation transcript
 */
function formatMessages(messages, format) {
    if (!messages || messages.length === 0) return ""

    var isMarkdown = format && format.toLowerCase() === "markdown"
    var lines = []

    for (var i = 0; i < messages.length; i++) {
        var m = messages[i]
        var role = m.role || ""
        var content = (m.message || "").replace(/\s+$/g, "")

        if (isMarkdown) {
            var escaped = escapeMarkdown(content)
            if (role === "user") {
                lines.push("**User:** " + escaped)
            } else if (role === "bot") {
                // Continuation lines must keep the blockquote prefix, otherwise
                // multi-line bot answers fall out of the quote on render.
                lines.push("> **Bot:** " + escaped.replace(/\n/g, "\n> "))
            } else {
                lines.push("**" + role.charAt(0).toUpperCase() + role.slice(1) + ":** " + escaped)
            }
        } else {
            lines.push(role.charAt(0).toUpperCase() + role.slice(1) + ": " + content)
        }
        lines.push("")
    }

    return lines.join("\n")
}