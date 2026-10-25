separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Frame_Layout (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
      Write_Info_Metadata_Fixtures;
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      --  Tall enough that every info-pane row (now including the owner/group
      --  fields) stays within the visible pane rather than being clipped.
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 1200, Line_Height => 20);
      declare
         Found_Name         : Boolean := False;
         Found_Name_Heading : Boolean := False;
         Found_Heading_Bold : Boolean := False;
         Found_Top_Value    : Boolean := False;
         Found_Top_Bold     : Boolean := False;
         Found_Top_Label    : Boolean := False;
         Found_Postfixed_Value : Boolean := False;
         Found_Filetype     : Boolean := False;
         Found_Filetype_Value : Boolean := False;
         Found_Size         : Boolean := False;
         Found_Size_Value   : Boolean := False;
         Found_Created      : Boolean := False;
         Found_Modified     : Boolean := False;
         Found_Permissions  : Boolean := False;
         Found_Perm_Text    : Boolean := False;
         Header_R, Header_W, Header_E : Boolean := False;
         Row_User, Row_Other : Boolean := False;
         Found_Metadata_Key : Boolean := False;
         Found_Kind         : Boolean := False;
         Found_Extra        : Boolean := False;
         Found_Extra_First  : Boolean := False;
         Found_Extra_Second : Boolean := False;
         Extra_First_Y      : Natural := 0;
         Found_Relative_Time : Boolean := False;
         Found_A11y_Section : Boolean := False;
         Info_X             : constant Natural := Frame.Layout.Main_Width + 10;
         Info_Y             : constant Natural := Frame.Layout.Main_Y + 10;
      begin
         for Text of Frame.Text loop
            declare
               Raw    : constant String := To_String (Text.Text);
               Suffix : constant String := " (meta.txt)";
               Postfixed : constant Boolean :=
                 Raw'Length > Suffix'Length
                 and then Raw (Raw'Last - Suffix'Length + 1 .. Raw'Last) = Suffix;
               Value : constant String := Raw;
            begin
               if Postfixed and then Text.X = Info_X then
                  Found_Postfixed_Value := True;
               end if;

               if Value = "meta.txt"
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y
               then
                  Found_Name_Heading := True;
               elsif Value = "meta.txt"
                 and then Text.X = Info_X + 1
                 and then Text.Y = Info_Y
               then
                  Found_Heading_Bold := True;
               elsif Value = Files.Localization.Text ("info.name")
                 and then Text.X >= Info_X
               then
                  Found_Name := True;
               elsif Value = Files.Localization.Text ("info.filetype")
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y + 40
               then
                  Found_Top_Label := True;
                  Found_Filetype := True;
               elsif Value = Files.Localization.Text ("info.filetype")
                 and then Text.X = Info_X + 1
                 and then Text.Y = Info_Y + 40
               then
                  Found_Top_Bold := True;
               elsif Value = Files.Localization.Text ("info.filetype") then
                  Found_Filetype := True;
               elsif Value = Files.Localization.Text ("info.kind.text")
                 and then Text.X = Info_X
                 and then Text.Y = Info_Y + 60
               then
                  Found_Top_Value := True;
                  Found_Filetype_Value := True;
               elsif Value = Files.Localization.Text ("info.kind.text") then
                  Found_Filetype_Value := True;
               elsif Value = Files.Localization.Text ("info.size") then
                  Found_Size := True;
               --  The size as humanize writes it: CLDR's "byte"/"bytes".
               elsif Ada.Strings.Fixed.Index (Value, " byte") > 1
                 and then Value /= Files.Localization.Text ("info.size")
               then
                  Found_Size_Value := True;
               elsif Value = Files.Localization.Text ("info.created") then
                  Found_Created := True;
               elsif Value = Files.Localization.Text ("info.modified") then
                  Found_Modified := True;
               elsif Value = Files.Localization.Text ("info.permissions") then
                  Found_Permissions := True;
               elsif Text.X >= Info_X and then Value = "R" then
                  Header_R := True;
               elsif Text.X >= Info_X and then Value = "W" then
                  Header_W := True;
               elsif Text.X >= Info_X and then Value = "E" then
                  Header_E := True;
               elsif Value = Files.Localization.Text ("info.permissions.user") then
                  Row_User := True;
               elsif Value = Files.Localization.Text ("info.permissions.other") then
                  Row_Other := True;
               elsif Value = Files.Localization.Text ("info.permissions.readable")
                 or else Value = Files.Localization.Text ("info.permissions.writable")
               then
                  --  Must NOT happen: the stacked text summary was replaced by
                  --  the matrix for a single selection.
                  Found_Perm_Text := True;
               elsif Value = Files.Localization.Text ("info.metadata_error") then
                  Found_Metadata_Key := True;
               elsif Value = Files.Localization.Text ("info.kind") then
                  Found_Kind := True;
               elsif Value = Files.Localization.Text ("info.extra") then
                  Found_Extra := True;
               elsif Value =
                 Detail_Value ("info.extra.text.lines.prefix", "1", "info.extra.text.lines.suffix")
               then
                  Found_Extra_First := True;
                  Extra_First_Y := Text.Y;
               elsif Value =
                 Detail_Localized_Value
                   ("info.extra.encoding.prefix",
                    "info.extra.encoding.ascii",
                    "info.extra.encoding.suffix")
               then
                  Found_Extra_Second := Extra_First_Y > 0 and then Text.Y = Extra_First_Y + 20;
               elsif Value = Files.Localization.Text ("time.relative.now")
                 or else Ada.Strings.Fixed.Index
                   (Value, Files.Localization.Text ("time.relative.today") & " ") = 1
               then
                  Found_Relative_Time := True;
               end if;
            end;
         end loop;

         for Node of Frame.Accessibility loop
            if Node.Role = Guikit.Draw.Role_List_Item
              and then To_String (Node.Name) = "meta.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.filetype") & ": " &
                 Files.Localization.Text ("info.kind.text")) > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.size") & ":") > 0
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description), Files.Localization.Text ("info.modified") & ":") > 0
            then
               Found_A11y_Section := True;
            end if;
         end loop;

         Assert (not Found_Name, "info pane does not waste a row on a Name label");
         Assert (Found_Name_Heading and then Found_Heading_Bold,
                 "info pane renders the selected item name once as a heading");
         Assert (Found_Top_Label, "info pane places filetype below the item heading");
         Assert (Found_Top_Bold, "info pane label renders with bold offset");
         Assert (Found_Top_Value, "info pane value follows label on next row");
         Assert (not Found_Postfixed_Value,
                 "info pane single-item values do not repeat the item name");
         Assert (Found_Filetype, "info pane frame includes localized filetype row");
         Assert (Found_Filetype_Value, "info pane filetype value is separate from label");
         Assert (Found_Size, "info pane frame includes localized size row");
         Assert (Found_Size_Value, "info pane frame includes size unit");
         Assert (Found_Created, "info pane frame includes localized missing creation row");
         Assert (Found_Modified, "info pane frame includes localized modified row");
         Assert (Found_Permissions, "info pane frame includes localized permissions label");
         Assert (Header_R, "info pane permission matrix has an R/W/E column header: R");
         Assert (Header_W, "info pane permission matrix has an R/W/E column header: W");
         Assert (Header_E, "info pane permission matrix has an R/W/E column header: E");
         Assert (Row_User and then Row_Other,
                 "info pane permission matrix labels its user/group/other rows");
         Assert (not Found_Perm_Text,
                 "single-item permissions show the matrix, not a stacked text summary");
         Assert (Natural (Frame.Permission_Hits.Length) > 0,
                 "the editable single item registers clickable permission cells");
         Assert (not Found_Metadata_Key,
                 "a healthy item shows no Metadata Error row");
         Assert (not Found_Kind, "info pane no longer shows the redundant Kind row");
         Assert (Found_Extra, "info pane frame includes filetype-specific extra metadata row");
         Assert (Found_Extra_First, "info pane details renders first metadata item");
         Assert (Found_Extra_Second, "info pane details renders second metadata item on separate row");
         Assert (Found_Relative_Time, "info pane humanizes recent metadata timestamps");
         Assert (Found_A11y_Section, "info pane frame exposes accessible selected-file section");
      end;
   end Test_Info_Pane_Frame_Layout;
