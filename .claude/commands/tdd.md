---
description: Test-driven development workflow
---

## Feature to implement
$ARGUMENTS

## Mandatory test-driven development workflow to implement feature
1. Think and develop a plan to implement the feature. Use Protocol-Oriented Programming if applicable.
2. Call the tdd-contract-designer subagent, explaining the feature and the implementation plan to it and describing where in the project structure the feature will be implemented
2. Call the tdd-test-writer subagent, explaining the feature and directing it to the right Contract.swift file which was written by tdd-contract-designer
3. Iteratively do the following:
    - Using Protocol-Oriented Programming principles (if applicable), incrementally implement a part of the feature which will pass one or more of the tests written by tdd-test-writer (if the feature itself is incremental and/or there are very few simple tests, implement the whole feature)
    - Call the tdd-test-runner subagent to run the tests
    - If the tests you were aiming to pass passed, repeat the cycle until all tests are done. If the tests you were aiming to pass didn't pass, consider the feedback of tdd-test-runner and implement the needed changes required to pass the tests. Be very cautious about changing the tests themselves; only do so when there is a very clear and obvious flaw in the testing logic. Prioritize changing the real code.