#!/bin/zsh

set -euo pipefail

package_root="${0:A:h:h}"
check_only=false
if [[ "${1:-}" == "--check" ]]; then
    if [[ $# -ne 1 ]]; then
        print -u2 "usage: $0 [--check]"
        exit 2
    fi
    check_only=true
elif [[ $# -gt 0 ]]; then
    print -u2 "usage: $0 [--check]"
    exit 2
fi

typeset -a targets=(MaeumjaroDomain MaeumjaroIntents MaeumjaroPersistence)
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/maeumjaro-localizations.XXXXXX")"

for target in $targets; do
    resources="$package_root/Sources/$target/Resources"
    catalog="$resources/Localizable.xcstrings"
    generated="$temporary_root/$target"
    checked_in="$resources/ko.lproj/Localizable.strings"

    mkdir -p "$generated"
    xcrun xcstringstool compile "$catalog" \
        --output-directory "$generated" \
        --language ko \
        --serialization-format text

    if $check_only; then
        if [[ ! -f "$checked_in" ]] || ! cmp -s "$generated/ko.lproj/Localizable.strings" "$checked_in"; then
            print -u2 "localization is out of date: $checked_in"
            exit 1
        fi
    else
        mkdir -p "${checked_in:h}"
        cp "$generated/ko.lproj/Localizable.strings" "$checked_in"
    fi
done

if $check_only; then
    print "Localizable.strings are up to date."
else
    print "Generated Korean Localizable.strings from String Catalogs."
fi
print "Temporary compiler output: $temporary_root"
