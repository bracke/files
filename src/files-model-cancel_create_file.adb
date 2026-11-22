separate (Files.Model)
procedure Cancel_Create_File
  (Model : in out Window_Model) is
begin
   --  Nothing to end: opening the settings pane or the palette clears the
   --  edit state on every open, and a full touch rebuilt every row.
   if not Model.Temporary.Active and then not Model.Rename.Active then
      return;
   end if;
   if Model.Temporary.Active then
      Touch (Model);
   end if;
   Model.Temporary := (others => <>);
   if Model.Selected_Item_Index = Temporary_Item_Index then
      Model.Selected_Item_Index := 0;
   end if;
   Remove_Selected_Index (Model, Temporary_Item_Index);
   --  The temporary item owns the only rename field while it is active, so
   --  clearing rename state here discards exactly that field.
   Reset_Rename_State (Model);
end Cancel_Create_File;
