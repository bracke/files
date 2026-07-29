separate (Files.Model)
   procedure Set_Directory_Signature
     (Model     : in out Window_Model;
      Signature : Files.File_System.Directory_Signature) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Directory_Signature := Signature;
   end Set_Directory_Signature;
