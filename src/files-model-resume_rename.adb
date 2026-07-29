separate (Files.Model)
   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if not Rename_Is_Enabled (Model) then
         return;
      end if;

      Clear_Overlay_State_For_Edit (Model);
      Model.Rename_Fields.Clear;
      Model.Rename_Fields.Append
        (Rename_Field'
           (Item_Index => Effective_Selected_Item_Index (Model),
            Value      => To_Unbounded_String (Text),
            Cursor     => Text'Length));
      Model.Rename_Active := True;
      Model.Focus_Value := Files.Types.Focus_Rename_Input;
   end Resume_Rename;
