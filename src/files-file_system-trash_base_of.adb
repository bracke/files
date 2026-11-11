separate (Files.File_System)
function Trash_Base_Of (Trashed_Path : String) return String is
   Home : constant String := Trash_Base_Path;
begin
   --  A Recycle Bin item's base is its bin folder: no info/ beside it, so
   --  only Is_Volume_Trash_Item asks this of one; restore, purge and the
   --  original path ask Hostkit.Trash.
   if Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin then
      return
        (if Hostkit.Trash.Is_Recycled_Item (Trashed_Path)
         then Files.Fs_Primitives.Parent_Directory (Trashed_Path)
         else "");
   elsif Trash_Backend_Of_Current_Environment not in Trash_Xdg_Data_Home | Trash_Home_Data then
      return "";
   elsif Home /= "" and then Is_Trash_Payload (Trashed_Path, Hostkit.Fs.Join (Home, "files")) then
      return Home;
   elsif not Volume_Trash_Supported then
      return "";
   end if;
   declare
      Files_Directory : constant String := Files.Fs_Primitives.Parent_Directory (Trashed_Path);
      Base            : constant String := Files.Fs_Primitives.Parent_Directory (Files_Directory);
   begin
      --  Files_Directory is the item's own parent, so only the base needs
      --  checking (Valid_Volume_Trash_Base refuses a linked files/).
      if Files.Fs_Primitives.Leaf_Text (Files_Directory) = "files"
        and then Valid_Original_Path (Trashed_Path)
        and then Valid_Volume_Trash_Base (Base)
      then
         return Base;
      end if;
      return "";
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Trash_Base_Of;
