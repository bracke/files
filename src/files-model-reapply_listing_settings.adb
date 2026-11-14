with Files.File_Types;
separate (Files.Model)
procedure Reapply_Listing_Settings
  (Model      : in out Window_Model;
   Settings   : Files.Settings.Settings_Model;
   Reclassify : Boolean)
is
   Selected    : constant Files.Items.Item_Vectors.Vector := Selected_Items (Model);
   Primary     : constant UString :=
     (if Model.Selected_Item_Index in Model.Items.First_Index .. Model.Items.Last_Index
      then Model.Items (Model.Selected_Item_Index).Full_Path
      else Null_Unbounded_String);
   Scroll      : constant Natural := Model.Main_View_Scroll;
   Info_Scroll : constant Natural := Model.Info_Pane_Scroll;
   Kept        : Files.Items.Item_Vectors.Vector;
begin
   --  Every result stays, hidden ones too: the hidden-files setting applies
   --  when the rows are worked out (Item_Is_Visible), so a setting that
   --  hides them and then shows them again gives the same results back.
   if Reclassify then
      Kept.Reserve_Capacity (Model.Items.Length);
      for Item of Model.Items loop
         declare
            Changed : Files.Items.Directory_Item := Item;
         begin
            Changed.Filetype := To_Unbounded_String
              (Files.File_Types.Detect_Filetype (Settings, Item.Kind, To_String (Item.Name)));
            Changed.Icon_Id := To_Unbounded_String
              (Files.File_Types.Icon_Id_For (Settings, Item.Kind, To_String (Changed.Filetype)));
            --  The details are read for a type: read again for the new one.
            if Changed.Filetype /= Item.Filetype then
               Changed.Filetype_Extra := Files.Extra_Info.No_Info;
               Changed.Filetype_Extra_Loaded := False;
            end if;
            Kept.Append (Changed);
         end;
      end loop;
   else
      Kept := Model.Items;
   end if;
   --  Swap_Items keeps the search state; it resets what a relisting resets.
   Swap_Items (Model, Kept, Sorted => True);
   Touch (Model);
   Model.Results_Hide_Hidden := not Settings.Show_Hidden_Files;
   Invalidate_Visible (Model);
   Restore_Selection (Model, Selected, To_String (Primary));
   Set_Main_View_Scroll_Lines (Model, Scroll);
   --  The info pane keeps its place while it shows the same item (as
   --  Keep_Info_Pane after a refresh): Swap_Items reset it.
   if Length (Primary) > 0
     and then Model.Selected_Item_Index in Model.Items.First_Index .. Model.Items.Last_Index
     and then Model.Items (Model.Selected_Item_Index).Full_Path = Primary
   then
      Set_Info_Pane_Scroll_Lines (Model, Info_Scroll);
   end if;
end Reapply_Listing_Settings;
