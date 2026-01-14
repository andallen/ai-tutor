#!/usr/bin/env node
// HTML Screenshot with scroll support using Playwright
// Usage: node html-capture.mjs <file> <output> [--scroll=id|pixels] [--width=1470] [--height=900]

import { chromium } from 'playwright';
import path from 'path';

const args = process.argv.slice(2);
const file = args.find(a => !a.startsWith('--'));
const output = args.find((a, i) => !a.startsWith('--') && i > 0) || '/tmp/capture.png';

// Parse options
const opts = {};
args.filter(a => a.startsWith('--')).forEach(a => {
    const [key, val] = a.slice(2).split('=');
    opts[key] = val;
});

const width = parseInt(opts.width || '1470');
const height = parseInt(opts.height || '900');
const scroll = opts.scroll;

if (!file) {
    console.error('Usage: node html-capture.mjs <file.html> [output.png] [--scroll=elementId|pixels] [--width=1470] [--height=900]');
    process.exit(1);
}

async function capture() {
    const browser = await chromium.launch();
    const page = await browser.newPage();
    await page.setViewportSize({ width, height });

    const fileUrl = file.startsWith('file://') ? file : `file://${path.resolve(file)}`;
    await page.goto(fileUrl, { waitUntil: 'networkidle' });

    // Scroll if specified
    if (scroll) {
        if (/^\d+$/.test(scroll)) {
            await page.evaluate((y) => window.scrollTo(0, parseInt(y)), scroll);
        } else {
            await page.evaluate((id) => {
                const el = document.getElementById(id);
                if (el) el.scrollIntoView({ block: 'start' });
            }, scroll);
        }
        await page.waitForTimeout(200);
    }

    await page.screenshot({ path: output });
    console.log(`Screenshot saved: ${output}`);
    await browser.close();
}

capture().catch(e => { console.error(e.message); process.exit(1); });
