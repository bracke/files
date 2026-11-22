with Files.File_Types;
separate (Files.Model)
procedure Reapply_Listing_Settings
  (Model      : in out Window_Model;
   Settings   : Files.Settings.Settings_Model;
   Reclassify : Boolean)
is
   --  Taken before the visibility changes: Restore_Selection keeps of them
   --  what is still shown, as a refresh does, and closes Quick Look.
   Selected : constant Files.Items.Item_Vectors.Vector := Selected_Items (Model);
   Primary  : constant UString :=
     (if Model.Selected_Item_Index in Model.Items.First_Index .. Model.Items.Last_Index
      then Model.Items (Model.Selected_Item_Index).Full_Path
      else Null_Unbounded_String);
   --  A new item's row being named is selected by a marker, not a path.
   Naming   : constant Boolean := Model.Selected_Item_Index = Temporary_Item_Index;
   Preview  : Quick_Look_State;
   Scroll      : constant Natural := Model.Main_View_Scroll;
   Info_Scroll : constant Natural := Model.Info_Pane_Scroll;
begin
   --  In place, as a background refresh is held back for them: the results,
   --  a rename or a new item's name in progress, the palette, the scroll and
   --  Quick Look stay; only what the settings decide changes. Every result
   --  stays, hidden ones too: the hidden-files setting applies when the rows
   --  are worked out (Item_Is_Visible), so a setting that hides them and then
   --  shows them again gives the same results back.
   Touch (Model);
   Model.Listing_Revision_Value := Model.Listing_Revision_Value + 1;
   if Reclassify then
      for Item of Model.Items loop
         declare
            Filetype : constant UString := To_Unbounded_String
              (Files.File_Types.Detect_Filetype (Settings, Item.Kind, To_String (Item.Name)));
         begin
            --  The details are read for a type: read again for the new one.
            if Filetype /= Item.Filetype then
               Item.Filetype_Extra := Files.Extra_Info.No_Info;
               Item.Filetype_Extra_Loaded := False;
            end if;
            Item.Filetype := Filetype;
            Item.Icon_Id := To_Unbounded_String
              (Files.File_Types.Icon_Id_For (Settings, Item.Kind, To_String (Filetype)));
         end;
      end loop;
      --  A type sort may order them differently now; the selection and the
      --  rename fields follow their items by path.
      Resort_Items (Model);
   end if;
   Model.Results_Hide_Hidden := not Settings.Show_Hidden_Files;
   Invalidate_Visible (Model);
   --  What the setting now hides leaves the selection, and nothing else
   --  takes its place; a rename field on it goes with it.
   Preview := Model.Quick_Look;
   Restore_Selection (Model, Selected, To_String (Primary));
   if Naming and then Temporary_Is_Visible (Model) then
      Model.Selected_Item_Index := Temporary_Item_Index;
      Add_Selected_Index (Model, Temporary_Item_Index);
   end if;
   Reconcile_Rename_With_Selection (Model);
   Set_Main_View_Scroll_Lines (Model, Scroll);
   --  Quick Look and the info pane's place stay while the selected item is
   --  still the one they show.
   if Length (Primary) > 0
     and then Model.Selected_Item_Index in Model.Items.First_Index .. Model.Items.Last_Index
     and then Model.Items (Model.Selected_Item_Index).Full_Path = Primary
   then
      Support.Set_Info_Pane_Scroll_Lines (Model, Info_Scroll);
      if Preview.Open and then Preview.Path = Primary then
         Model.Quick_Look := Preview;
      end if;
   end if;
end Reapply_Listing_Settings;
