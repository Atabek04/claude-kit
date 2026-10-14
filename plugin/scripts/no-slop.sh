#!/bin/bash
# Comment-hygiene gate. No arguments: PreToolUse hook. Otherwise --diff <base> [--staged] or --tree [--ceiling N].
# Rules, per-project config and the false-positive process are in README.md.
set -u

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

IFS= read -r -d '' AWK_SCAN <<'AWK_EOF' || true
function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function chars_of(s,   t, n) {
    t = s
    n = gsub(/[\200-\277]/, "", t)
    return length(s) - n
}

function trunc(s, n,   i, c, seen) {
    seen = 0
    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c !~ /[\200-\277]/) {
            seen++
            if (seen > n) break
        }
    }
    return substr(s, 1, i - 1)
}

function count_occ(s, pat,   n, p) {
    n = 0
    while ((p = index(s, pat)) > 0) {
        n++
        s = substr(s, p + length(pat))
    }
    return n
}

function viol(s, e, rule, text) {
    gsub(/\t/, " ", text)
    print "V\t" s "\t" e "\t" rule "\t" trunc(trim(text), 100)
}

# True when the end of prefix sits inside a string literal. Char literals like '"' are skipped in slash mode.
function in_string(prefix, mode,   i, c, state, len) {
    state = 0
    len = length(prefix)
    for (i = 1; i <= len; i++) {
        c = substr(prefix, i, 1)
        if (state == 0) {
            if (c == "\\") { i++; continue }
            if (c == "\"") state = 1
            else if (c == "'" && mode == "slash") {
                if (substr(prefix, i + 2, 1) == "'") i += 2
                else if (substr(prefix, i + 1, 1) == "\\" && substr(prefix, i + 3, 1) == "'") i += 3
            } else if (c == "'" && mode != "slash") state = 2
            else if (c == "`" && mode != "dash") state = 3
        } else if (state == 1) {
            if (c == "\\") i++
            else if (c == "\"") state = 0
        } else if (state == 2) {
            if (c == "'") state = 0
        } else if (state == 3) {
            if (c == "`") state = 0
        }
    }
    return state != 0
}

# A trailing marker needs whitespace before it and an even quote state, so "http://x" and "a # b" stay code.
function find_marker(line, marker, mode,   start, j, pos, prev) {
    start = 1
    while ((j = index(substr(line, start), marker)) > 0) {
        pos = start + j - 1
        if (pos > 1) {
            prev = substr(line, pos - 1, 1)
            if ((prev == " " || prev == "\t") && !in_string(substr(line, 1, pos - 1), mode)) return pos
        }
        start = pos + 1
    }
    return 0
}

function flush_L() {
    if (lcount > 3) viol(lstart, lend, "run-cap", lcount " comment lines in a row (cap 3): " ltext)
    lcount = 0
}
function flush_B() {
    if (bcount > 5) viol(bstart, bend, "run-cap", bcount " lines in one block comment (cap 5): " btext)
    bcount = 0
}
function flush_runs() { flush_L(); flush_B() }

function check_names(code,   c) {
    if (ext ~ /^(kt|java|ts|tsx)$/ &&
        code ~ /(^|[^A-Za-z0-9_])(class|interface|object)[ \t]+[A-Za-z0-9_]*(Manager|Helper|Util|Utils|Wrapper)([^A-Za-z0-9_]|$)/)
        viol(nr, nr, "banned-name", cur)
    if (ext == "kt" && code !~ /(^|[^A-Za-z0-9_])override[ \t]/ &&
        code ~ /(^|[^A-Za-z0-9_])fun[ \t]+(<[^>]*>[ \t]*)?([A-Za-z0-9_<>?,. ]*\.)?(handle|process|doWork|execute)[ \t]*\(/)
        viol(nr, nr, "banned-name", cur)
    if ((ext == "ts" || ext == "tsx") && code ~ /(^|[^A-Za-z0-9_])function[ \t*]+(handle|process|doWork|execute)[ \t]*[(<]/)
        viol(nr, nr, "banned-name", cur)
    if (ext == "go") {
        if (code ~ /^[ \t]*func[ \t]+(\([^)]*\)[ \t]*)?(handle|process|doWork|execute)[ \t]*[(\[]/)
            viol(nr, nr, "banned-name", cur)
        if (code ~ /^[ \t]*type[ \t]+[A-Za-z0-9_]*(Manager|Helper|Util|Utils|Wrapper)[ \t]+(struct|interface)/)
            viol(nr, nr, "banned-name", cur)
    }
    if (ext == "py") {
        if (code ~ /^[ \t]*(async[ \t]+)?def[ \t]+(handle|process|doWork|execute)[ \t]*\(/)
            viol(nr, nr, "banned-name", cur)
        if (code ~ /^[ \t]*class[ \t]+[A-Za-z0-9_]*(Manager|Helper|Util|Utils|Wrapper)([^A-Za-z0-9_]|$)/)
            viol(nr, nr, "banned-name", cur)
    }
}

function code_line(code) {
    flush_runs()
    if (ext == "go" && code ~ /^package[ \t]/ && ctg > 1) viol(ctgstart, nr - 1, "go-package-doc", ctg " comment lines above package (cap 1)")
    ctg = 0
    last_code = trim(code)
    check_names(code)
}

function code_break() { flush_runs(); ctg = 0 }

function begin_block() { flush_runs() }
function end_block() { flush_B() }

function is_directive(s) {
    if (s ~ /^(go:|nolint|\+build|line |swiftlint:|eslint-|@ts-|prettier-ignore|noinspection|language=|ktlint-|detekt|istanbul|nosemgrep|NOSONAR|pragma|jshint)/) return 1
    if (s ~ /^(noqa|type:|-\*-|shellcheck |pylint:|pyright:|mypy:|fmt:|isort:|nosec|ruff:|yaml-language-server:|coding[:=]|vim:|yapf:)/) return 1
    return 0
}

function todo_ok(after,   p, inner, rest, h, path) {
    if (substr(after, 1, 1) != "(") return 0
    p = index(after, ")")
    if (p == 0) return 0
    inner = substr(after, 2, p - 2)
    rest = substr(after, p + 1)
    if (rest !~ /^:[ \t]+[^ \t]/) return 0
    if (inner ~ /[ \t]/) return 0
    h = index(inner, "#")
    if (h < 2 || h == length(inner)) return 0
    path = substr(inner, 1, h - 1)
    if (todo_anchor != "") {
        if (substr(path, 1, length(todo_anchor)) != todo_anchor) return 0
        if (path !~ /\.md$/ || length(path) <= length(todo_anchor) + 3) return 0
    }
    return 1
}

function todo_bad(s,   kws, i, kw, padded, after) {
    split("TODO FIXME XXX HACK", kws, " ")
    padded = " " s " "
    for (i = 1; i <= 4; i++) {
        kw = kws[i]
        if (match(padded, "[^A-Za-z0-9_]" kw "[^A-Za-z0-9_]")) {
            after = substr(padded, RSTART + 1 + length(kw))
            if (!todo_ok(after)) return 1
        }
    }
    return 0
}

function changelog_hit(s, ls, dated_ok) {
    if (s ~ /(^|[^A-Za-z0-9_])(Removed|Added|Replaced|Deleted|Renamed|Changed|Introduced|Fixed)[ \t]+(on[ \t]+)?20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) return 1
    if (ls ~ /(^|[^a-z0-9_])(this|it|that|the (rule|file|function|method|field|check|list))[ \t]+(used to|previously)([^a-z0-9_]|$)/) return 1
    if (ls ~ /(^|[^a-z0-9_])(we|i)[ \t]+((just|now|then)[ \t]+)?(removed|added|deleted|replaced|renamed|refactored|changed|moved|split|inlined)([^a-z0-9_]|$)/) return 1
    if (dated_ok && ls ~ /(^|[^a-z0-9_])(until|as of|before)[ \t]+20[0-9][0-9](-[0-9][0-9])?([^0-9]|$)/) return 1
    return 0
}

function roadmap_hit(ls,   rest, p, win) {
    if (ls ~ /(^|[^a-z0-9_])for now([^a-z0-9_]|$)/) return 1
    if (ls ~ /(^|[^a-z0-9_])for the time being([^a-z0-9_]|$)/) return 1
    if (ls ~ /(^|[^a-z])temporar(y|ily)([^a-z]|$)/) return 1
    if (ls ~ /(^|[^a-z0-9_])not yet (built|implemented|wired|supported)([^a-z0-9_]|$)/) return 1
    if (ls ~ /(^|[^a-z0-9_])in a later (batch|phase|step)([^a-z0-9_]|$)/) return 1
    rest = ls
    while ((p = index(rest, "until")) > 0) {
        win = substr(rest, p + 5, 60)
        if (match(win, /(^|[^a-z])(exists|lands|ships|is built|is added|is implemented|is wired)/) && RSTART <= 41) return 1
        rest = substr(rest, p + 5)
    }
    return 0
}

function statement_start(s) {
    if (s ~ /^(return|throw|break|continue|val|var|let|const)([ \t;]|$)/) return 1
    return s ~ /^[A-Za-z_][A-Za-z0-9_.]*(\(|\[|\+\+|--|[ \t]*[-+*\/%&|^]?=[^=])/
}

function code_like(s) {
    if (lang == "slash") {
        if (s ~ /\{$/ || s ~ /^\}/) return 1
        if (s ~ /[};]$/ && s !~ /\. / && statement_start(s)) return 1
        if (s ~ /^(val|var|let|const)[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*[:=;,]/) return 1
        if (s ~ /^(fun|func)[ \t]+[A-Za-z_][A-Za-z0-9_.<>]*\(/ || s ~ /^func[ \t]+\(/) return 1
        if (s ~ /^((data|sealed|abstract|open|enum)[ \t]+)?class[ \t]+[A-Z][A-Za-z0-9_]*([ \t]*[(<:{]|$)/) return 1
        if (s ~ /^import[ \t]+[^ \t]*[A-Za-z0-9_]\.[A-Za-z_*][^ \t]*$/) return 1
        if (s ~ /^import[ \t]+["'{]/ || s ~ /^import[ \t].*[ \t]from[ \t]+["']/) return 1
        if (s ~ /^package[ \t]+[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z0-9_.]*$/) return 1
        if (s ~ /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*\(.*\)$/) return 1
    } else if (lang == "hash") {
        if (s ~ /^import[ \t]+[a-z_][a-z0-9_.]*$/) return 1
        if (s ~ /^from[ \t]+[A-Za-z_.][A-Za-z0-9_.]*[ \t]+import[ \t]/) return 1
        if (s ~ /^def[ \t]+[A-Za-z_][A-Za-z0-9_]*\(/) return 1
        if (s ~ /^class[ \t]+[A-Z][A-Za-z0-9_]*([ \t]*[(:]|$)/) return 1
        if (s ~ /^return[ \t]+[A-Za-z_][A-Za-z0-9_]*[(\[.]/) return 1
        if (s ~ /^return[ \t]+(None|True|False|self|nil|null|true|false|[0-9]+)$/) return 1
        if (s ~ /^return[ \t]+[\[({"']/) return 1
        if (s ~ /^print\(/) return 1
    }
    return 0
}

function comment_line(kind, body,   raw, s, ls, tx) {
    raw = ltrim(body)
    s = trim(body)
    if (kind == "L" || kind == "T") {
        if (lang == "slash" && (substr(s, 1, 1) == "/" || substr(s, 1, 1) == "!")) s = ltrim(substr(s, 2))
        if (lang == "hash") sub(/^#+[ \t]*/, "", s)
    }
    if (raw ~ /^[-=*~_][-=*~_][-=*~_][-=*~_]/ || raw ~ /^[#\/][#\/][#\/]+[ \t]*$/) viol(nr, nr, "banner", cur)
    if (s == "") return
    if (is_directive(s)) {
        if (kind != "T") flush_runs()
        return
    }
    ls = tolower(s)

    if (ls ~ /^(step[ \t]*[0-9]|(first|then|next|finally),?[ \t]+we([ \t,]|$))/ || s ~ /^[0-9]+\.[ \t]+[A-Z]/)
        viol(nr, nr, "step-narration", cur)
    if (s ~ /^#?(end)?region([ \t]+[A-Z][A-Za-z0-9 _:-]*)?$/) viol(nr, nr, "banner", cur)
    if (s ~ /^(State|Handlers|Effects|Render|Helpers|Constants|Types|Mutations|Queries|Imports|Variables|Public|Private):?$/)
        viol(nr, nr, "section-label", cur)
    if (ls ~ /^@param[ \t]+[a-z_][a-z0-9_]*[ \t]+(the|a|an)[ \t]/ || ls ~ /^@returns?[ \t]+the[ \t]/)
        viol(nr, nr, "signature-echo", cur)
    if (todo_bad(s)) viol(nr, nr, "todo-anchor", cur)
    if (changelog_hit(s, ls, 1)) viol(nr, nr, "changelog", cur)
    if (roadmap_hit(ls)) viol(nr, nr, "roadmap", cur)
    if (kind == "L" && code_like(s)) viol(nr, nr, "commented-out-code", cur)
    if (kind != "T" && chars_of(line) > 120 && s ~ /[ \t]/) viol(nr, nr, "width", cur)

    if (want_c != "") {
        tx = s
        gsub(/\t/, " ", tx)
        print "C\t" nr "\t" tx "\t" trim(cur)
    }

    if (kind == "L") {
        flush_B()
        if (lcount == 0) { lstart = nr; ltext = trim(cur) }
        lcount++
        lend = nr
    } else if (kind == "B") {
        flush_L()
        if (bcount == 0) { bstart = nr; btext = trim(cur) }
        bcount++
        bend = nr
    } else {
        flush_runs()
        return
    }
    if (ctg == 0) ctgstart = nr
    ctg++
}

function do_slash(   tl, rest, p, body, tpos, bpos, code, n3, text) {
    if (in_raw) {
        if (count_occ(line, "\"\"\"") % 2 == 1) in_raw = 0
        code_break()
        return
    }
    if (in_block) {
        p = index(line, "*/")
        body = (p > 0) ? substr(line, 1, p - 1) : line
        sub(/^[ \t]*\*?/, "", body)
        comment_line("B", body)
        if (p > 0) { in_block = 0; end_block() }
        return
    }
    tl = ltrim(line)
    if (tl == "") { code_break(); return }
    if (substr(tl, 1, 2) == "/*") {
        begin_block()
        rest = substr(tl, 3)
        if (substr(rest, 1, 1) == "*" && substr(rest, 2, 1) != "/") rest = substr(rest, 2)
        p = index(rest, "*/")
        if (p > 0) { comment_line("B", substr(rest, 1, p - 1)); end_block() }
        else { in_block = 1; comment_line("B", rest) }
        return
    }
    if (substr(tl, 1, 2) == "//") { comment_line("L", substr(tl, 3)); return }
    code = line
    n3 = has_raw ? count_occ(line, "\"\"\"") : 0
    if (n3 > 0) code = substr(line, 1, index(line, "\"\"\"") - 1)
    if (n3 % 2 == 1) in_raw = 1
    tpos = find_marker(code, "//", "slash")
    bpos = find_marker(code, "/*", "slash")
    if (tpos > 0 && (bpos == 0 || tpos < bpos)) {
        code_line(substr(line, 1, tpos - 1))
        comment_line("T", substr(line, tpos + 2))
    } else if (bpos > 0) {
        code_line(substr(line, 1, bpos - 1))
        rest = substr(line, bpos + 2)
        p = index(rest, "*/")
        if (p > 0) text = substr(rest, 1, p - 1)
        else { text = rest; in_block = 1; begin_block() }
        comment_line("T", text)
    } else {
        code_line(code)
    }
}

function docstring_position() { return last_code == "" || last_code ~ /:$/ }

function do_hash(   tl, rest, p, body, d, pos, d1, d2) {
    tl = ltrim(line)
    if (meta) {
        if (tl ~ /^#[ \t]*\/\/\/[ \t]*$/) meta = 0
        return
    }
    if (tl ~ /^#[ \t]*\/\/\/[ \t]+[A-Za-z]+[ \t]*$/) { meta = 1; flush_runs(); return }
    if (ext == "py") {
        if (in_doc) {
            p = index(line, doc_delim)
            body = (p > 0) ? substr(line, 1, p - 1) : line
            comment_line("B", body)
            if (p > 0) { in_doc = 0; end_block() }
            return
        }
        if (in_str) {
            if (count_occ(line, str_delim) % 2 == 1) in_str = 0
            code_break()
            return
        }
        if (docstring_position() && match(tl, /^[rRuUbBfF]?[rRbBfF]?("""|''')/)) {
            d = substr(tl, RLENGTH - 2, 3)
            rest = substr(tl, RLENGTH + 1)
            begin_block()
            p = index(rest, d)
            if (p > 0) { comment_line("B", substr(rest, 1, p - 1)); end_block() }
            else { in_doc = 1; doc_delim = d; comment_line("B", rest) }
            return
        }
        d1 = index(line, "\"\"\"")
        d2 = index(line, "'''")
        if (d1 > 0 || d2 > 0) {
            d = (d1 > 0 && (d2 == 0 || d1 < d2)) ? "\"\"\"" : "'''"
            if (count_occ(line, d) % 2 == 1) { in_str = 1; str_delim = d }
        }
    }
    if (tl == "") { code_break(); return }
    if (substr(tl, 1, 1) == "#") { comment_line("L", substr(tl, 2)); return }
    pos = find_marker(line, "#", "hash")
    if (pos > 0) {
        code_line(substr(line, 1, pos - 1))
        comment_line("T", substr(line, pos + 1))
    } else {
        code_line(line)
    }
}

function do_dash(   tl, pos) {
    tl = ltrim(line)
    if (tl == "") { code_break(); return }
    if (substr(tl, 1, 2) == "--") { comment_line("L", substr(tl, 3)); return }
    pos = find_marker(line, "--", "dash")
    if (pos > 0) {
        code_line(substr(line, 1, pos - 1))
        comment_line("T", substr(line, pos + 2))
    } else {
        code_line(line)
    }
}

function do_markdown(   t, s, q) {
    t = ltrim(line)
    if (t ~ /^(```|~~~)/) {
        if (fence == "") fence = substr(t, 1, 3)
        else if (substr(t, 1, 3) == fence) fence = ""
        return
    }
    if (fence != "") return
    s = trim(line)
    # Prose that bans a phrase has to quote it; a quoted or backticked span is a citation, not narration.
    q = s
    gsub(/`[^`]*`/, "", q)
    gsub(/"[^"]*"/, "", q)
    if (s != "" && changelog_hit(q, tolower(q), s ~ /^[>#*]/)) viol(nr, nr, "changelog", s)
}

BEGIN {
    lang = ENVIRON["NS_LANG"]
    ext = ENVIRON["NS_EXT"]
    todo_anchor = ENVIRON["NS_ANCHOR"]
    want_c = ENVIRON["NS_WANTC"]
    has_raw = (ext == "kt" || ext == "java" || ext == "swift" || ext == "scala")
    last_code = ""
}

{
    line = $0
    sub(/\r$/, "", line)
    nr = NR
    cur = line
    if (lang == "md") { do_markdown(); next }
    if (nr == 1 && substr(line, 1, 2) == "#!") { code_break(); next }
    if (lang == "slash") do_slash()
    else if (lang == "hash") do_hash()
    else if (lang == "dash") do_dash()
}

END { nr = NR + 1; flush_runs() }
AWK_EOF

ESCAPE_TEXT="If this rule is WRONG here, do not rephrase to evade it. Fix the rule instead: narrow the pattern in claude-kit's no-slop.sh so it stops misfiring without losing the case it was written for, add an allow and a deny fixture, and record the fix in plugin/false-positives.md. A false positive is a bug in the gate and is fixed now, not queued. Never disable the hook and never dodge the pattern; if the correct boundary is unclear, tell the user and stop."

die() {
    printf 'no-slop: %s\n' "$*" >&2
    exit 2
}

hint_for() {
    case $1 in
        step-narration) echo "If the steps need labels the function is too long: extract named functions and delete the labels." ;;
        banner) echo "A banner means the file holds several things: split them and the banner goes with them." ;;
        section-label) echo "Structure is the file's job, not a comment's." ;;
        signature-echo) echo "Types are documentation: fold the description into the prose or delete the tag." ;;
        todo-anchor) echo "Allowed form: TODO(<path>.md#<item>): <what>. Fix it now, or write it into the backlog and drop the comment." ;;
        run-cap) echo "State the constraint, delete the derivation. Long reasoning belongs in the commit message or a README." ;;
        width) echo "Wrap the comment at 120 characters or shorten it." ;;
        changelog) echo "A comment must be true for a reader who never sees this diff. What changed goes in the commit message." ;;
        roadmap) echo "Delete the comment or state the constraint timelessly. Plans belong in the backlog." ;;
        commented-out-code) echo "Delete commented-out code; git keeps it." ;;
        ticket-id) echo "Ticket ids mean nothing to the next reader: keep the sentence, delete the id." ;;
        go-package-doc) echo "A Go package comment is one line." ;;
        banned-name) echo "Name the responsibility: no Manager/Helper/Util/Wrapper types, no bare handle/process/execute, no utils or helpers files." ;;
        *) echo "" ;;
    esac
}

lang_of() {
    local base=${1##*/} ext
    case $base in
        Dockerfile | *.Dockerfile | Makefile) echo hash; return ;;
    esac
    ext=${base##*.}
    [ "$ext" = "$base" ] && return 0
    case $ext in
        kt | kts | java | go | swift | ts | tsx | js | mjs | cjs | rs | c | h | cpp | scala | dart) echo slash ;;
        py | sh | bash | zsh | yml | yaml | toml | rb) echo hash ;;
        sql) echo dash ;;
        md) echo md ;;
    esac
}

ext_of() {
    local base=${1##*/}
    case $base in
        Dockerfile | *.Dockerfile | Makefile) echo "$base"; return ;;
    esac
    echo "${base##*.}"
}

cfg_get() {
    [ -f "$2" ] || return 0
    sed -n "s/^[[:space:]]*$1=//p" "$2" | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

CFG_TICKET=""
CFG_EXEMPT=""
CFG_ANCHOR=""

load_config() {
    local file=$1
    CFG_TICKET=$(cfg_get ticket_regex "$file")
    CFG_EXEMPT=$(cfg_get exempt "$file")
    CFG_ANCHOR=$(cfg_get todo_anchor "$file")
    if [ -n "$CFG_TICKET" ]; then
        printf '' | grep -E -e "$CFG_TICKET" > /dev/null 2>&1
        if [ $? -eq 2 ]; then
            printf 'no-slop: ignoring invalid ticket_regex in %s\n' "$file" >&2
            CFG_TICKET=""
        fi
    fi
}

is_claude_kit_repo() {
    [ -f "$1/plugin/scripts/no-slop.sh" ] && [ -f "$1/.claude-plugin/marketplace.json" ]
}

is_exempt() {
    local root=$1 rel=$2 glob
    case $rel in
        CLAUDE.md | */CLAUDE.md) return 0 ;;
    esac
    if [ -n "$root" ] && is_claude_kit_repo "$root"; then
        case $rel in
            plugin/scripts/no-slop.sh | plugin/false-positives.md | test/fixtures/*) return 0 ;;
        esac
    fi
    local words
    IFS=' ' read -r -a words <<< "$CFG_EXEMPT"
    for glob in ${words[@]+"${words[@]}"}; do
        glob=${glob//\*\*/\*}
        # shellcheck disable=SC2254
        case $rel in $glob) return 0 ;; esac
    done
    return 1
}

is_banned_basename() {
    local base=${1##*/}
    case $base in
        utils.* | helpers.* | util.go | Utils.kt | Helpers.kt | common.kt) return 0 ;;
    esac
    return 1
}

# Scans $1 as the full text of a file named $2. Emits start<TAB>end<TAB>rule<TAB>text records.
scan_text() {
    local file=$1 name=$2 lang ext out
    lang=$(lang_of "$name")
    [ -z "$lang" ] && return 0
    ext=$(ext_of "$name")
    out=$TMP/scan.out
    NS_LANG=$lang NS_EXT=$ext NS_ANCHOR=$CFG_ANCHOR NS_WANTC=${CFG_TICKET:+1} \
        LC_ALL=C awk "$AWK_SCAN" "$file" > "$out"
    awk -F'\t' '$1 == "V" { print $2 "\t" $3 "\t" $4 "\t" $5 }' "$out"
    if [ -n "$CFG_TICKET" ] && [ "$lang" != md ]; then
        awk -F'\t' '$1 == "C" { print $3 }' "$out" > "$TMP/ctext"
        awk -F'\t' '$1 == "C" { print $2 "\t" $4 }' "$out" > "$TMP/cmeta"
        LC_ALL=C grep -n -E -e "$CFG_TICKET" "$TMP/ctext" | cut -d: -f1 > "$TMP/chits"
        awk -F'\t' 'FILENAME == ARGV[1] { h[$1] = 1; next } (FNR in h) { print $1 "\t" $1 "\tticket-id\t" $2 }' \
            "$TMP/chits" "$TMP/cmeta"
    fi
}

# Keeps only records whose line range touches a line listed in file $1.
filter_added() {
    awk -F'\t' 'FILENAME == ARGV[1] { a[$1] = 1; next }
        { for (i = $1; i <= $2; i++) if (i in a) { print; break } }' "$1" -
}

nearest_existing_dir() {
    local d=$1
    while [ ! -d "$d" ] && [ "$d" != "/" ] && [ -n "$d" ]; do d=$(dirname "$d"); done
    echo "$d"
}

canonical_path() {
    local path=$1 dir tail=""
    dir=$path
    while [ ! -d "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        tail="/$(basename "$dir")$tail"
        dir=$(dirname "$dir")
    done
    printf '%s%s' "$(cd "$dir" && pwd -P)" "$tail"
}

emit_deny() {
    local message=$1
    jq -n --arg reason "$message" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
}

check_pair() {
    local old=$1 new=$2 name=$3
    if [ -s "$old" ]; then
        awk 'FILENAME == ARGV[1] { o[$0] = 1; next } !($0 in o) { print FNR }' "$old" "$new" > "$TMP/added"
    else
        awk '{ print NR }' "$new" > "$TMP/added"
    fi
    scan_text "$new" "$name" | filter_added "$TMP/added" >> "$TMP/hook.records"
}

hook_mode() {
    local event tool file canon dir root rel i count
    event=$(cat)
    tool=$(printf '%s' "$event" | jq -r '.tool_name // empty')
    case $tool in
        Write | Edit | MultiEdit) ;;
        *) exit 0 ;;
    esac
    file=$(printf '%s' "$event" | jq -r '.tool_input.file_path // empty')
    [ -z "$file" ] && exit 0
    case $file in
        /tmp/* | /private/tmp/* | /var/folders/* | /private/var/folders/* | */scratchpad/*) exit 0 ;;
        "$HOME"/.claude/projects/*/memory/*) exit 0 ;;
    esac

    canon=$(canonical_path "$file")
    dir=$(nearest_existing_dir "$(dirname "$canon")")
    root=$(git -C "$dir" rev-parse --show-toplevel 2> /dev/null || true)
    rel=$canon
    [ -n "$root" ] && rel=${canon#"$root"/}
    [ -n "$root" ] && [ -z "${NO_SLOP_CONFIG:-}" ] && load_config "$root/.claude/comment-rules"
    [ -n "${NO_SLOP_CONFIG:-}" ] && load_config "$NO_SLOP_CONFIG"
    is_exempt "$root" "$rel" && exit 0
    case $canon in
        "$HOME"/.claude/CLAUDE.md) exit 0 ;;
    esac

    : > "$TMP/hook.records"
    case $tool in
        Write)
            printf '%s' "$event" | jq -j '.tool_input.content // empty' > "$TMP/new"
            if [ -f "$file" ]; then
                cp "$file" "$TMP/old"
            else
                : > "$TMP/old"
                if [ -n "$(lang_of "$file")" ] && is_banned_basename "$file"; then
                    printf '1\t1\tbanned-name\t%s\n' "${file##*/}" >> "$TMP/hook.records"
                fi
            fi
            check_pair "$TMP/old" "$TMP/new" "$file"
            ;;
        Edit)
            printf '%s' "$event" | jq -j '.tool_input.old_string // empty' > "$TMP/old"
            printf '%s' "$event" | jq -j '.tool_input.new_string // empty' > "$TMP/new"
            check_pair "$TMP/old" "$TMP/new" "$file"
            ;;
        MultiEdit)
            count=$(printf '%s' "$event" | jq -r '(.tool_input.edits // []) | length')
            i=0
            while [ "$i" -lt "$count" ]; do
                printf '%s' "$event" | jq -j ".tool_input.edits[$i].old_string // empty" > "$TMP/old"
                printf '%s' "$event" | jq -j ".tool_input.edits[$i].new_string // empty" > "$TMP/new"
                check_pair "$TMP/old" "$TMP/new" "$file"
                i=$((i + 1))
            done
            ;;
    esac

    [ -s "$TMP/hook.records" ] || exit 0
    local message rules="" rule hints=""
    message="Comment-hygiene gate blocked this edit of $rel:"
    while IFS=$'\t' read -r _ _ rule text; do
        message="$message
- $rule: $text"
        case " $rules " in
            *" $rule "*) ;;
            *) rules="${rules:-} $rule"; hints="$hints
$rule: $(hint_for "$rule")" ;;
        esac
    done < <(head -n 20 "$TMP/hook.records")
    message="$message
$hints

$ESCAPE_TEXT"
    emit_deny "$message"
    exit 0
}

print_records() {
    local path=$1 rec_start rec_rule rec_text
    while IFS=$'\t' read -r rec_start _ rec_rule rec_text; do
        printf '%s:%s: %s: %s\n' "$path" "$rec_start" "$rec_rule" "$rec_text"
    done
}

VIOLATING_FILES=0
SCANNED_FILES=0
WALKED_FILES=0

report_file() {
    local path=$1 records=$2
    [ -s "$records" ] || return 0
    VIOLATING_FILES=$((VIOLATING_FILES + 1))
    print_records "$path" < "$records"
}

tree_mode() {
    local root f src_total
    root=$(git rev-parse --show-toplevel 2> /dev/null) || die "--tree must run inside a git repository"
    cd "$root" || die "cannot enter $root"
    load_config "${CFG_FILE:-$root/.claude/comment-rules}"
    git ls-files -z > "$TMP/tree.list"
    while IFS= read -r -d '' f; do
        [ -f "$f" ] || continue
        [ -n "$(lang_of "$f")" ] || continue
        WALKED_FILES=$((WALKED_FILES + 1))
        is_exempt "$root" "$f" && continue
        SCANNED_FILES=$((SCANNED_FILES + 1))
        scan_text "$f" "$f" > "$TMP/file.records"
        if is_banned_basename "$f"; then printf '1\t1\tbanned-name\t%s\n' "${f##*/}" >> "$TMP/file.records"; fi
        report_file "$f" "$TMP/file.records"
    done < "$TMP/tree.list"

    src_total=$(git ls-files | grep -c -E '\.(kt|kts|java|go|swift|ts|tsx|js|mjs|cjs|rs|c|h|cpp|scala|dart|py|sh|bash|zsh|yml|yaml|toml|rb|sql|md)$|(^|/)(Dockerfile|Makefile)$|\.Dockerfile$' || true)
    if [ "$WALKED_FILES" -lt 20 ] && [ "$src_total" -gt "$WALKED_FILES" ]; then
        printf 'FAIL: walked %s of %s tracked source files. The walk is broken, not the tree clean.\n' "$WALKED_FILES" "$src_total"
        exit 1
    fi
    printf 'files with violations: %s of %s scanned\n' "$VIOLATING_FILES" "$SCANNED_FILES"
    if [ -n "${CEILING:-}" ]; then
        if [ "$VIOLATING_FILES" -gt "$CEILING" ]; then
            printf 'FAIL: %s files with violations, ceiling is %s.\n' "$VIOLATING_FILES" "$CEILING"
            exit 1
        fi
        if [ "$VIOLATING_FILES" -lt "$CEILING" ]; then
            printf 'Lower the ceiling to %s in the same commit.\n' "$VIOLATING_FILES"
        fi
        exit 0
    fi
    [ "$VIOLATING_FILES" -eq 0 ] || exit 1
    exit 0
}

diff_pass() {
    local label=$1 show_prefix=$2
    shift 2
    local k a b cur="" curnew=0 added=$TMP/added
    git -c core.quotepath=off diff -U0 --no-color --diff-filter=ACMR "$@" > "$TMP/diff.out" 2> "$TMP/diff.err" ||
        die "git diff failed for $label: $(cat "$TMP/diff.err"). In CI check out with fetch-depth: 0."
    awk '
        /^diff --git / { isnew = 0; next }
        /^new file mode/ { isnew = 1; next }
        /^\+\+\+ b\// { path = substr($0, 7); sub(/\t.*$/, "", path); print "F\t" path "\t" isnew; next }
        /^@@ / { match($0, /\+[0-9]+/); ln = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
        /^\+/ && !/^\+\+\+ / { print "A\t" ln; ln++ }
    ' "$TMP/diff.out" > "$TMP/diff.parsed"

    flush_diff_file() {
        [ -n "$cur" ] || return 0
        [ -n "$(lang_of "$cur")" ] || return 0
        is_exempt "$ROOT" "$cur" && return 0
        git show "${show_prefix}${cur}" > "$TMP/content" 2> /dev/null || return 0
        SCANNED_FILES=$((SCANNED_FILES + 1))
        scan_text "$TMP/content" "$cur" | filter_added "$added" > "$TMP/file.records"
        if [ "$curnew" = 1 ] && is_banned_basename "$cur"; then printf '1\t1\tbanned-name\t%s\n' "${cur##*/}" >> "$TMP/file.records"; fi
        report_file "$cur" "$TMP/file.records"
    }

    : > "$added"
    while IFS=$'\t' read -r k a b; do
        case $k in
            F) flush_diff_file; cur=$a; curnew=$b; : > "$added" ;;
            A) printf '%s\n' "$a" >> "$added" ;;
        esac
    done < "$TMP/diff.parsed"
    flush_diff_file
}

diff_mode() {
    ROOT=$(git rev-parse --show-toplevel 2> /dev/null) || die "--diff must run inside a git repository"
    cd "$ROOT" || die "cannot enter $ROOT"
    load_config "${CFG_FILE:-$ROOT/.claude/comment-rules}"
    if [ -n "$BASE" ]; then diff_pass "$BASE...HEAD" "HEAD:" "$BASE...HEAD"; fi
    if [ "$STAGED" = 1 ]; then diff_pass "the index" ":" --cached; fi
    [ "$VIOLATING_FILES" -eq 0 ] || exit 1
    exit 0
}

usage() {
    cat << 'USAGE'
no-slop.sh                       PreToolUse hook: reads the event JSON on stdin
no-slop.sh --diff <base> [--staged]   check lines added in <base>...HEAD (and the index)
no-slop.sh --tree [--ceiling N]       check every tracked file
Options: --config <file> reads rules from <file> instead of <root>/.claude/comment-rules
USAGE
}

if [ $# -eq 0 ]; then
    hook_mode
fi

MODE=""
BASE=""
STAGED=0
CEILING=""
CFG_FILE=${NO_SLOP_CONFIG:-}
while [ $# -gt 0 ]; do
    case $1 in
        --diff)
            [ $# -ge 2 ] || die "--diff needs a base ref"
            MODE="diff"
            BASE=$2
            shift 2
            ;;
        --staged) MODE=${MODE:-"diff"}; STAGED=1; shift ;;
        --tree) MODE="tree"; shift ;;
        --ceiling)
            [ $# -ge 2 ] || die "--ceiling needs a number"
            CEILING=$2
            shift 2
            ;;
        --config)
            [ $# -ge 2 ] || die "--config needs a file"
            CFG_FILE=$2
            shift 2
            ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; die "unknown argument: $1" ;;
    esac
done

case $MODE in
    diff) diff_mode ;;
    tree) tree_mode ;;
    *) usage >&2; exit 2 ;;
esac
