# Skill Icons

This directory contains custom icons for skills that appear in the AI chat overlay.

## How to Add a Custom Icon

1. **Prepare your icon image**:
   - Square image (recommended: 256x256 or larger)
   - PNG or JPG format
   - The image will be displayed as a circle, so design accordingly

2. **Name the file**:
   - Use the skill's ID as the filename
   - Example: For the Graphing Calculator skill (ID: `graphing-calculator`), name your file:
     - `graphing-calculator.png` or
     - `graphing-calculator.jpg`

3. **Add the file to this directory**:
   - Simply paste your image file into this directory
   - The app will automatically detect and load it

4. **Rebuild the app**:
   - Run `Scripts/buildapp` to include the new icon in the app bundle
   - The icon will appear in the skills box when you open the AI overlay

## Current Skills

- **graphing-calculator**: Graphing Calculator skill (no custom icon yet - shows placeholder circle)

## Notes

- If no custom icon exists, a light gray placeholder circle is shown
- PNG files are checked first, then JPG files
- Icons are displayed at 44x44 points with circular clipping
