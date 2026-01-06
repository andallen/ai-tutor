Stage and commit changes to the main branch. Then, do the following:

One-by-one, for each BRANCH under "Branches to merge into", execute the following workflow. Take into account that the branches are likely in worktrees:

1. Merge the main branch into BRANCH
2. Resolve all conflicts if any arise; prioritize the main branch's code but exercise common sense; try your best to make it so that main's code doesn't cancel out BRANCH's code/functionality
3. Commit in BRANCH

## Branches to merge into
$ARGUMENTS
