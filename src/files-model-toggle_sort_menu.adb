separate (Files.Model)
procedure Toggle_Sort_Menu
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Sort_Menu_Open := not Model.Sort_Menu_Open;
   --  Open the menu with the keyboard highlight on the current sort field
   --  (rows 1 .. 5 mirror Sort_Field'Val 0 .. 4).
   if Model.Sort_Menu_Open then
      Claim_Overlay_Input (Model);
      Model.Sort_Menu_Highlight_Value := Files.Types.Sort_Field'Pos (Model.Sort_Field_Value) + 1;
   end if;
end Toggle_Sort_Menu;
