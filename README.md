imgui bindings for mach

regenerating:

```
python3 --version # must be installed and in path
pip3 install ply 
zig build generate
```

notes:

- why does this generate zig at all? can't it use cImport on the generated headers?