# Schedule Manage

List Windows scheduled tasks with indexes, filter them by a keyword or number, then enable,
disable, or delete selected tasks by index, comma list, range, or keyword after confirmation.

Examples:

```text
/schedule-manage
/schedule-manage SkillVault
/schedule-manage enable 2
/schedule-manage disable SkillVault
/schedule-manage delete 2
/schedule-manage delete 1,3-5
/schedule-manage delete SkillVault
```

`enable` allows future triggered runs; it does not run the task immediately. `disable`
retains the definition and prevents future scheduled runs; it does not stop a running
instance. `delete` removes the task definition.

The script previews every selected action unless `-Force` is supplied after confirmation.
Run `scripts/test-schedule-manage.ps1` from the repository root for fake-task checks that
do not change any real Windows schedules.
