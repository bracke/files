with Files.Model.Creation;
separate (Files.Operations)
procedure Begin_Create_Item
  (Model  : in out Files.Model.Window_Model;
   Folder : Boolean)
is
   Name : constant String := Files.File_System.Next_Untitled_Name (Files.Model.Current_Path (Model));
begin
   if Folder then
      Files.Model.Creation.Begin_Create_Folder (Model, Name);
   else
      Files.Model.Creation.Begin_Create_File (Model, Name);
   end if;
   Files.Model.Set_Error (Model, "");
end Begin_Create_Item;
