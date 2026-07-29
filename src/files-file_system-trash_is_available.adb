separate (Files.File_System)
   function Trash_Is_Available return Boolean is
      Backend : constant Trash_Backend := Trash_Backend_For_Base;
   begin
      --  The desktop's own trash needs no base directory of ours: the Recycle
      --  Bin and the Finder's trash are simply there. Asking for a base path
      --  would report no trash at all on Windows, and take the whole
      --  move-to-trash command down with it.
      if Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native then
         return True;
      end if;

      return Path_Can_Be_Directory (Trash_Base_Path);
   end Trash_Is_Available;
