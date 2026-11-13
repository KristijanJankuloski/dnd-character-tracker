# Fonts

Both families are licensed under the SIL Open Font License 1.1. The licence
texts are `Cinzel-OFL.txt` and `Alegreya-OFL.txt`, and `lib/main.dart`
registers them with Flutter's licence registry.

| File | Used for |
| --- | --- |
| `Cinzel-Bold.ttf` | Names, panel titles, captions, tab labels |
| `Alegreya-*.ttf` | All other text and every number |

## Cinzel is modified

`Cinzel-Bold.ttf` is not the upstream file. The character map entries for the
digits 0 to 9 are removed.

Cinzel draws 1 like a capital I, so a title such as "Level 11" reads as
"Level II". With the digits unmapped, Flutter falls back to Alegreya for them.
`displayStyle` in `lib/core/theme.dart` names Alegreya as the fallback, and
`test/core/theme_test.dart` fails if the digits come back.

To repeat the change after updating the font, run this with
[fontTools](https://github.com/fonttools/fonttools) installed:

```python
from fontTools.ttLib import TTFont

font = TTFont("Cinzel-Bold.ttf")
for table in font["cmap"].tables:
    for codepoint in range(0x30, 0x3A):
        table.cmap.pop(codepoint, None)
font.save("Cinzel-Bold.ttf")
```
