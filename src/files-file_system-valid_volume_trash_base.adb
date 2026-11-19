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
      Name   : constant String := Files.Types.Leaf_Of (Base);
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Base);
      --  A part surely not made yet, or our own real directory: one that
      --  cannot be looked at could be the link this guards against.
      function Absent_Or_Own (Part : String) return Boolean is
        ((not Hostkit.Fs.Is_Link (Part) and then Files.Fs_Primitives.Entry_Is_Absent (Part))
         or else Own_Directory (Part));

      --  The base, and its files/ and info/: a files/ that is a link would
      --  make Empty Trash delete whatever it points at.
      function Owned_Tree return Boolean is
        (Own_Directory (Base)
         and then Absent_Or_Own (Hostkit.Fs.Join (Base, "files"))
         and then Absent_Or_Own (Hostkit.Fs.Join (Base, "info")));
   begin
      if Name = ".Trash-" & Id then
         return Safe_Trash_Parent (Parent, Shared => False, Existing => True) and then Owned_Tree;
      elsif Name = Id and then Files.Types.Leaf_Of (Parent) = ".Trashes" then
         --  The Finder's per-user folder, for the trash that keeps its
         --  layout: no files/ or info/ of ours in it, its items directly.
         return Trash_Backend_Of_Current_Environment in Trash_Macos_Home | Trash_Macos_Native
           and then Safe_Trash_Parent (Parent, Shared => True)
           and then Safe_Trash_Parent (Files.Fs_Primitives.Parent_Directory (Parent), Shared => False, Existing => True)
           and then Own_Directory (Base);
      elsif Name = Id and then Files.Types.Leaf_Of (Parent) = ".Trash" then
         return Safe_Trash_Parent (Parent, Shared => True)
           and then Safe_Trash_Parent (Files.Fs_Primitives.Parent_Directory (Parent), Shared => False, Existing => True)
           and then Owned_Tree;
      end if;
      return False;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return False;
end Valid_Volume_Trash_Base;
