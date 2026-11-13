separate (Files.Model)
procedure Focus_Ownership_Input
  (Model         : in out Window_Model;
   Editing_Group : Boolean;
   Account_Name  : String)
is
   Item : constant Files.Items.Directory_Item := Selected_Item (Model);
begin
   if Selected_Count (Model) /= 1
     or else Selection_Includes_Temporary (Model)
     or else not Item.Ownership_Available
     or else Model.Current_Is_Trash_Value
   then
      return;
   end if;

   Touch (Model);
   Reset_Type_Ahead (Model);
   Model.Focus_Value := Files.Types.Focus_Ownership_Input;
   Model.Ownership_Input.Editing_Group := Editing_Group;
   declare
      Id : constant Files.Types.Account_Id := (if Editing_Group then Item.Group_Id else Item.Owner_Id);
   begin
      --  Seed with the resolved name so the field matches its display; the
      --  commit path accepts a name or a number. Fall back to the number.
      Model.Ownership_Input.Text :=
        To_Unbounded_String
          (if Account_Name /= "" then Account_Name
           else Files.Types.Account_Image (Id));
   end;
   Model.Ownership_Input.Cursor := Length (Model.Ownership_Input.Text);
   Clear_Root_Selector_State (Model);
   Model.Command_Palette.Open := False;
   Guikit.Command_Palette.Reset (Model.Command_Palette.View);
end Focus_Ownership_Input;
