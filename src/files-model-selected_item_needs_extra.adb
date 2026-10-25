separate (Files.Model)
function Selected_Item_Needs_Extra
  (Model : Window_Model)
   return Boolean
is
   Idx : constant Natural := Model.Selected_Item_Index;
begin
   if not Model.Info_Pane_Open
     or else Model.Paste_Exec.Active
     or else Files.Process_Jobs.Active (Model.Refresh_Job)
     or else Idx = 0
     or else Idx > Natural (Model.Items.Length)
   then
      return False;
   end if;
   declare
      Item : constant Files.File_System.Directory_Item := Model.Items.Element (Idx);
   begin
      return not Item.Filetype_Extra_Loaded and then Length (Item.Filetype_Extra) = 0;
   end;
end Selected_Item_Needs_Extra;
