# Embedded manifest example

Windows executables can contain manifests.
Manifests are metadata can control various aspects before and during program execution.
The most common use cases are:

* UAC awareness (for privilege escalation)
* DPI awareness (for correctly rendering at >96 dpi)
* Enabling visual styles (Common Controls v6)

This example uses the manifest to enable visual styles, which will affect
the appearance of a button.

## Embedding manifests with Odin

Manifests are regular embedded resources (such as images or localized strings),
so they can be embedded with a `.rc` script. They use resource type
`RT_MANIFEST` (numeric value `24`), and the main application manifest is
expected to have resource ID `1`.

See the contents of `resource.rc` and compile with:

```
odin build . -resource:resource.rc
```

Alternatively, a manifest can be embedded into an existing binary with the `mt.exe`
tool, which is part of the Windows SDK:

```
mt.exe -manifest app.manifest -outputresource:embedded_manifest.exe;1
```

## Troubleshooting

If you are seeing:

```
error RC1015: cannot open include file 'winuser.h'
```

Your build environment is not set up properly for `rc.exe`, which is the component
that compiles the `resource.rc` file. The easiest fix is to launch the developer
command prompt for Visual Studio, and build from there.

Alternatively, you must manually ensure that your local Windows SDK's appropriate
Include directory is added to your `%INCLUDE%` envrionment variable.
