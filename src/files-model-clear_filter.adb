separate (Files.Model)
   procedure Clear_Filter
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Set_Filter (Model, "");
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
   end Clear_Filter;
