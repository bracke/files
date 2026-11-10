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
   --  Read in place: the window loop asks on every pass.
   return not Model.Items (Idx).Filetype_Extra_Loaded and then Files.Extra_Info."="
       (Model.Items (Idx).Filetype_Extra.Of_Kind, Files.Extra_Info.None);
end Selected_Item_Needs_Extra;
