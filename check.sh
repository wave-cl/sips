#!/bin/sh
# Consistency checks for the SIP set. A documents repo cannot be tested, but it
# can drift, and these are the ways it does: a SIP with an incomplete preamble,
# one missing from the index, an index row pointing at nothing, or a
# cross-reference to a file that has been renamed.
set -u

fail=0
note() { printf '  %s\n' "$1"; fail=1; }

echo "preambles"
for f in sip-[0-9]*.md; do
    for field in SIP Title Author Status Type Layer Created; do
        grep -q "^${field}:" "$f" || note "$f: missing $field"
    done

    # The number in the preamble must match the number in the filename,
    # otherwise the index and the document disagree about what this is.
    declared=$(sed -n 's/^SIP: *//p' "$f" | head -1)
    from_name=$(echo "$f" | sed 's/^sip-0*\([0-9]*\)\.md$/\1/')
    [ "$declared" = "$from_name" ] ||
        note "$f: preamble says SIP $declared, filename says $from_name"

    status=$(sed -n 's/^Status: *//p' "$f" | head -1)
    case "$status" in
        Draft|Proposed|Active|Rejected|Withdrawn|Replaced) ;;
        *) note "$f: unknown status '$status'" ;;
    esac
done

echo "index"
for f in sip-[0-9]*.md; do
    grep -q "($f)" README.md || note "$f: not linked from the README index"
done
for linked in $(grep -o 'sip-[0-9]*\.md' README.md | sort -u); do
    [ -f "$linked" ] || note "README links $linked, which does not exist"
done

echo "cross-references"
for f in sip-[0-9]*.md README.md template.md; do
    for ref in $(grep -o 'sip-[0-9]*\.md' "$f" | sort -u); do
        [ -f "$ref" ] || note "$f references $ref, which does not exist"
    done
done

# Requires: must name SIPs that exist, or the dependency chain is fiction.
# template.md is skipped: its preamble is placeholder text, not a claim.
for f in sip-[0-9]*.md; do
    for n in $(sed -n 's/^Requires: *//p' "$f" | tr ',' ' '); do
        case "$n" in
            ''|*[!0-9]*) note "$f: Requires '$n' is not a SIP number"; continue ;;
        esac
        target=$(printf 'sip-%04d.md' "$n")
        [ -f "$target" ] || note "$f requires SIP $n, which does not exist"
    done
done

if [ "$fail" -eq 0 ]; then
    echo "ok — $(ls sip-[0-9]*.md | wc -l | tr -d ' ') SIPs consistent"
else
    echo "FAILED"
fi
exit "$fail"
