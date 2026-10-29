# Vendored runtime only

MIT inkgd GDScript runtime, upstream revision
`fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a`, taken from the working
`MohamedXIV/kiosk-on-the-nile` tree
`9fdbd963b8773c6c51e612862d85a37dcb24a9a3` through GitHub.
Runtime files are copied verbatim, including Kiosk's local performance fixes.
Editor, C# and InkPlayer wrappers are omitted; BTL uses InkStory behind InkDialogue.
Godot-generated UID sidecars are local. LICENSE and UPSTREAM_LICENSE.txt retained.

Compiled with inklecate 1.2.1 (Ink JSON format 21), Linux archive SHA-256:
`1997ff5bca618c90003ecd5fecb286e7468abb955005a2a185042949642f8fb5`.
The compiler is a development tool, not a runtime dependency. Rebuild the source
and embedded fixture story with `python tools/compile-narrative.py /path/to/inklecate`.
