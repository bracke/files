separate (Files.Model)
   procedure Close_Quick_Look
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Quick_Look (Model);
   end Close_Quick_Look;
