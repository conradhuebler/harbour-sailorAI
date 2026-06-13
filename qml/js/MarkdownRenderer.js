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

// Tool-log helpers. Live web-tool lines (e.g. "🔍 Searching: ...") are collapsed to a
// single clickable line in chat bubbles; the full log can be inspected in a dialog.
// The labels object comes from ChatPage.webToolLabels(). - Claude Generated
function _toolLogPrefix(label) {
    if (!label) return "";
    var idx = label.indexOf("%1");
    if (idx < 0) return label;
    return label.substring(0, idx) + label.substring(idx + 2);
}

function _isToolLogLine(line, labels) {
    var s = _toolLogPrefix(labels.searching);
    var r = _toolLogPrefix(labels.reading);
    return (s && line.indexOf(s) === 0) || (r && line.indexOf(r) === 0);
}

function _parseToolLogLine(line, labels) {
    var s = _toolLogPrefix(labels.searching);
    if (s && line.indexOf(s) === 0) {
        var q = line.substring(s.length).replace(/^"|"$/g, "").replace(/^“|”$/g, "");
        return { type: "search", value: q };
    }
    var r = _toolLogPrefix(labels.reading);
    if (r && line.indexOf(r) === 0) {
        return { type: "read", value: line.substring(r.length) };
    }
    return null;
}

/**
 * Extract web-tool calls from a message. Returns an array of {type, value} objects
 * without duplicates, in order of first appearance.
 * @param {string} src - Markdown source
 * @param {object} labels - {searching, reading} from ChatPage.webToolLabels()
 * @returns {Array}
 */
function extractToolLog(src, labels) {
    if (!src || !labels) return [];
    var lines = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var out = [];
    var seen = {};
    for (var i = 0; i < lines.length; i++) {
        var p = _parseToolLogLine(lines[i], labels);
        if (p) {
            var key = p.type + "|" + p.value;
            if (!seen[key]) {
                seen[key] = true;
                out.push(p);
            }
        }
    }
    return out;
}

/**
 * Replace all web-tool log lines in src with a single clickable placeholder line.
 * @param {string} src - Markdown source
 * @param {object} labels - {searching, reading, toolLogSummary} from ChatPage.webToolLabels()
 * @returns {string}
 */
function collapseToolLog(src, labels) {
    if (!src || !labels) return src;
    var lines = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var calls = extractToolLog(src, labels);
    if (calls.length === 0) return src;

    var firstIdx = -1;
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        if (_isToolLogLine(lines[i], labels)) {
            if (firstIdx < 0) firstIdx = i;
        } else {
            out.push(lines[i]);
        }
    }

    var summaryTemplate = labels.toolLogSummary || "🔍 Web-Tools used (%1 calls)";
    var summary = summaryTemplate.replace("%1", String(calls.length));
    var placeholder = "[" + summary + "](sailorai:toollog:)";
    if (firstIdx >= 0 && firstIdx <= out.length) {
        out.splice(firstIdx, 0, placeholder);
    } else {
        out.unshift(placeholder);
    }
    return out.join("\n");
}

// Sources helpers. The final "Sources" block is replaced by a clickable line in the
// chat bubble; the full list is shown in a dialog. - Claude Generated
function _findSourcesBlock(src, labels) {
    if (!src) return null;
    // Accept both the localized header and the English fallback, because the
    // backend may emit "Sources" even when the UI language is not English.
    // The backend writes the header as "Sources:" (with trailing colon).
    var headers = [];
    if (labels && labels.sourcesHeader) {
        headers.push(labels.sourcesHeader);
        headers.push(labels.sourcesHeader + ":");
    }
    headers.push("Sources");
    headers.push("Sources:");

    var text = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var lines = text.split("\n");
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
        var trimmed = lines[i].replace(/^\s+|\s+$/g, "");
        for (var h = 0; h < headers.length; h++) {
            if (trimmed === headers[h]) {
                start = i;
                break;
            }
        }
        if (start >= 0) break;
    }
    if (start < 0) return null;
    var sources = [];
    for (var j = start + 1; j < lines.length; j++) {
        var line = lines[j].replace(/^\s+|\s+$/g, "");
        if (!line) continue;
        if (/^\d+\./.test(line)) {
            sources.push(line.replace(/^\d+\.\s*/, ""));
        } else {
            break;
        }
    }
    if (sources.length === 0) return null;
    return { startLine: start, endLine: start + sources.length, sources: sources };
}

/**
 * Find all Sources blocks in a message. Returns an array of block descriptors.
 * @param {string} src - Markdown source
 * @param {object} labels - {sourcesHeader} from ChatPage.webToolLabels()
 * @returns {Array}
 */
function _findAllSourcesBlocks(src, labels) {
    if (!src) return [];
    var lines = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var blocks = [];
    var i = 0;
    while (i < lines.length) {
        var block = _findSourcesBlock(lines.slice(i).join("\n"), labels);
        if (!block) break;
        block.startLine += i;
        block.endLine += i;
        blocks.push(block);
        i = block.endLine + 1;
    }
    return blocks;
}

/**
 * Extract the Sources block from a message. Returns an array of source strings
 * ("title — url") or null if none found.
 * @param {string} src - Markdown source
 * @param {object} labels - {sourcesHeader} from ChatPage.webToolLabels()
 * @returns {Array|null}
 */
function extractSources(src, labels) {
    var block = _findSourcesBlock(src, labels);
    return block ? block.sources : null;
}

/**
 * Replace Sources blocks with a single clickable placeholder line.
 * If the model emitted the block in multiple languages, keep only the first
 * block and discard the duplicates.
 * @param {string} src - Markdown source
 * @param {object} labels - {sourcesHeader, sourcesSummary} from ChatPage.webToolLabels()
 * @returns {string}
 */
function collapseSources(src, labels) {
    if (!src || !labels) return src;
    var blocks = _findAllSourcesBlocks(src, labels);
    if (blocks.length === 0) return src;

    var lines = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    var summaryTemplate = labels.sourcesSummary || "📚 Sources (%1)";
    var placeholder = "[" + summaryTemplate.replace("%1", String(blocks[0].sources.length)) + "](sailorai:sources:)";

    // Mark lines that belong to any sources block for removal.
    var remove = {};
    for (var b = 0; b < blocks.length; b++) {
        for (var k = blocks[b].startLine; k <= blocks[b].endLine; k++) {
            remove[k] = true;
        }
    }

    var out = [];
    for (var i = 0; i < lines.length; i++) {
        if (remove[i]) {
            // Insert placeholder once at the first removed line.
            if (i === blocks[0].startLine) out.push(placeholder);
            continue;
        }
        out.push(lines[i]);
    }
    return out.join("\n");
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

// Extract every Markdown table from src and return an array of rendered HTML
// tables in order of appearance. Used for the collapsed-table popup view.
// Does not consume the original content; returns only the table HTML fragments.
function extractTables(src) {
    if (!src) return [];
    var text = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var tables = [];
    var lines = text.split("\n");
    var i = 0, n = lines.length;
    while (i < n) {
        var line = lines[i];
        if (line.indexOf("|") !== -1 && (i + 1) < n && _looksLikeTableSep(lines[i + 1])) {
            var header = _splitRow(line);
            i += 2;
            var rows = [];
            while (i < n && lines[i].indexOf("|") !== -1 && !/^\s*$/.test(lines[i])) {
                rows.push(_splitRow(lines[i])); i++;
            }
            tables.push(_buildTable(header, rows));
        } else {
            i++;
        }
    }
    return tables;
}

/**
 * Check whether a Markdown string contains at least one table.
 * @param {string} src - Markdown source
 * @returns {boolean}
 */
function hasTable(src) {
    if (!src) return false;
    var text = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    var lines = text.split("\n");
    for (var i = 0; i + 1 < lines.length; i++) {
        if (lines[i].indexOf("|") !== -1 && _looksLikeTableSep(lines[i + 1])) return true;
    }
    return false;
}

function _parseBlocks(text, options) {
    options = options || {};
    var collapseTables = !!options.collapseTables;
    var tableCounter = options.tableCounter || { value: 0 };

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
            var idx = tableCounter.value++;
            if (collapseTables) {
                // Replace the table with a clickable placeholder in the chat bubble.
                // The special href is intercepted in ChatPage.onLinkActivated.
                out.push('<p><a href="sailorai:table:' + idx + '">📊 ' + _inline("Tabelle anzeigen") + '</a></p>');
            } else {
                out.push(_buildTable(header, rows));
            }
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
 * @param {object} [options] - rendering options
 * @param {boolean} [options.collapseTables] - replace tables with clickable placeholders
 * @returns {string} HTML
 */
function toRichText(src, options) {
    options = options || {};
    if (!src) return "";
    var text = String(src).replace(/\r\n/g, "\n").replace(/\r/g, "\n");

    var codeBlocks = [];
    var inlineCodes = [];
    text = _extractFenced(text, codeBlocks);
    text = _extractInlineCode(text, inlineCodes);
    text = collapseToolLog(text, options.toolLabels);
    text = collapseSources(text, options.toolLabels);
    text = _escapeHtml(text);

    var html = _parseBlocks(text, options);
    html = _restore(html, codeBlocks, inlineCodes);
    return html;
}

/**
 * Convert Markdown to HTML with all tables collapsed to clickable placeholders.
 * Useful for chat bubbles where wide tables would break the layout.
 * @param {string} src - Markdown source
 * @param {object} [options] - { toolLabels }
 * @returns {string} HTML
 */
function toRichTextCollapsed(src, options) {
    options = options || {};
    return toRichText(src, { collapseTables: true, toolLabels: options.toolLabels });
}
