with Files.Model.Filtering;
separate (Files.Job_Drivers.Operation.Advance)
procedure Apply_Snapshot is
   use type Files.UI_Types.Search_Scope;
   --  Search results keep the window's selection where it still is.
   Previous_Selection : constant Files.Types.String_Vectors.Vector :=
     Files.Model.Selection.Selected_Paths (Model);
   Previous_Primary   : constant String := To_String (Files.Model.Selection.Selected_Item (Model).Full_Path);
begin
   if Done.Recent then
      Files.Model.Navigate_Recent (Model, Done.Items);
   else
      Files.Model.Replace_Items (Model, Done.Items);
   end if;
   Files.Model.Set_Directory_Signature (Model, Done.Signature);
   if Done.Kind in Search_Names | Search_Contents then
      Files.Model.Filtering.Note_Search_Results
        (Model,
         (if Done.Kind = Search_Names then Files.UI_Types.Search_Names
          else Files.UI_Types.Search_Contents));
   else
      --  The helper searched again when the window showed results: its
      --  items are results still, kept as the window showed them.
      if Done.Searched = Files.UI_Types.Filter_Here then
         Files.Model.Filtering.Clear_Search_Results (Model);
      elsif not Files.Model.Filtering.Search_Results_Are_Active (Model)
        or else Files.Model.Filtering.Search_Scope_Of (Model) /= Done.Searched
      then
         Files.Model.Filtering.Note_Search_Results (Model, Done.Searched);
      end if;
      if Length (Done.Selection) = 0 and then Done.Searched /= Files.UI_Types.Filter_Here then
         Files.Model.Selection.Restore (Model, Previous_Selection, Previous_Primary);
      elsif Length (Done.Selection) > 0 then
         declare
            Selected : constant Boolean :=
              Files.Model.Selection.Select_By_Name (Model, To_String (Done.Selection));
            pragma Unreferenced (Selected);
         begin
            null;
         end;
      end if;
   end if;
end Apply_Snapshot;
