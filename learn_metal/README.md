# Getting started with Metal in Odin

Odin officially bundles with a low-overhead Odin interface for Metal that helps developers add Metal functionality to graphical applications, games, game engines, and GPU workload in Odin directly.

## Highlights

* Odin native drop interface as an alternative to the Metal in Objective-C or Swift
* Direct mapping of all Metal Objective-C classes, constants, and enumerations in Odin in `vendor:darwin/Metal`
* No measurable overhead compared to calling Metal in Objective-C, due to built-in compiler support for Objective-C operations
* No wrappers which do hidden memory allocations
* String `ErrorDomain` constants have weak linkage and are automatically set to `nil` if not available

## How to use

```odin
import NS  "vendor:darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA  "vendor:darwin/QuartzCore"
```

## Package Documentation

* https://pkg.odin-lang.org/vendor/darwin/Metal/
* https://pkg.odin-lang.org/vendor/darwin/Foundation/
* https://pkg.odin-lang.org/vendor/darwin/QuartzCore/
