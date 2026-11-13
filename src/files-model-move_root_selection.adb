separate (Files.Model)
procedure Move_Root_Selection
  (Model     : in out Window_Model;
   Direction : Guikit.Input.Navigation_Direction)
is
   Count   : constant Natural := Root_Count (Model);
   Current : constant Natural := Root_Selected_Index (Model);
begin
   Touch (Model);
   if not Model.Root_Selector.Open or else Count = 0 then
      Model.Root_Selector.Selected := 0;
   elsif Current = 0 then
      Model.Root_Selector.Selected := 1;
   elsif Direction = Guikit.Input.Move_Up or else Direction = Guikit.Input.Move_Left then
      Model.Root_Selector.Selected := (if Current = 1 then Count else Current - 1);
   else
      Model.Root_Selector.Selected := (if Current = Count then 1 else Current + 1);
   end if;
end Move_Root_Selection;
