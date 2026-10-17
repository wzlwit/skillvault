
# Publishing

Contents: Before any write; Commits; Create; Update; Draft state; After a write.

Use this procedure whenever `/pr-publish` publishes, alone or with plain-word adjustments. `$publish`
is the verified absolute path of the bundled [helper](../scripts/pr-publish.ps1); run it from the
repository with PowerShell 7.

## Before any write

1. Run `& $publish -Action Status -Fetch`. It first fetches origin's copy of the base and of this
   branch, which changes no files or branches; when the fetch fails (`fetched` is false), say that
   the behind count may be out of date and go on. Stop on a detached HEAD. On the base branch with
   nothing uncommitted, stop: there is nothing to publish. When the request names a PR by URL or
   number, Status must report that PR as the branch's open PR, in the current repository or a local
   checkout the request names (`-RepositoryPath`); otherwise stop and say so.
2. With uncommitted changes (`uncommittedFiles` above 0), unless the request says to leave them out,
   plan the commits as in [Commits](#commits) and check the plan with
   `& $publish -Action Commit -PlanFile <plan>`. It refuses a plan that misses or repeats a change.
3. When the branch is behind its base (`behind` above 0), run `& $publish -Action Rebase` without
   `-Apply`. It reports whether rebasing rewrites commits already pushed (`forcePush`) and the
   remote commit a force push would replace (`expectedRemoteHead`).
4. Write the files under the [description rules](description.md): the table, and for a new PR the
   title and description. Run the `Publish` command below without `-Apply`: it reports what would
   change, writes the resulting description to a local file (`bodyFile`), lists check findings, and
   says whether the branch is pushed. When the plan moves the work off the base branch, check the
   drafted description, with its table, through `& $publish -Action Check -BodyFile <file>` instead.
5. Show the planned commits (the branch, each commit's subject and files, and any files left out),
   how far behind the base the branch is, the push, and the preview. Ask once with the host's
   question tool when there are planned commits:
   - **Commit and publish** (the default): commit through `& $publish -Action Commit -PlanFile <plan> -Apply`, then go on.
   - **Rebase first**, offered only when the branch is behind: commit, then rebase through
     `& $publish -Action Rebase -Apply`. When `forcePush` is true, the option names the force push
     of this branch over `expectedRemoteHead`, so choosing it approves exactly that push.
   - **Hold**, or no answer: write nothing.

   Without planned commits, publish at once and as is, because `/pr-publish` itself is the request;
   the report says how far behind the base the branch is and that "rebase first" updates it. A
   request that says "rebase first" rebases without asking, unless it needs a force push: then ask
   once, naming it. A request that says "show me first" stops here.
6. Push with `& $publish -Action Push -Apply`. It sets the upstream on origin for a new branch and
   does nothing when the branch is already pushed. After an approved rebase that needs a force
   push, add `-ExpectedRemoteHead <expectedRemoteHead>`: it pushes with a lease on exactly that
   commit and refuses if the remote moved. Otherwise, when the remote branch has commits the local
   one lacks, it stops: ask whether to pull or force-push.
7. Publish with `-Apply`, as in Create or Update below.

A rebase that hits conflicts is undone and nothing is pushed: report the conflict and leave it to
the user. The commits made before it stay.

## Commits

Plan commits from every uncommitted change that Status counts: staged, unstaged, and untracked.

- Group by concern and commit whole files. A file with several concerns goes with its main one, and
  a partly staged file is committed whole.
- Keep tests with the code they test, so each commit builds on its own. Give docs or configuration
  their own commit when they stand alone, and make one commit when everything is one change.
- Include an untracked file only when it belongs to the change, and list every other change under
  `exclude`; it stays uncommitted. Never commit secrets, credentials, build output, logs, or
  temporary files: exclude them and say so in the question.
- Write messages in the repository's style, from its recent `git log`: an imperative subject under
  72 characters, then a short body when it helps. Repository hooks run; never skip them.
- On the base branch, name a new branch in the plan after the repository's branch names, such as
  `users/<alias>/<topic>`.

Save the plan as JSON in the OS temporary folder. Paths are repository-relative, and `branch` is
only for leaving the base branch:

```json
{
  "branch": "users/alias/round-halves",
  "commits": [
    { "message": "Round halves up\n\n- Round 2.5 to 3 in totals.", "files": ["src/Rounding.cs", "tests/RoundingTests.cs"] },
    { "message": "Document rounding", "files": ["docs/rounding.md"] }
  ],
  "exclude": ["scratch.log"]
}
```

The helper starts from an empty index, stages each commit's files, checks that exactly those files
are staged, and commits. When a commit fails, for example because a hook rejects it, the helper stops
and reports the commits already made; nothing is pushed.

## Create

Follow the `create-pull-request` skill for the title and description, but not its draft, commit,
push, or reporting steps: the PR opens ready for review, commits follow [Commits](#commits), the
push goes through `-Action Push`, and the report follows After a write.

1. If the VS Code `github-pull-request_create_pull_request` tool is available, use it with the
   branch name only (not `owner:branch`), the base, the title, the previewed `bodyFile` text, and
   `draft: false`.
2. If that tool is missing or fails (for example, "has no GitHub remotes"), run
   `& $publish -Action Publish -Title <title> -BodyFile <description-file> -TableFile <table-file> -Apply`.
   It checks that no open PR exists for the branch, then creates it through the REST API.

## Update

`& $publish -Action Publish -TableFile <table-file> -Apply` adds the table to the open PR's live
description, or replaces its Current vs. to-be section, and changes nothing else. Add
`-BodyFile <file>` or `-Title <title>` only when the request says "rewrite the description" or asks
for a new title. Before replacing text, the helper saves the current title and description to a temporary
file and reports its path; an unchanged description isn't written again.

`gh pr edit` can fail on GitHub Enterprise with "Projects (classic) is being deprecated" and change
nothing, so the helper uses the REST API. It also switches the console to UTF-8 around every `gh`
call, because capturing UTF-8 output through another code page corrupts non-ASCII text.

## Draft state

pr-publish never changes it on its own: a new PR opens ready for review and an existing PR keeps its
state. When the request says "ready", run `gh pr ready <number>` to mark the PR ready; when it says
"as draft", run `gh pr ready <number> --undo` to make it a draft, right after creating it for a new PR.

## After a write

The helper reads the PR back and fails if the title, description, or draft state differs from
what it sent. Report the PR number, base, head commit, draft state, any backup path, and end with
the PR link. Leave reviewers, labels, comments, and merging to the user.
