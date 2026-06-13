.pragma library

/*
 * Markdown -> HTML (Qt RichText subset) renderer for chat bubbles.
 * Copyright (C) 2024 - 2025 Conrad Hübler <Conrad.Huebler@gmx.net>
 *
 * Claude Generated. Sailfish runs Qt 5.6, so Text.MarkdownText (Qt 5.14+) is not
 * available; we convert Markdown to the HTML subset that Qt's RichText understands
 * (<b> <i> <s> <a> <h1-6> <ul>/<ol>/<li> <pre> <code> <table> <blockquote> <hr> <br>)
 * and render with Text.RichText. The converter is tolerant of incomplete Markdown so
 * it can run on every streaming chunk without throwing.
 */

// Code spans are protected with sentinel tokens while the rest of the text is formatted,
// then restored verbatim at the end. The tokens use only uppercase letters + digits, so
// they contain no Markdown/HTML special characters, survive escaping and the inline/block
// rules untouched, and are extremely unlikely to collide with real chat text.
var _FENCE_A = "XCODEBLOCKX";   // fenced code block:  XCODEBLOCKX<idx>X
var _INLINE_A = "XINLINECODEX"; // inline code:        XINLINECODEX<idx>X

function _escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// The bulk text is already HTML-escaped before inline runs, so for href values we only
// need to neutralise the attribute delimiter.
function _attrQuote(s) {
    return s.replace(/"/g, "&quot;");
}

function _extractFenced(text, store) {
    // ```lang\n ... \n```  (an unclosed fence consumes to end of text - streaming tolerant)
    return text.replace(/```[^\n]*\n([\s\S]*?)(?:```|$)/g, function(m, body) {
        var idx = store.length;
        store.push(body.replace(/\n$/, ""));
        return "\n" + _FENCE_A + idx + "X\n";
    });
}

function _extractInlineCode(text, store) {
    return text.replace(/`([^`\n]+)`/g, function(m, body) {
        var idx = store.length;
        store.push(body);
        return _INLINE_A + idx + "X";
    });
}

function _autolink(s) {
    // Link bare http(s) URLs. The leading group avoids URLs already inside href="..."
    // (preceded by ") or used as link text (preceded by >); Qt 5.6 has no lookbehind.
    return s.replace(/(^|[\s(])(https?:\/\/[^\s<>"')]+)/g, function(m, pre, url) {
        return pre + '<a href="' + _attrQuote(url) + '">' + url + '</a>';
    });
}

function _inline(s) {
    // Input is already HTML-escaped. Order matters: images before links, bold before italic.
    // Images -> clickable link (inline embedding of remote images is unreliable on Qt 5.6).
    s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)[^)]*\)/g, function(m, alt, url) {
        return '<a href="' + _attrQuote(url) + '">🖼 ' + (alt || url) + '</a>';
    });
    // Links [text](url)
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)[^)]*\)/g, function(m, txt, url) {
        return '<a href="' + _attrQuote(url) + '">' + txt + '</a>';
    });
    // Bold **x** (require non-space at the edges to avoid matching stray asterisks)
    s = s.replace(/\*\*(\S(?:[^*]*?\S)?)\*\*/g, "<b>$1</b>");
    // Italic *x* (after bold so ** is already consumed)
    s = s.replace(/\*(\S(?:[^*\n]*?\S)?)\*/g, "<i>$1</i>");
    // Strikethrough ~~x~~
    s = s.replace(/~~(\S(?:[^~]*?\S)?)~~/g, "<s>$1</s>");
    return _autolink(s);
}

function _looksLikeTableSep(line) {
    // e.g. |---|:--:|---| or --- | ---
    return /\|/.test(line) && /-/.test(line) && /^[\s|:\-]+$/.test(line);
}

function _splitRow(line) {
    var t = line.replace(/^\s+|\s+$/g, "");
    if (t.charAt(0) === "|") t = t.substring(1);
    if (t.charAt(t.length - 1) === "|") t = t.substring(0, t.length - 1);
    var cells = t.split("|");
    for (var i = 0; i < cells.length; i++) cells[i] = cells[i].replace(/^\s+|\s+$/g, "");
    return cells;
}

function _buildTable(header, rows) {
    var html = '<table border="1" cellpadding="6" cellspacing="0"><tr>';
    for (var c = 0; c < header.length; c++) html += "<th>" + _inline(header[c]) + "</th>";
    html += "</tr>";
    for (var r = 0; r < rows.length; r++) {
        html += "<tr>";
        for (var k = 0; k < header.length; k++) {
            var cell = (k < rows[r].length) ? rows[r][k] : "";
            html += "<td>" + _inline(cell) + "</td>";
        }
        html += "</tr>";
    }
    return html + "</table>";
}

function _parseBlocks(text) {
    var lines = text.split("\n");
    var out = [];
    var para = [];
    var i = 0, n = lines.length;

    function flushPara() {
        if (para.length) {
            out.push("<p>" + _inline(para.join("<br>")) + "</p>");
            para = [];
        }
    }

    while (i < n) {
        var line = lines[i];

        if (/^\s*$/.test(line)) { flushPara(); i++; continue; }

        // standalone fenced-code placeholder
        if (/^XCODEBLOCKX\d+X$/.test(line.replace(/^\s+|\s+$/g, ""))) {
            flushPara();
            out.push(line.replace(/^\s+|\s+$/g, ""));
            i++; continue;
        }

        // heading
        var h = /^(#{1,6})\s+(.*)$/.exec(line);
        if (h) { flushPara(); out.push("<h" + h[1].length + ">" + _inline(h[2]) + "</h" + h[1].length + ">"); i++; continue; }

        // horizontal rule (3+ of the same -, *, _)
        if (/^\s*([-*_])\s*(\1\s*){2,}$/.test(line)) { flushPara(); out.push("<hr>"); i++; continue; }

        // table (header row + separator row)
        if (line.indexOf("|") !== -1 && (i + 1) < n && _looksLikeTableSep(lines[i + 1])) {
            flushPara();
            var header = _splitRow(line);
            i += 2;
            var rows = [];
            while (i < n && lines[i].indexOf("|") !== -1 && !/^\s*$/.test(lines[i])) {
                rows.push(_splitRow(lines[i])); i++;
            }
            out.push(_buildTable(header, rows));
            continue;
        }

        // blockquote (text is already HTML-escaped, so '>' is now '&gt;')
        if (/^\s*&gt;\s?/.test(line)) {
            flushPara();
            var q = [];
            while (i < n && /^\s*&gt;\s?/.test(lines[i])) { q.push(lines[i].replace(/^\s*&gt;\s?/, "")); i++; }
            out.push("<blockquote>" + _inline(q.join("<br>")) + "</blockquote>");
            continue;
        }

        // unordered list
        if (/^\s*[-*+]\s+/.test(line)) {
            flushPara();
            var items = "";
            while (i < n && /^\s*[-*+]\s+/.test(lines[i])) {
                items += "<li>" + _inline(lines[i].replace(/^\s*[-*+]\s+/, "")) + "</li>"; i++;
            }
            out.push("<ul>" + items + "</ul>");
            continue;
        }

        // ordered list
        if (/^\s*\d+\.\s+/.test(line)) {
            flushPara();
            var oitems = "";
            while (i < n && /^\s*\d+\.\s+/.test(lines[i])) {
                oitems += "<li>" + _inline(lines[i].replace(/^\s*\d+\.\s+/, "")) + "</li>"; i++;
            }
            out.push("<ol>" + oitems + "</ol>");
            continue;
        }

        para.push(line);
        i++;
    }
    flushPara();
    return out.join("\n");
}

function _restore(html, codeBlocks, inlineCodes) {
    html = html.replace(/XINLINECODEX(\d+)X/g, function(m, idx) {
        return "<code>" + _escapeHtml(inlineCodes[parseInt(idx, 10)]) + "</code>";
    });
    html = html.replace(/XCODEBLOCKX(\d+)X/g, function(m, idx) {
        return "<pre>" + _escapeHtml(codeBlocks[parseInt(idx, 10)]) + "</pre>";
    });
    return html;
}

/**
 * Convert a Markdown string to an HTML string suitable for Text.RichText.
 * @param {string} src - Markdown source
 * @returns {string} HTML
 */
function toRichText(src) {
    if (!src) return "";
    var text = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n");

    var codeBlocks = [];
    var inlineCodes = [];
    text = _extractFenced(text, codeBlocks);
    text = _extractInlineCode(text, inlineCodes);
    text = _escapeHtml(text);

    var html = _parseBlocks(text);
    html = _restore(html, codeBlocks, inlineCodes);
    return html;
}
