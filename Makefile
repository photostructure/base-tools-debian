.PHONY: update-pins validate regression-test chunky-bacon

update-pins:
	pinact run -u

validate:
	docker build --target builder -t base-tools-debian:test .

# Builds, then diffs the fresh binaries against the published image over the
# vendored corpus in test/fixtures: one complete RAW identified and demosaiced,
# one truncated RAW rejected, ten JPEGs transformed, and SQLite exercised. An
# empty diff means the bump changed no observable behavior in those cases.
#
# Needs a network pull of the published image, so it's a separate target rather
# than part of `validate`.
regression-test: validate
	./.claude/skills/update/run-regression-test.sh

# Run everything before we do a release -- claude will run the update-pins and
# regression tests for us.
chunky-bacon:
	claude "/update"
