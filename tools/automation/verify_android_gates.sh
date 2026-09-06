#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="$repo_root/app/src/main/AndroidManifest.xml"
main_src="$repo_root/app/src/main/java"
fail() { echo "FAIL: $*" >&2; exit 1; }

grep -q 'android:allowBackup="false"' "$manifest" || fail "allowBackup must be false"
grep -q 'android:dataExtractionRules="@xml/data_extraction_rules"' "$manifest" || fail "data extraction rules missing"
grep -q 'android:fullBackupContent="@xml/backup_rules"' "$manifest" || fail "legacy backup rules missing"
if grep -Eq 'android.permission.(INTERNET|ACCESS_NETWORK_STATE|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE)' "$manifest"; then
  fail "network or broad external-storage permission declared"
fi
if rg -n 'android\.util\.Log|println\(|Timber\.' "$main_src"; then
  fail "detailed logging API found in production source"
fi
for rules in "$repo_root/app/src/main/res/xml/backup_rules.xml" "$repo_root/app/src/main/res/xml/data_extraction_rules.xml"; do
  test -s "$rules" || fail "missing backup resource: $rules"
  grep -q 'domain="database" path="\."' "$rules" || fail "database is not excluded: $rules"
  grep -q 'path="datastore/"' "$rules" || fail "datastore is not excluded: $rules"
  grep -q 'path="events/"' "$rules" || fail "events are not excluded: $rules"
done
echo "PASS: offline, permission, logging, and backup-isolation static gates"
