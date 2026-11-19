separate (Files.File_System.Thumbnails)
function Thumbnail_Extension
  (Source_Path : String)
   return String
is
   --  The extension as filetype detection reads it (Files.File_Types): a
   --  dotfile (".png") or a trailing dot ("draft.") has none.
   Extension : constant String :=
     Files.File_Types.Normalized_Extension_Of (Files.Types.Leaf_Of (Source_Path));
begin
   return (if Extension = "" then "file" else Extension);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      return "file";
end Thumbnail_Extension;
