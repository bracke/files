separate (Files.Model)
procedure Set_Root_Selected_Index
  (Model : in out Window_Model;
   Index : Natural) is
begin
   Touch (Model);
   if not Model.Root_Selector.Open or else Root_Count (Model) = 0 then
      Model.Root_Selector.Selected := 0;
   elsif Index = 0 then
      Model.Root_Selector.Selected := 0;
   else
      Model.Root_Selector.Selected := Natural'Min (Index, Root_Count (Model));
   end if;
end Set_Root_Selected_Index;
