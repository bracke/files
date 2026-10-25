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

begin
   if Base = "" or else not Hostkit.Process.Current_User_Id (Uid) then
      return False;
   end if;
   declare
      Id     : constant String := Natural_Text (Uid);
      Name   : constant String := Ada.Directories.Simple_Name (Base);
      Parent : constant String := Ada.Directories.Containing_Directory (Base);
      --  A part not made yet, or our own real directory.
      function Absent_Or_Own (Part : String) return Boolean is
        ((not Hostkit.Fs.Is_Link (Part) and then not Ada.Directories.Exists (Part))
         or else Own_Directory (Part));

      --  The base, and its files/ and info/: a files/ that is a link would
      --  make Empty Trash delete whatever it points at.
      function Owned_Tree return Boolean is
        (Own_Directory (Base)
         and then Absent_Or_Own (Join_Path (Base, "files"))
         and then Absent_Or_Own (Join_Path (Base, "info")));
   begin
      if Name = ".Trash-" & Id then
         return Safe_Trash_Parent (Parent, Shared => False) and then Owned_Tree;
      elsif Name = Id and then Ada.Directories.Simple_Name (Parent) = ".Trash" then
         return Safe_Trash_Parent (Parent, Shared => True)
           and then Safe_Trash_Parent (Ada.Directories.Containing_Directory (Parent), Shared => False)
           and then Owned_Tree;
      end if;
      return False;
   end;
exception
   when others => return False;
end Valid_Volume_Trash_Base;
