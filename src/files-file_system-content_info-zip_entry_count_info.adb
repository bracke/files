with Zlib;

separate (Files.File_System.Content_Info)
--  The entry count the archive itself records, as zlib reads it from the End
--  Of Central Directory record (the ZIP64 one when present) in the file's
--  tail: counting central-directory signatures instead counted a stored inner
--  archive's entries and any chance PK 1 2 in the data too. An archive with
--  no valid record (truncated, or not a ZIP at all) shows 0 entries, as one
--  that cannot be opened does: no number the archive does not state.
function Zip_Entry_Count_Info
  (Path    : String;
   Of_Kind : Files.Extra_Info.Kind;
   Subject : String)
   return Files.Extra_Info.Info
is
   use type Zlib.Status_Code;

   function Entries (Count : Natural; Capped : Boolean := False) return Files.Extra_Info.Info is
     (Files.Extra_Info.Make (Of_Kind, Subject => Subject, Count => Count, Capped => Capped));

   --  Only a regular file that is no link is read, as every content probe
   --  here: the check opens it without blocking and without following one.
   Probe  : GNAT.OS_Lib.File_Descriptor := Files.IO.Fs_Primitives.Open_Regular_Read (Path);
   Count  : Natural;
   Capped : Boolean;
   Status : Zlib.Status_Code;
begin
   if Probe = GNAT.OS_Lib.Invalid_FD then
      return Entries (0);
   end if;
   Close_Read_Descriptor (Probe);
   Zlib.Count_ZIP_File_Entries (Path, Count, Capped, Status);
   return (if Status = Zlib.Ok then Entries (Count, Capped) else Entries (0));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Close_Read_Descriptor (Probe);
      return Entries (0);
end Zip_Entry_Count_Info;
