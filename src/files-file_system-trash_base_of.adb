separate (Files.File_System)
function Trash_Base_Of (Trashed_Path : String) return String is
   Home : constant String := Trash_Base_Path;

   --  The Finder's layout (the ~/.Trash backend, and the Finder's own trash
   --  that says where it put an item): items directly in ~/.Trash or in a
   --  volume's .Trashes/<uid>, with no info files -- the folder holding the
   --  item is its base, as long as it is one of those.
   function Finder_Base return String is
      Parent      : constant String := Files.Fs_Primitives.Parent_Directory (Trashed_Path);
      Home_Folder : constant String := Files.Environment.Value ("HOME");
      Home_Trash  : constant String :=
        (if Home_Folder = "" or else not GNAT.OS_Lib.Is_Absolute_Path (Home_Folder) then ""
         else Hostkit.Fs.Join (Home_Folder, ".Trash"));
   begin
      if not Valid_Original_Path (Trashed_Path) then
         return "";
      elsif Home_Trash /= "" and then Is_Trash_Payload (Trashed_Path, Home_Trash) then
         return Home_Trash;
      elsif Is_Finder_Volume_Trash (Parent) and then Valid_Volume_Trash_Base (Parent) then
         return Parent;
      end if;
      return "";
   end Finder_Base;
begin
   --  A Recycle Bin item's base is its bin folder: no info/ beside it, so
   --  only Is_Volume_Trash_Item asks this of one; restore, purge and the
   --  original path ask Hostkit.Trash.
   if Trash_Backend_Of_Current_Environment = Trash_Windows_Recycle_Bin then
      return
        (if Hostkit.Trash.Is_Recycled_Item (Trashed_Path)
         then Files.Fs_Primitives.Parent_Directory (Trashed_Path)
         else "");
   elsif Trash_Backend_Of_Current_Environment in Trash_Macos_Home | Trash_Macos_Native then
      return Finder_Base;
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
      if Files.Types.Leaf_Of (Files_Directory) = "files"
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
