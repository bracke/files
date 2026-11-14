with Files.File_Types;
separate (Files.Model)
procedure Reapply_Listing_Settings
  (Model      : in out Window_Model;
   Settings   : Files.Settings.Settings_Model;
   Reclassify : Boolean)
is
   Selected : constant Files.Items.Item_Vectors.Vector := Selected_Items (Model);
   Primary  : constant UString :=
     (if Model.Selected_Item_Index in Model.Items.First_Index .. Model.Items.Last_Index
      then Model.Items (Model.Selected_Item_Index).Full_Path
      else Null_Unbounded_String);
   Scroll   : constant Natural := Model.Main_View_Scroll;
   Kept     : Files.Items.Item_Vectors.Vector;
begin
   for Item of Model.Items loop
      if Settings.Show_Hidden_Files or else not Item.Hidden then
         declare
            Changed : Files.Items.Directory_Item := Item;
         begin
            if Reclassify then
               Changed.Filetype := To_Unbounded_String
                 (Files.File_Types.Detect_Filetype (Settings, Item.Kind, To_String (Item.Name)));
               Changed.Icon_Id := To_Unbounded_String
                 (Files.File_Types.Icon_Id_For (Settings, Item.Kind, To_String (Changed.Filetype)));
               --  The details are read for a type: read again for the new one.
               if Changed.Filetype /= Item.Filetype then
                  Changed.Filetype_Extra := Files.Extra_Info.No_Info;
                  Changed.Filetype_Extra_Loaded := False;
               end if;
            end if;
            Kept.Append (Changed);
         end;
      end if;
   end loop;
   --  Swap_Items keeps the search state; it resets what a relisting resets.
   Swap_Items (Model, Kept, Sorted => True);
   Restore_Selection (Model, Selected, To_String (Primary));
   Set_Main_View_Scroll_Lines (Model, Scroll);
end Reapply_Listing_Settings;
