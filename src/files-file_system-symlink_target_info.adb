separate (Files.File_System)
function Symlink_Target_Info (Path : String) return Files.Extra_Info.Info is
   Target : Ada.Strings.Unbounded.Unbounded_String;
begin
   --  The link's own stored text, not what it resolves to: a link written as
   --  "plain.txt" is shown as "plain.txt", which is the fact the detail line
   --  is reporting. Hostkit reads it -- readlink on POSIX, the reparse point
   --  on Windows, where there is no readlink to call.
   if not Hostkit.Fs.Read_Link_Target (Path, Target) then
      return Files.Extra_Info.No_Info;
   end if;

   return Files.Extra_Info.Make (Files.Extra_Info.Symlink_Target, Value => Ada.Strings.Unbounded.To_String (Target));
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Files.Extra_Info.No_Info;
end Symlink_Target_Info;
