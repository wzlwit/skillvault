# Schedule Manager

List Windows scheduled tasks with indexes, then enable, disable, or delete selected tasks by
index, comma list, range, or keyword after confirmation.

Examples:

```text
/schedule-manager
/schedule-manager enable 2
/schedule-manager disable SkillVault
/schedule-manager delete 2
/schedule-manager delete 1,3-5
/schedule-manager delete SkillVault
```

`enable` allows future triggered runs; it does not run the task immediately. `disable`
retains the definition and prevents future scheduled runs; it does not stop a running
instance. `delete` removes the task definition. `remove` and `uninstall` alias `delete`.

The script previews every selected action unless `-Force` is supplied after confirmation.
Run `scripts/test-schedule-manager.ps1` from the repository root for fake-task checks that
do not change any real Windows schedules.