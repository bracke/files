separate (Files.Model)
   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Search_Scope_Value := Scope;
      Model.Search_Results_Active := Scope /= Files.Types.Filter_Here;
   end Note_Search_Results;
