separate (Files.File_System)
function Trash_Base_Of (Trashed_Path : String) return String is
   Home : constant String := Trash_Base_Path;
begin
   if Trash_Backend_Of_Current_Environment not in Trash_Xdg_Data_Home | Trash_Home_Data then
      return "";
   elsif Home /= "" and then Is_Trash_Payload (Trashed_Path, Join_Path (Home, "files")) then
      return Home;
   elsif not Volume_Trash_Supported then
      return "";
   end if;
   declare
      Files_Directory : constant String := Ada.Directories.Containing_Directory (Trashed_Path);
      Base            : constant String := Ada.Directories.Containing_Directory (Files_Directory);
   begin
      --  Files_Directory is the item's own parent, so only the base needs
      --  checking (Valid_Volume_Trash_Base refuses a linked files/).
      if Ada.Directories.Simple_Name (Files_Directory) = "files"
        and then Valid_Original_Path (Trashed_Path)
        and then Valid_Volume_Trash_Base (Base)
      then
         return Base;
      end if;
      return "";
   end;
exception
   when others => return "";
end Trash_Base_Of;
