# Console example

Demonstrates the complete update flow in about 80 lines.

```
fpc -Fu../../src ConsoleDemo.lpr
./ConsoleDemo https://example.com/releases
```

The Velopack native library has to be next to the executable (or referenced by
`VELOPACK_LIBRARY`). Behavior when the program is started outside of a Velopack installation
has only been checked against the test stub, not against the real library:
`TUpdateManager.Create` is expected to raise `EVelopackError` (there is no
installed application to update), and the demo reports that and exits.

`pack.sh` shows how to package the result with the `vpk` CLI (unverified).
