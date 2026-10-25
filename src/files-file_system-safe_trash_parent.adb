with Interfaces;

separate (Files.File_System)
function Safe_Trash_Parent (Parent : String; Shared : Boolean) return Boolean is
   use type Interfaces.Unsigned_64;
   Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Parent);
   Sticky          : constant Boolean := (Revision.Mode and 8#1000#) /= 0;
   Others_Writable : constant Boolean := (Revision.Mode and 8#002#) /= 0;
begin
   if Hostkit.Fs.Is_Link (Parent)
     or else not Files.Fs_Primitives.Directory_Exists (Parent)
     or else not Revision.Available
   then
      return False;
   elsif Shared then
      return Sticky and then Revision.User_Id = 0;
   else
      return Sticky or else not Others_Writable;
   end if;
exception
   when others => return False;
end Safe_Trash_Parent;
