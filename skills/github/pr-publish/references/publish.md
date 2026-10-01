
# Publishing

Use this procedure for `upsert`. `$publish` is the verified absolute path of the bundled
[helper](../scripts/pr-publish.ps1); run it from the repository with PowerShell 7.

## Before any write

1. Run `& $publish -Action Status`. Stop on the base branch itself, on uncommitted changes the
   user hasn't chosen to leave out, or when the branch is behind its base and the user hasn't
   decided whether to rebase.
2. A new PR needs the branch pushed and equal to its upstream. Push only when the user asked for
   it; a history rewrite needs approval of that exact force-with-lease.
3. Prepare the title and description file under the [description rules](description.md) and run
   `-Action Check` on it. Show the preview result before applying.

## Create

1. If the VS Code `github-pull-request_create_pull_request` tool is available, use it with the
   branch name only (not `owner:branch`), the base, the title, the description file's text, and
   `draft` only for `--draft`.
2. If that tool is missing or fails (for example, "has no GitHub remotes"), run
   `& $publish -Action Publish -Title <title> -BodyFile <file> [-Draft] -Apply`. It checks that no
   open PR exists for the branch, then creates it through the REST API.

## Update

`& $publish -Action Publish [-Title <title>] [-BodyFile <file>] [-Draft|-Ready] -Apply` updates
the branch's open PR. It saves the current title and description to a temporary file first and
reports its path. Title and description use one REST `PATCH`. Draft and ready use GraphQL
`convertPullRequestToDraft` and `markPullRequestReadyForReview`, because REST can't change them.
Without `-Apply`, `Publish` only reports what it would do.

`gh pr edit` can fail on GitHub Enterprise with "Projects (classic) is being deprecated" and change
nothing; the helper avoids it. It also switches the console to UTF-8 around every `gh` call,
because capturing UTF-8 output through another code page corrupts non-ASCII text.

## After a write

The helper reads the PR back and fails if the title, description, or draft state differs from
what it sent. Report the PR number, base, head commit, draft state, any backup path, and end with
the PR link. Leave reviewers, labels, comments, and merging to the user.
