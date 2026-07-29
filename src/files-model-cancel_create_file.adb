separate (Files.Model)
   procedure Cancel_Create_File
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      if Model.Selected_Item_Index = Temporary_Item_Index then
         Model.Selected_Item_Index := 0;
      end if;
      Remove_Selected_Index (Model, Temporary_Item_Index);
      --  The temporary item owns the only rename field while it is active, so
      --  clearing rename state here discards exactly that field.
      Reset_Rename_State (Model);
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Cancel_Create_File;
