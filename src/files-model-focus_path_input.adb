separate (Files.Model)
   procedure Focus_Path_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Path_Input;
      Model.Path_Input_Value := Model.Current_Path_Value;
      Model.Path_Input_Cursor := Length (Model.Path_Input_Value);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Path_Input;
