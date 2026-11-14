separate (Files.File_System.Thumbnails)
function Thumbnail_Extension
  (Source_Path : String)
   return String
is
   --  The extension as filetype detection reads it (Files.File_Types): a
   --  dotfile (".png") or a trailing dot ("draft.") has none.
   Extension : constant String := Files.File_Types.Extension_Of (Files.Fs_Primitives.Leaf_Text (Source_Path));
begin
   return (if Extension = "" then "file" else Extension);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      return "file";
end Thumbnail_Extension;
