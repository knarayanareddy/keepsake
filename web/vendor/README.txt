ethers vendored from npm ethers@6.13.4 dist/ethers.min.js (ESM, 490KB). Rebuild: npm i ethers@6.13.4 && cp node_modules/ethers/dist/ethers.min.js web/vendor/

fonts/ — IBM Plex Sans 400/600, Plex Mono 400, Newsreader 500 (latin subset, ~88 KB total), from
@fontsource/{ibm-plex-sans,ibm-plex-mono,newsreader} on npm. Regenerate:
  npm i @fontsource/ibm-plex-sans @fontsource/ibm-plex-mono @fontsource/newsreader
  cp node_modules/@fontsource/*/files/*latin-*-normal.woff2 web/vendor/fonts/
Vendored for the same reason as ethers: a killed CDN must not restyle the demo (AGENT_UI.md §4).
