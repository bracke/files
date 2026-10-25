with Hostkit.Process;
with Interfaces;

separate (Files.File_System)
function Valid_Volume_Trash_Base (Base : String) return Boolean is
   use type Interfaces.Unsigned_64;
   Uid : Natural;

   --  A real directory, not a link, owned by this user.
   function Own_Directory (Path : String) return Boolean is
      Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Path);
   begin
      return not Hostkit.Fs.Is_Link (Path)
        and then Files.Fs_Primitives.Directory_Exists (Path)
        and then Revision.Available
        and then Revision.User_Id = Interfaces.Unsigned_64 (Uid);
   end Own_Directory;

   --  The administrator's shared .Trash: a real directory with the sticky
   --  bit, so users cannot remove each other's folders in it.
   function Shared_Trash (Path : String) return Boolean is
      Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Path);
   begin
      return not Hostkit.Fs.Is_Link (Path)
        and then Files.Fs_Primitives.Directory_Exists (Path)
        and then Revision.Available
        and then (Revision.Mode and 8#1000#) /= 0;
   end Shared_Trash;
begin
   if Base = "" or else not Hostkit.Process.Current_User_Id (Uid) then
      return False;
   end if;
   declare
      Id     : constant String := Image_No_Space (Uid);
      Name   : constant String := Ada.Directories.Simple_Name (Base);
      Parent : constant String := Ada.Directories.Containing_Directory (Base);
   begin
      if Name = ".Trash-" & Id then
         return Own_Directory (Base);
      elsif Name = Id and then Ada.Directories.Simple_Name (Parent) = ".Trash" then
         return Shared_Trash (Parent) and then Own_Directory (Base);
      end if;
      return False;
   end;
exception
   when others => return False;
end Valid_Volume_Trash_Base;
