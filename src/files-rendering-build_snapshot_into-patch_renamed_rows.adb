with Files.Model.Status_Samples;
with Files.Settings.Path_References;
separate (Files.Rendering.Build_Snapshot_Into)
   --  The rows kept from the last build, of which only the rename fields'
   --  text and carets changed since (Files.Model.Rename_Revision): each
   --  field is written into the row it is drawn in again, and the other rows
   --  stand. Which rows show a field does not change without the rows
   --  revision moving, so the rows noted when they were built still hold.
   procedure Patch_Renamed_Rows is
      use type Files.Model.Clipboard_Mode;
      --  A field whose item shows twice in the fields is written once, the
      --  first one, as a build does.
      Written : Renamed_Row_Maps.Map;

      function Row_Of (Visible_Index : Positive) return Natural is
        (if not Snapshot.Visible_Rows.Is_Empty
         then (if Visible_Index <= Natural (Snapshot.Visible_Rows.Length)
               then Snapshot.Visible_Rows (Visible_Index) else 0)
         elsif Visible_Index <= Natural (Snapshot.Items.Length) then Visible_Index
         else 0);

      procedure Write (Item_Index : Natural; Value : UString; Cursor : Natural) is
         Found : constant Renamed_Row_Maps.Cursor := Snapshot.Renamed_Rows.Find (Item_Index);
         Row   : Natural;
      begin
         if not Renamed_Row_Maps.Has_Element (Found) or else Written.Contains (Item_Index) then
            return;
         end if;
         Written.Insert (Item_Index, Renamed_Row_Maps.Element (Found));
         Row := Row_Of (Renamed_Row_Maps.Element (Found));
         if Row = 0 then
            return;
         end if;
         declare
            Shown : Item_Snapshot renames Snapshot.Items (Snapshot.Items.First_Index + Row - 1);
         begin
            Shown.Rename_Value := Value;
            Shown.Rename_Cursor := Cursor;
            --  The pending create row is named by its field: what the row
            --  shows of the name follows it, as a build would show it.
            if Item_Index = Files.Model.Temporary_Item_Index then
               declare
                  Item  : constant Files.Items.Directory_Item :=
                    Files.Model.Visible_Item (Model, Renamed_Row_Maps.Element (Found));
                  Paths : constant Files.Settings.Path_References.Path_Index :=
                    Files.Settings.Path_References.Index_Paths
          (Settings, Files.Model.Status_Samples.Name_Folding (Model));
                  Full  : constant String := To_String (Item.Full_Path);
               begin
                  Shown.Name := Item.Name;
                  Shown.Full_Path := Item.Full_Path;
                  Shown.Filetype := Item.Filetype;
                  Shown.Filetype_Detail := Filetype_Detail (Item);
                  Shown.Icon :=
                    Files.File_Types.Resolve_Icon (Item.Kind, To_String (Item.Filetype), To_String (Item.Icon_Id));
                  Shown.Cut_Pending :=
                    Files.Model.Clipboard.Mode_Of (Model) = Files.Model.Clipboard_Cut
                    and then Files.Model.Clipboard.Paths (Model).Contains (Item.Full_Path);
                  Shown.Is_Favorite := Files.Settings.Path_References.Is_Favorite (Paths, Full);
                  Shown.Label := Files.Settings.Path_References.Label_Of (Paths, Full);
               end;
            end if;
         end;
      end Write;
   begin
      Files.Model.Rename.For_Each_Field (Model, Write'Access);
   end Patch_Renamed_Rows;
