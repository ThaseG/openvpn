# Git workflow

Commit messages **MUST** follow the [Gitmoji](https://gitmoji.dev) convention.

New changes **MUST** be done in a separated branch with a dedicated Merge Request.

# Merge Requests

Merge Requests **MUST** be reviewed before being merged.

Merge requests **SHOULD** rebase their branch on `devel` before merging to avoid merge conflicts.

# Versionning

New versions **MUST** be created via a git tag of the following format: `v$MAJOR.$MINOR.$PATCH`.

Version numbers **MUST** follow Semantic Versionning.

Major version of OpenVPN must reflect a change in MINOR number. Patch number is reflecting in a change in this repository.

# Architecture Decision Records

Merge Requests act as ADR.

An ADR is a record of "why" things are done in a certain way. This is important
for onboarding new people on the project as they can just go through the
history of ADR to understand the project.
