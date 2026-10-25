separate (Files.File_System)
function Symlink_Target_Token (Path : String) return String is
   Target : Ada.Strings.Unbounded.Unbounded_String;
begin
   --  The link's own stored text, not what it resolves to: a link written as
   --  "plain.txt" is shown as "plain.txt", which is the fact the detail line
   --  is reporting. Hostkit reads it -- readlink on POSIX, the reparse point
   --  on Windows, where there is no readlink to call.
   if not Hostkit.Fs.Read_Link_Target (Path, Target) then
      return "";
   end if;

   return "symlink.target|" & Ada.Strings.Unbounded.To_String (Target);
exception
   when others =>
      return "";
end Symlink_Target_Token;
