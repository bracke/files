with Files.File_Types;
with Files.Model.Creation;
separate (Files.Operations.Editing)
procedure Begin_Create_Item
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Folder   : Boolean)
is
   Name    : constant String := Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model));
   Classes : constant Files.File_Types.Classification := Files.Settings.Classification_Of (Settings);
begin
   if Folder then
      Files.Model.Creation.Begin_Create_Folder (Model, Name, Classes);
   else
      Files.Model.Creation.Begin_Create_File (Model, Name, Classes);
   end if;
   Files.Model.Set_Error (Model, "");
end Begin_Create_Item;
