separate (Files.Model)
   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Begin_Create_Temporary (Model, Name, Is_Directory => True);
   end Begin_Create_Folder;
