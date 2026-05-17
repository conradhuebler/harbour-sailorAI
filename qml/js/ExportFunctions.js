.pragma library

// ExportFunctions.js – formatting utilities for exporting chat data
// Copyright (C) 2024-2025 Conrad Hübler <Conrad.Huebler@gmx.net>

function escapeMarkdown(text) {
    return text.replace(/([\\`*_{}\[\]()\#\+\-!])/g, "\\$1")
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