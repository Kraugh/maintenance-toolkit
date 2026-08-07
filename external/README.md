# Optional external tools

`speedtest.exe` is optional. Its absence must produce a warning, never a crash.


## Optional Ookla SpeedTest CLI

Network Diagnostics options 3 and 4 can use `speedtest.exe`.

Preferred location:

```text
external\speedtest.exe
```

If it is not present there, MT also checks `PATH`.

Maintenance Toolkit does not download or install SpeedTest automatically.
If the executable is absent, the SpeedTest step is reported as a warning and
the remaining diagnostics/report continue normally.
