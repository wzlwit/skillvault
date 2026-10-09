
# Publishing

Use this procedure for `upsert`. `$publish` is the verified absolute path of the bundled
[helper](../scripts/pr-publish.ps1); run it from the repository with PowerShell 7.

## Before any write

1. Run `& $publish -Action Status`. Stop on the base branch itself, on uncommitted changes the
   user hasn't chosen to leave out, or when the branch is behind its base and the user hasn't
   decided whether to rebase.
2. A new PR needs the branch pushed and equal to its upstream. Push only when the user asked for
   it; a history rewrite needs approval of that exact force-with-lease.
3. Write the files under the [description rules](description.md): the table, and for a new PR the
   title and description. Run the `Publish` command below without `-Apply`: it reports what would
   change, writes the resulting description to a local file (`bodyFile`), and lists check findings.
   Show that, then run the same command with `-Apply`.

## Create

Follow the `create-pull-request` skill for the title and description, but not its draft, commit,
push, or reporting steps: the PR opens ready for review, pr-publish doesn't commit for the user,
pushes only when asked, and reports as in After a write.

1. If the VS Code `github-pull-request_create_pull_request` tool is available, use it with the
   branch name only (not `owner:branch`), the base, the title, the previewed `bodyFile` text, and
   `draft: false`.
2. If that tool is missing or fails (for example, "has no GitHub remotes"), run
   `& $publish -Action Publish -Title <title> -BodyFile <description-file> -TableFile <table-file> -Apply`.
   It checks that no open PR exists for the branch, then creates it through the REST API.

## Update

`& $publish -Action Publish -TableFile <table-file> -Apply` adds the table to the open PR's live
description, or replaces its Current vs. to-be section, and changes nothing else. Add
`-BodyFile <file>` or `-Title <title>` only when the user asked to rewrite the description or change
the title. Before replacing text, the helper saves the current title and description to a temporary
file and reports its path; an unchanged description isn't written again.

`gh pr edit` can fail on GitHub Enterprise with "Projects (classic) is being deprecated" and change
nothing, so the helper uses the REST API. It also switches the console to UTF-8 around every `gh`
call, because capturing UTF-8 output through another code page corrupts non-ASCII text.

## Draft state

pr-publish never changes it: a new PR opens ready for review and an existing PR keeps its state.
When the user asks, run `gh pr ready <number>` to mark the PR ready, or
`gh pr ready <number> --undo` to make it a draft.

## After a write

The helper reads the PR back and fails if the title, description, or draft state differs from
what it sent. Report the PR number, base, head commit, draft state, any backup path, and end with
the PR link. Leave reviewers, labels, comments, and merging to the user.
