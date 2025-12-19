Dashboard
The Dashboard is the screen the user sees first. It shows a list of Notebooks and provides the actions the user expects: create a new Notebook, rename a Notebook, delete a Notebook, and open a Notebook. The Dashboard should not contain storage logic. It should only display information and forward user actions to the Notebook Library.

Notebook Library
The Notebook Library is the part of the code that the Dashboard talks to. Its job is to translate Dashboard actions into concrete operations and keep the Dashboard list accurate. The Notebook Library asks the Bundle Manager for the current list of Notebooks, and it requests create, rename, delete, and open operations. The Notebook Library does not read or write files. It treats the Bundle Manager as the one place that knows how Notebooks are stored.

Bundle
A Bundle is the on-disk folder that stores everything for exactly one Notebook. The user never sees the Bundle directly. The Bundle is simply the physical representation of the Notebook on disk.

Manifest
The Manifest is a JSON file inside the Bundle. It is the authoritative list of what ink exists in the Notebook and where that ink belongs on the Notebook canvas. At this stage the Manifest only needs to describe ink. Later you can extend it to list other kinds of content, but for now it should be narrowly focused.

Bundle Manager
The Bundle Manager is the only code allowed to perform direct file operations on the Bundle. If any other part of the app needs to create a Notebook, load a Notebook, save ink, rename a Notebook, or delete a Notebook, it must do so through the Bundle Manager. This is important because it prevents file-system logic from spreading across the app and becoming inconsistent.
⸻
Additional terms used in this architecture

Notebook Editor
The Notebook Editor is the screen that displays a single Notebook and lets the user write ink. It is responsible for the editing experience (drawing, scrolling, zooming, and showing ink on screen). It is not responsible for directly reading and writing files.

Notebook Model
The Notebook Model is the in-memory representation of what is inside the Notebook. It is built by reading the Manifest when the Notebook is opened. It contains a list of ink “chunks” that exist and the basic information needed to render them, such as their positions and sizes on the canvas.

Ink Item
An Ink Item is one chunk of ink content. Instead of storing all ink for the entire Notebook in one enormous file, the Notebook is stored as multiple Ink Items. Each Ink Item has:
- an identifier
- a rectangular region on the Notebook canvas (x, y, width, height in Notebook coordinates)
- a reference to where the ink data is saved inside the Bundle

The actual ink data for an Ink Item is stored as its own file inside the Bundle.

Document Handle
A Document Handle is what the Bundle Manager returns when a Notebook is opened. It represents “this specific open Notebook Bundle” and gives the Notebook Editor a controlled way to request loads and saves without exposing file paths everywhere.

Viewport Controller
The Viewport Controller is responsible for deciding which Ink Items should be loaded into memory at any moment. The Notebook can become very long, so you should not load every Ink Item all at once. The Viewport Controller watches the visible area of the screen (the part of the Notebook the user can currently see) and requests ink data only for Ink Items that are near that visible region.

Commit Policy
The Commit Policy defines when newly drawn ink becomes a new Ink Item (or updates an existing Ink Item). When the user draws, you temporarily hold that ink in a “working” state. The Commit Policy decides when that working ink should be finalized into a saved chunk. Typical triggers are:
- the user pauses drawing for a moment
- the user scrolls away from the current area
- the working ink grows beyond a size threshold

The specific triggers can be simple at first, but you want the concept of a Commit Policy early so ink does not become one constantly-growing blob.

Save Coordinator
The Save Coordinator is a responsibility inside the Bundle Manager. Its job is to perform safe saving. It writes or updates the ink payload files and then updates the Manifest in a way that minimizes the risk of corruption if the app is interrupted.
⸻
What is stored in the Bundle at this stage

Inside each Bundle you should have, at minimum:

1. The Manifest (JSON) 
2. This contains:
- a unique Notebook identifier
- a display name (or some reference to it)
- a version number (so you can change formats later)
- a list of Ink Items, each with:
    - id
    - rectangle on the Notebook canvas
    - path to the payload file inside the Bundle

2. The ink payload files 
3. These are stored under a dedicated folder inside the Bundle (for example, “ink/”). Each file corresponds to one Ink Item.
⸻
How the main workflows happen

Workflow 1: The Dashboard needs to show the list of Notebooks
1. The Dashboard asks the Notebook Library for the list of Notebooks.
2. The Notebook Library asks the Bundle Manager to list existing Bundles.
3. The Bundle Manager scans the storage location where Bundles are kept, reads whatever minimal metadata is needed (for example, the display name), and returns a list to the Notebook Library.
4. The Notebook Library provides that list to the Dashboard for display.

Workflow 2: The user creates a Notebook
1. The Dashboard tells the Notebook Library that the user wants to create a Notebook.
2. The Notebook Library requests creation from the Bundle Manager.
3. The Bundle Manager creates a new Bundle folder, writes an initial Manifest, and creates an ink folder inside the Bundle.
4. The Bundle Manager returns the new Notebook’s identifier and metadata to the Notebook Library.
5. The Notebook Library updates the Dashboard list.

Workflow 3: The user renames or deletes a Notebook
Rename:
1. Dashboard action goes to Notebook Library.
2. Notebook Library requests rename from Bundle Manager.
3. Bundle Manager updates the stored name (in the Manifest or in a dedicated metadata file).
4. Notebook Library updates the Dashboard list.

Delete:
1. Dashboard action goes to Notebook Library.
2. Notebook Library requests delete from Bundle Manager.
3. Bundle Manager deletes the Bundle folder from disk.
4. Notebook Library updates the Dashboard list.

Workflow 4: The user opens a Notebook and starts writing
1. The Dashboard tells the Notebook Library which Notebook the user wants to open.
2. The Notebook Library asks the Bundle Manager to open that Notebook.
3. The Bundle Manager reads the Manifest, validates it, and returns a Document Handle.
4. The Notebook Editor builds the Notebook Model from the Manifest.
5. The Viewport Controller determines which Ink Items are visible and requests their payloads from the Bundle Manager through the Document Handle.
6. The Notebook Editor renders those Ink Items on the canvas.
7. The user draws new ink. That new ink is held as working ink until the Commit Policy triggers a commit.
8. When the Commit Policy triggers, the Notebook Editor produces a new Ink Item (or updates an existing one), updates the Notebook Model, and requests a save through the Bundle Manager.
9. The Bundle Manager (through the Save Coordinator) writes the ink payload file and then updates the Manifest so the new Ink Item is listed and will reappear on the next open.

Goal for the first complete version
You will know you are done when a user can: open the app, create a Notebook on the Dashboard, open it, write ink on a long scrolling canvas, close the app, reopen it, and see the same ink again.