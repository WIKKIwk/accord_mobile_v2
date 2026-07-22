# Xprinter iOS SDK

Official Xprinter iOS SDK v3.2.7 archive for the 58/80 mm and 2/3-inch label
printer families, downloaded from the vendor page:

https://www.xprinter.net/companyfile/3.html

The archive contains:

- `libPrinterSDK.a`
- Objective-C headers for `XBLEManager` and `XTSPLCommand`
- an iOS Swift BLE/TSPL sample app
- English and Chinese programming manuals

The supplied static library contains an `arm64` device slice and an `x86_64`
slice, but it is not an `.xcframework`; simulator builds using the `arm64`
simulator target are not supported by this vendor binary. The device
`iphoneos/arm64` build is the supported integration target.

SHA-256:

```text
7d38a94008160c20cc7ae1db3cd2a2191c497859b022c4561a49fe532ae01e7f
```

The vendor download page does not state standalone redistribution terms for
the archive. Confirm Xprinter distribution terms before publishing an iOS
build containing the SDK.
