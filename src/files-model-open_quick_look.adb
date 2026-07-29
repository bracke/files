separate (Files.Model)
   procedure Open_Quick_Look
     (Model   : in out Window_Model;
      Content : Files.Quick_Look.Quick_Look_Content) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Quick_Look_Active        := True;
      Model.Quick_Look_Path_Value    := Selected_Item (Model).Full_Path;
      Model.Quick_Look_Content_Value := Content;
   end Open_Quick_Look;
