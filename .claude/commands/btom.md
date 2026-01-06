One-by-one, for each BRANCH under "Branches to merg from", execute the following workflow. Take into account that the branches are likely in worktrees:
1. Stage and commit the changes in BRANCH
2. Merge BRANCH into the main branch
3. Resolve all conflicts if any arise; since you are probably merging multiple branches into main, try to preserve as much of the code between all those branches as possible when merging so that one branch doesn't "cancel out" the other.
4. Update the CLAUDE.md file in the root of the main branch to reflect the new project structure if any updates were made
4. Commit in the MAIN brach

## Branches to merge from
$ARGUMENTS
