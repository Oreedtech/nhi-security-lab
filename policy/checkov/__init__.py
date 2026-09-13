# Required for Checkov to load this directory via --external-checks-dir.
# Without it the loader imports nothing and the scan still exits 0, so a green build would
# mean only that the built-in ruleset passed. See the note in verify.yml.
