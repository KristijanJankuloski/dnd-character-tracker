# App icon

- `app_icon_source.png` is the original 1254x1254 artwork.
- `app_icon_ios.png` is the artwork scaled to 95% on a black, opaque 1024x1024 canvas, so the baked-in rounded gold frame sits inside the iOS corner mask.
- `app_icon_android.png` is the legacy Android icon (pre-Android 8), with the black corners outside the frame made transparent.
- `app_icon_foreground.png` is the Android adaptive icon foreground: the framed tile at 50% of the canvas, so the whole frame stays inside the 66dp safe zone on any launcher mask. The background is solid black (`#000000`).

After changing any of these, regenerate the platform icons with:

```
dart run flutter_launcher_icons
```
