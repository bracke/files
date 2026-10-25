with Guikit.Shared_Bytes;

--  Immutable, reference-counted byte buffers for decoded thumbnail pixels.
--
--  A directory item, the visible rows built from it, every view snapshot and
--  the draw commands built from those each held their own deep copy of an
--  item's RGBA thumbnail. One shared buffer now travels through all of them
--  into guikit's draw commands; copying a Bytes value only bumps a count.
package Files.Shared_Bytes renames Guikit.Shared_Bytes;
