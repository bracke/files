with Interfaces;

with Hostkit.Process;

separate (Files.File_System)
function Safe_Trash_Parent (Parent : String; Shared : Boolean; Existing : Boolean := False) return Boolean is
   use type Interfaces.Unsigned_64;
   Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Parent);
   Sticky          : constant Boolean := (Revision.Mode and 8#1000#) /= 0;
   --  Writable by anyone but its owner: they could rename our trash away and
   --  put a link in its place.
   --  A trash made earlier under a top its group can write to stays listed
   --  and restorable when that group is the user's own private group (the
   --  user-private-group scheme: a group named as the user, on a top the
   --  user owns, with umask 002) -- no one else is in it. A group others
   --  share could swap the trash for a folder of the user's and have Empty
   --  Trash delete its contents, so that is refused like a new trash.
   --  Writable by everyone is never trusted.
   Uid : Natural := 0;
   Own_Private_Group : constant Boolean :=
     Existing
     and then Hostkit.Process.Current_User_Id (Uid)
     and then Revision.User_Id = Interfaces.Unsigned_64 (Uid)
     and then Revision.Group_Id <= Interfaces.Unsigned_64 (Files.Types.Account_Id'Last)
     and then User_Name_For_Id (Files.Types.Account_Id (Uid)) /= ""
     and then Group_Name_For_Id (Files.Types.Account_Id (Revision.Group_Id))
                = User_Name_For_Id (Files.Types.Account_Id (Uid));
   Shared_Writable : constant Boolean :=
     (Revision.Mode and (if Own_Private_Group then 8#002# else 8#022#)) /= 0;
begin
   if Hostkit.Fs.Is_Link (Parent)
     or else not Files.Fs_Primitives.Directory_Exists (Parent)
     or else not Revision.Available
   then
      return False;
   elsif Shared then
      return Sticky and then Revision.User_Id = 0;
   else
      return Sticky or else not Shared_Writable;
   end if;
exception
   when others => return False;
end Safe_Trash_Parent;
