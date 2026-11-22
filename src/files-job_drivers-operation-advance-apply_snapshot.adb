with Files.Model.Filtering;
separate (Files.Job_Drivers.Operation.Advance)
procedure Apply_Snapshot is
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
      Files.Model.Filtering.Clear_Search_Results (Model);
      if Length (Done.Selection) > 0 then
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
