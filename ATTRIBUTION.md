# Attribution & Third-Party Licenses

This project, **PrivaClip**, was inspired by the architectural concepts and user experience paradigms explored in the open-source reference project:
**Clip-Board** (Repository: `https://github.com/lighthouse-computer/Clip-Board`).

---

## Upstream Project Attribution

- **Project Name**: Clip-Board
- **Original Author**: Siddharth Sangwan
- **Repository**: [https://github.com/lighthouse-computer/Clip-Board](https://github.com/lighthouse-computer/Clip-Board)
- **License**: MIT License

### Upstream MIT License Text

```text
MIT License

Copyright (c) 2026 Siddharth Sangwan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## PrivaClip Independent Implementation Statement

PrivaClip is an independent, clean-room rewrite built to resolve architectural and security challenges in clipboard management software.
- All core modules (`PrivaClipCore`, `PrivaClipUI`, `PrivaClipApp`) were re-architected in modern Swift to ensure thread safety, Apple Silicon optimization, and adherence to macOS Sonoma/Sequoia platform conventions.
- PrivaClip does not represent itself as an official continuation or derivative of the upstream product.
- All cryptographic storage (`CryptoKit`), Keychain integration, Smart Collections, Snippet expansions, and exclusion filtering are original implementations created for PrivaClip.
- All trademark, product naming, and visual identity assets (`PrivaClip`, custom `.icns` artwork) are original to this project.
