# AutoHotkey source parts

Run `72-Auto_GSF_Buff_Click_Nhan_Vat.ahk` from the repository root. It keeps
the startup code and includes the numbered `.ahk` files in `lib`.

The numbered files are consecutive sections of the original script, not
independent modules. Their order in the entrypoint is intentional: keep the
includes in that order when editing or adding sections. AutoHotkey v1 includes
share the same global scope; they do not isolate variables or functions.

The source was split without changing the order or contents of the original
labels and functions. For larger refactors, move a complete feature at a time
and test the entrypoint with the project's AutoHotkey v1 runtime.

Farm only picks up ground items within the configured pickup radius. It does
not leave the route to walk or recover toward a distant item; items outside
that radius can be picked if the character later comes within range.
