You are making a UI-only change. Do not touch backend logic, APIs, databases, auth, or deployment. 

Before changing anything, follow this workflow and show your work:

1) Restate the request as UI behaviors, not code edits.
   - Describe in detail what the user should see and be able to do after the change.

2) Map the relevant UI surface area (dependency scan).
   - Identify the components, views, styles, state stores, routing, feature flags, and shared UI utilities that affect this screen.
   - Identify any accessibility, responsiveness, theming, localization, animation, or virtualization constraints that apply.

3) Conduct research online and do your own reasoning to think about what is generally the most common, clean, and effective approach to implementing the requested change. If this approach conflicts with the current architecture of the code, prioritize the optimal approach rather than the current architecture; refactor the code to ensure the optimal approach is used.

4) Decide the right scope: “smallest correct change.”
   - Propose 2–3 implementation options:
     A) Minimal patch
     B) Targeted refactor (preferred when dependencies make A unlikely to work perfectly)
     C) Larger cleanup (only if needed)
   - For each option, state what could break if done incorrectly.
   - Choose one option and justify it in terms of correctness and dependency safety.

4) Define acceptance checks before coding.
   - Write a short checklist of observable UI outcomes (including edge cases).
   - Include a “regression watchlist” for nearby UI elements likely to be affected.

5) Synthesize your implementation plan.

6) Make the change.
   - Implement the chosen option.
   - If you discover hidden dependencies mid-way, pause and widen the scope immediately rather than forcing a brittle patch.
   - Keep changes cohesive: if you introduce a new UI pattern, align it with existing shared components/utilities, but do not be afraid to refactor the code to prioritize an optimal clean implementation rather than a hacky one.


IMPORTANT TO KEEP IN MIND:
This app has five dashboard card types: (1) normal note on the main dashboard, (2) normal note in a folder overlay, (3) PDF note on the main dashboard, (4) PDF note in a folder overlay, and (5) folder card.

The app also has two note view types: normal note view and PDF note view.

When you make any change to a dashboard card, you must apply the same change to all five dashboard card types unless there is a clear, specific, or common sense reason it cannot or should not apply to one of them. If an exception is necessary, state which card type is excluded and why.

When you make any change to one note view, you must make the corresponding change in the other note view as well. Use common sense to avoid changes that would break or degrade PDF-specific behavior. If you intentionally diverge between the two note views, explicitly explain the difference and the reason.

—————

THE REQUESTED UI CHANGE IS AS FOLLOWS:
$ARGUMENTS