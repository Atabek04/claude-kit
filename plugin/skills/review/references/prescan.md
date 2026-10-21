# Mechanical pre-scan

Run before drafting, and print the table even when every count is zero: it shows what was checked and anchors the
reviewer against skipping a rule. Counts are added lines of the diff (`DIFF` prints it, for example
`git diff -U0 origin/main...HEAD`); for a `path:` target scan the file contents instead. A hit is a lead to read,
never a finding by itself.

```bash
scan() { printf '%s=%s ' "$1" "$($DIFF | grep '^+' | grep -v '^+++' | grep -ciE "$2")"; }
scan force-unwrap '!!'           ; scan lateinit 'lateinit var'    ; scan field-value '@Value\('
scan eager 'FetchType\.EAGER'    ; scan find-all 'findAll\('       ; scan select-star 'select \*'
scan sleep 'Thread\.sleep'       ; scan synchronized 'synchronized' ; scan empty-catch 'catch \([^)]*\) *\{ *\}'
scan todo 'TODO|FIXME|HACK'      ; scan secret 'AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|sk-[A-Za-z0-9]{32}'
scan effect-fetch 'useEffect\(.*fetch\(' ; scan inner-html 'dangerouslySetInnerHTML'
scan local-token 'localStorage.*(token|jwt)' ; scan console 'console\.(log|debug)'
scan trust-all 'TrustAll|NoopHostnameVerifier|rejectUnauthorized: *false'
echo
```

Add the project's own rows in `.claude/review/prescan.sh` (one `name=count` per line) and run it when it exists. A
count that matches a reference check (`find-all` on a growing table, `synchronized` around I/O, `local-token`) makes
that check a candidate for its axis; the gates in SKILL.md section 4 still apply to each.
