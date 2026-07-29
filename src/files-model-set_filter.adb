separate (Files.Model)
   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Filter_Value := To_Unbounded_String (Text);
      Model.Filter_Cursor := Text'Length;
      Model.Main_View_Scroll := 0;
      Reconcile_Selection (Model);
   end Set_Filter;
