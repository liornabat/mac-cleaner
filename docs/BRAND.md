# MacClean artwork

The app and launcher share a cobalt-blue tile with a silver storage drive, cleaning brush, and a single glint. The tile has transparent outer margins. Native sidebar lettering remains system text rather than baked into the bitmap, so it stays sharp and accessible.

Master: `Sources/MacClean/Resources/MacCleanIcon.png` (1254 × 1254, PNG with alpha).

`scripts/build-icons.sh` derives standard macOS icon resolutions from this master with `sips`, then creates `dist/MacClean.icns` with `iconutil`. `scripts/build-app.sh` copies the PNG and icon into standard bundle resources and declares the launcher icon in `Info.plist`. The native application also sets its runtime icon, including when started through Swift Package Manager.

Generated with the built-in image-generation tool. Final generation prompt:

> Use case: logo-brand. Asset type: one production macOS app icon master for MacClean, a personal Mac storage and developer-cache cleaning utility. Create a beautifully crafted, distinctive square app icon centered on a truly transparent canvas. The app uses a restrained cobalt blue accent. Subject: a friendly precision cleaning brush angled across a compact silver storage drive, with one small crisp white four-point glint where the brush meets the drive; simplify into a memorable, coherent sculpted symbol. Cobalt blue rounded-square icon tile, subtle premium satin depth and soft highlights, silver and white symbol, clear large silhouette, calm trustworthy character. The tile occupies about 86 percent of the square canvas with macOS-style superellipse corners, transparent margins outside it, square straight-on composition. Keep the drive and brush chunky enough to remain legible at 32 pixels; use very few details and no tiny dots or labels. No text, no letters, no mockup, no device scene, no watermark, no alternate versions. Deliver only a single high-quality square icon, ideally 1024 by 1024.
