separate (Files.Model)
procedure Ensure_Selected_Item_Extra
  (Model : in out Window_Model)
is
   Idx : constant Natural := Model.Selected_Item_Index;
begin
   if not Model.Info_Pane_Open
     or else Model.Paste_Exec.Active
     or else Files.Process_Jobs.Active (Model.Refresh_Job)
     or else Idx = 0
     or else Idx > Natural (Model.Items.Length)
   then
      return;
   end if;
   declare
      Item : Files.File_System.Directory_Item := Model.Items.Element (Idx);
   begin
      if not Item.Filetype_Extra_Loaded and then Length (Item.Filetype_Extra) = 0 then
         Item.Filetype_Extra :=
           To_Unbounded_String
             (Files.File_System.Extra_Info_Token
                (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype)));
         Item.Filetype_Extra_Loaded := True;
         if Length (Item.Filetype_Extra) > 0 then
            Model.Revision_Value := Model.Revision_Value + 1;
         end if;
         Model.Items.Replace_Element (Idx, Item);
      end if;
   end;
end Ensure_Selected_Item_Extra;
