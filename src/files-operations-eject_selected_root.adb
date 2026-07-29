separate (Files.Operations)
   function Eject_Selected_Root
     (Model : in out Files.Model.Window_Model)
      return Operation_Result
   is
      Index : constant Natural := Files.Model.Root_Selected_Index (Model);
      Path  : Unbounded_String;
   begin
      if not Files.Model.Root_Selector_Is_Open (Model)
        or else Index = 0
        or else Index > Files.Model.Root_Count (Model)
      then
         return Disabled (Model, "error.root.selection.empty");
      end if;

      Path := To_Unbounded_String (Files.Model.Root_Path (Model, Index));
      if not Files.Model.Root_Is_Removable (Model, Index) then
         return Disabled (Model, "error.root.eject_unavailable");
      end if;

      Files.Model.Set_Error (Model, "error.root.eject_unavailable");
      return Make_Result
        (Operation_Failed,
         "error.root.eject_unavailable",
         To_String (Path));
   end Eject_Selected_Root;
