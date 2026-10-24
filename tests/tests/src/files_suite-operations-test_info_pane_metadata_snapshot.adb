separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      procedure Write_Late_JPEG (Path : String) is
         use type Ada.Streams.Stream_IO.Count;
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         String'Write
           (Ada.Streams.Stream_IO.Stream (File), Byte (16#FF#) & Byte (16#D8#));
         --  Sparse APP segments put the first dimensions marker just beyond
         --  the metadata scan budget without writing an eight-megabyte fixture.
         for Segment in 1 .. 128 loop
            String'Write
              (Ada.Streams.Stream_IO.Stream (File),
               Byte (16#FF#) & Byte (16#E0#) & Byte (16#FF#) & Byte (16#FF#));
            Ada.Streams.Stream_IO.Set_Index
              (File, Ada.Streams.Stream_IO.Index (File) +
                 Ada.Streams.Stream_IO.Count (65_533));
         end loop;
         String'Write
           (Ada.Streams.Stream_IO.Stream (File),
            Byte (16#FF#) & Byte (16#C0#) & Byte (0) & Byte (7) & Byte (8) &
            Byte (0) & Byte (16) & Byte (0) & Byte (32));
         Ada.Streams.Stream_IO.Close (File);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Write_Late_JPEG;

      function Detail_Value
        (Prefix_Key : String;
         Value      : String;
         Suffix_Key : String)
         return String
      is
         Prefix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
         Suffix : constant String :=
           Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
      begin
         if Suffix'Length > 0
           and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
         then
            return Prefix & " " & Value & " " & Suffix;
         else
            return Prefix & " " & Value & Suffix;
         end if;
      end Detail_Value;

      function Detail_Localized_Value
        (Prefix_Key : String;
         Value_Key  : String;
         Suffix_Key : String)
         return String
      is
      begin
         return Detail_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
      end Detail_Localized_Value;

      function Detail_Lines_Encoding
        (Lines_Prefix_Key : String;
         Lines            : String;
         Lines_Suffix_Key : String;
         Encoding_Key     : String)
         return String
      is
      begin
         return
           Detail_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
           & " "
           & Detail_Localized_Value
             ("info.extra.encoding.prefix", Encoding_Key, "info.extra.encoding.suffix");
      end Detail_Lines_Encoding;

      procedure Assert_Localized_Extra
        (Name     : String;
         Filetype : String;
         Token    : String;
         Expected : String;
         Message  : String;
         Kind     : Files.Types.Item_Kind := Files.Types.Regular_File_Item)
      is
         Items : Files.File_System.Item_Vectors.Vector;
         Item  : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => Name,
              Kind        => Kind,
              Filetype    => Filetype);
      begin
         Item.Filetype_Extra := To_Unbounded_String (Token);
         Items.Append (Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) = Expected,
            Message);
      end Assert_Localized_Extra;
   begin
      Reset_Root;
      Write_File (Join (Root, "meta.txt"), "abcd");
      Write_File (Join (Root, "zmarkdown.md"), "# Title" & ASCII.LF & "body");
      Write_Binary_File (Join (Root, "zsheet.xlsx"), "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File
        (Join (Root, "zbinary.pdf"),
         "%PDF-1.7" & Character'Val (16#FF#) & ASCII.LF
         & "1 0 obj <</Type /Page>>" & ASCII.LF
         & "2 0 obj <</Type /Pages /Count 1>>");
      Write_Binary_File (Join (Root, "zutf8.txt"), "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Join (Root, "zbinary.txt"), "bad" & Character'Val (16#C3#));
      Write_File
        (Join (Root, "zunit.adb"),
         "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Join (Root, "zdata.json"), "{""ok"":true}");
      Write_File (Join (Root, "zdoc.xml"), "<root/>");
      Write_Binary_File
        (Join (Root, "zheader.png"),
         Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) &
         Byte (16#1A#) & Byte (16#0A#) & Byte (0) & Byte (0) & Byte (0) &
         Byte (13) & "IHDR" & Byte (0) & Byte (0) & Byte (0) & Byte (32) &
         Byte (0) & Byte (0) & Byte (0) & Byte (16));
      Write_Binary_File
        (Join (Root, "zbad.png"),
         Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) &
         Byte (16#1A#) & Byte (16#0A#) & Byte (0) & Byte (0) & Byte (0) &
         Byte (13) & "NOPE" & Byte (0) & Byte (0) & Byte (0) & Byte (32) &
         Byte (0) & Byte (0) & Byte (0) & Byte (16));
      Write_Late_JPEG (Join (Root, "zlate.jpg"));
      Assert
        (Files.File_System.Extra_Info_Token
           (Join (Root, "zheader.png"), Files.Types.Regular_File_Item,
            "image/png") = "image.dimensions|32x16",
         "PNG metadata reads dimensions only from a valid leading IHDR");
      Assert
        (Files.File_System.Extra_Info_Token
           (Join (Root, "zbad.png"), Files.Types.Regular_File_Item,
            "image/png") = "",
         "PNG metadata rejects dimensions outside a leading IHDR");
      Assert
        (Files.File_System.Extra_Info_Token
           (Join (Root, "zlate.jpg"), Files.Types.Regular_File_Item,
            "image/jpeg") = "",
         "JPEG metadata stops before a dimensions marker beyond the scan budget");
      Assert
        (Files.File_System.Extra_Info_Token
           (Join (Root, "zbinary.pdf"), Files.Types.Regular_File_Item,
            "application/pdf") = "document.pdf.pages|1",
         "PDF metadata scans binary bytes and does not count the Pages tree");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      --  Extra info is computed lazily for the selected item when the info pane
      --  is open (the interaction reducer does this after each input).
      Files.Model.Ensure_Selected_Item_Extra (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 1, "snapshot contains selected item info");
      Assert (Snapshot.Selected_Info.Element (1).Name = To_Unbounded_String ("meta.txt"), "info name is captured");
      Assert (Snapshot.Items.Element (1).Size_Available, "item snapshot captures size availability");
      Assert
        (Snapshot.Items.Element (1).Size = Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "item snapshot captures size value");
      Assert (Snapshot.Items.Element (1).Modified_Available, "item snapshot captures modified availability");
      Assert
        (Snapshot.Items.Element (1).Modified_Time = Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "item snapshot captures modified time value");
      Assert
        (To_String (Snapshot.Items.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "item snapshot captures filesystem-backed filetype extra metadata");
      Assert (not Snapshot.Items.Element (1).Metadata_Error, "item snapshot captures metadata error state");
      Assert (Snapshot.Selected_Info.Element (1).Size_Available, "info size availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Size =
           Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "info size value is captured");
      Assert (Snapshot.Selected_Info.Element (1).Modified_Available, "info modified availability is captured");
      Assert
        (Snapshot.Selected_Info.Element (1).Modified_Time =
           Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "info modified time value is captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Permissions)'Length = 3,
         "info permissions are captured");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "info pane captures filetype-specific detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "info pane captures loaded text line metadata");
      --  Visit each item so its lazy extra info is computed and cached (as
      --  happens when the selection lands on it with the info pane open), then
      --  rebuild the snapshot so it carries every item's localized extra.
      for Idx in 1 .. Files.Model.Visible_Count (Model) loop
         Files.Model.Select_Visible (Model, Idx);
         Files.Model.Ensure_Selected_Item_Extra (Model);
      end loop;
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      declare
         Found_Utf8_Metadata   : Boolean := False;
         Found_Binary_Metadata : Boolean := False;
         Found_Markdown_Metadata : Boolean := False;
         Found_Xlsx_Metadata   : Boolean := False;
         Found_Ada_Metadata    : Boolean := False;
         Found_Json_Metadata   : Boolean := False;
         Found_Xml_Metadata    : Boolean := False;
      begin
         for Item of Snapshot.Items loop
            if To_String (Item.Name) = "zutf8.txt" then
               Found_Utf8_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.utf8");
            elsif To_String (Item.Name) = "zbinary.txt" then
               Found_Binary_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.text.lines.prefix",
                      "1",
                      "info.extra.text.lines.suffix",
                      "info.extra.encoding.binary");
            elsif To_String (Item.Name) = "zmarkdown.md" then
               Found_Markdown_Metadata :=
                 To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.markdown.lines.prefix",
                      "2",
                      "info.extra.markdown.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zsheet.xlsx" then
               Found_Xlsx_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.document.spreadsheet")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Value ("info.extra.office.xlsx.prefix", "1", "info.extra.office.entries.suffix");
            elsif To_String (Item.Name) = "zunit.adb" then
               Found_Ada_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.ada")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.ada.prefix",
                      "4",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdata.json" then
               Found_Json_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.json")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.json.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            elsif To_String (Item.Name) = "zdoc.xml" then
               Found_Xml_Metadata :=
                 To_String (Item.Filetype_Detail) =
                   Files.Localization.Text ("info.kind.source.xml")
                 and then To_String (Item.Filetype_Extra) =
                   Detail_Lines_Encoding
                     ("info.extra.source.xml.prefix",
                      "1",
                      "info.extra.source.lines.suffix",
                      "info.extra.encoding.ascii");
            end if;
         end loop;

         Assert (Found_Utf8_Metadata, "item snapshot localizes UTF-8 text metadata");
         Assert (Found_Binary_Metadata, "item snapshot localizes binary text metadata");
         Assert (Found_Markdown_Metadata, "item snapshot localizes Markdown metadata");
         Assert (Found_Xlsx_Metadata, "item snapshot localizes XLSX metadata");
         Assert (Found_Ada_Metadata, "item snapshot localizes Ada source metadata");
         Assert (Found_Json_Metadata, "item snapshot localizes JSON source metadata");
         Assert (Found_Xml_Metadata, "item snapshot localizes XML source metadata");
      end;

      Assert_Localized_Extra
        (Name     => "folder",
         Filetype => "inode/directory",
         Token    => "directory.count|7",
         Expected => Detail_Value ("info.extra.directory.count.prefix", "7", "info.extra.directory.count.suffix"),
         Message  => "item snapshot localizes directory count metadata",
         Kind     => Files.Types.Directory_Item);
      Assert_Localized_Extra
        (Name     => "program",
         Filetype => "application/x-executable",
         Token    => "executable.format|elf",
         Expected =>
           Detail_Localized_Value
             ("info.extra.executable.format.prefix",
              "info.extra.executable.format.elf",
              "info.extra.executable.format.suffix"),
         Message  => "item snapshot localizes executable format metadata",
         Kind     => Files.Types.Executable_Item);
      Assert_Localized_Extra
        (Name     => "picture.png",
         Filetype => "image/png",
         Token    => "image.dimensions|32x16",
         Expected =>
           Detail_Value ("info.extra.image.dimensions.prefix", "32x16", "info.extra.image.dimensions.suffix"),
         Message  => "item snapshot localizes image dimension metadata");
      Assert_Localized_Extra
        (Name     => "link",
         Filetype => "inode/symlink",
         Token    => "symlink.target|target.txt",
         Expected =>
           Detail_Value ("info.extra.symlink.target.prefix", "target.txt", "info.extra.symlink.target.suffix"),
         Message  => "item snapshot localizes symlink target metadata",
         Kind     => Files.Types.Symlink_Item);
      Assert_Localized_Extra
        (Name     => "paper.pdf",
         Filetype => "application/pdf",
         Token    => "document.pdf.pages|3",
         Expected =>
           Detail_Value ("info.extra.document.pdf.pages.prefix", "3", "info.extra.document.pdf.pages.suffix"),
         Message  => "item snapshot localizes PDF page metadata");
      Assert_Localized_Extra
        (Name     => "archive.tar",
         Filetype => "application/x-tar",
         Token    => "archive.format|tar",
         Expected =>
           Detail_Localized_Value
             ("info.extra.archive.format.prefix",
              "info.extra.archive.format.tar",
              "info.extra.archive.format.suffix"),
         Message  => "item snapshot localizes archive format metadata");
      Assert_Localized_Extra
        (Name     => "bundle.zip",
         Filetype => "application/zip",
         Token    => "archive.zip.entries|5",
         Expected => Detail_Value ("info.extra.archive.entries.prefix", "5", "info.extra.archive.entries.suffix"),
         Message  => "item snapshot localizes archive entry metadata");
      Assert_Localized_Extra
        (Name     => "report.docx",
         Filetype => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         Token    => "office.docx.entries|9",
         Expected => Detail_Value ("info.extra.office.docx.prefix", "9", "info.extra.office.entries.suffix"),
         Message  => "item snapshot localizes document package metadata");
      Assert_Localized_Extra
        (Name     => "track.mp3",
         Filetype => "audio/mpeg",
         Token    => "media.kind|audio",
         Expected => Files.Localization.Text ("info.extra.media.audio"),
         Message  => "item snapshot localizes audio media metadata");
      Assert_Localized_Extra
        (Name     => "clip.mp4",
         Filetype => "video/mp4",
         Token    => "media.kind|video",
         Expected => Files.Localization.Text ("info.extra.media.video"),
         Message  => "item snapshot localizes video media metadata");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Ensure_Selected_Item_Extra (Model);
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
         Assert (Header_R and then Header_W and then Header_E,
                 "info pane permission matrix has an R/W/E column header");
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

      declare
         Narrow_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
         Narrow_Info     : Files.Rendering.Info_Snapshot :=
           Narrow_Snapshot.Selected_Info.Element (1);
         Narrow_Frame    : Files.Rendering.Frame_Commands;
         Found_First     : Boolean := False;
         Found_Second    : Boolean := False;
         Found_Broken    : Boolean := False;
      begin
         Narrow_Info.Filetype_Extra :=
           To_Unbounded_String ("Markdown document has 233 lines.");
         Narrow_Snapshot.Selected_Info.Replace_Element (1, Narrow_Info);
         Narrow_Frame :=
           Files.Rendering.Build_Frame_Commands
             (Narrow_Snapshot, Width => 640, Height => 800, Line_Height => 20);

         for Text of Narrow_Frame.Text loop
            Found_First :=
              Found_First or else To_String (Text.Text) = "Markdown document has";
            Found_Second := Found_Second or else To_String (Text.Text) = "233 lines.";
            Found_Broken :=
              Found_Broken
              or else To_String (Text.Text) = "Markdown document has 2"
              or else To_String (Text.Text) = "33 lines.";
         end loop;

         Assert (Found_First and then Found_Second and then not Found_Broken,
                 "info metadata wraps at word boundaries instead of splitting words");
      end;

      declare
         Items          : Files.File_System.Item_Vectors.Vector;
         Broken_Item    : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "broken.txt",
              Kind        => Files.Types.Regular_File_Item,
              Filetype    => "text/plain");
         Found_Localized : Boolean := False;
         Found_A11y_Metadata : Boolean := False;
      begin
         Broken_Item.Metadata_Error := True;
         Broken_Item.Error_Key := To_Unbounded_String ("error.metadata.read");
         Items.Append (Broken_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 2000, Height => 800, Line_Height => 20);

         for Text of Frame.Text loop
            --  The value is postfixed with " (broken.txt)", so match the prefix.
            if Ada.Strings.Fixed.Index
                 (To_String (Text.Text), Files.Localization.Text ("error.metadata.read")) = 1
            then
               Found_Localized := True;
            end if;
         end loop;
         for Node of Frame.Accessibility loop
            if Node.Role = Guikit.Draw.Role_List_Item
              and then To_String (Node.Name) = "broken.txt"
              and then Ada.Strings.Fixed.Index
                (To_String (Node.Description),
                 Files.Localization.Text ("info.metadata_error") & ": "
                 & Files.Localization.Text ("error.metadata.read")) > 0
            then
               Found_A11y_Metadata := True;
            end if;
         end loop;

         Assert (Found_Localized, "info pane localizes metadata error keys");
         Assert (Found_A11y_Metadata, "info pane accessibility describes metadata error keys");
      end;

      Write_File (Join (Root, "blob.bin"), "binary");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "blob.bin");
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Files.Localization.Text ("info.extra.extension.prefix") &
         "bin" &
         Files.Localization.Text ("info.extra.extension.suffix"),
         "info pane captures extension metadata fallback");
      Files.Model.Toggle_Info_Pane (Model);

      Write_File (Join (Root, "run.sh"), "#!/bin/sh" & ASCII.LF);
      declare
         Items : Files.File_System.Item_Vectors.Vector;
         Exec_Item : Files.File_System.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "run.sh",
              Kind        => Files.Types.Executable_Item,
              Filetype    => "application/x-executable");
      begin
         Exec_Item.Size_Available := True;
         Exec_Item.Size := Long_Long_Integer (Ada.Directories.Size (Join (Root, "run.sh")));
         Items.Append (Exec_Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (Ada.Strings.Fixed.Index
              (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra),
               Files.Localization.Text ("info.extra.executable.size.prefix")) = 1,
            "info pane captures executable snapshot metadata without reading file contents");
      end;

      declare
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append
           (Files.File_System.Make_Item
              (Parent_Path => Join (Root, "missing-parent"),
               Name        => "ghost.bin",
               Kind        => Files.Types.Regular_File_Item,
               Filetype    => "application/octet-stream"));
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Assert
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
            Files.Localization.Text ("info.extra.extension.prefix") &
            "bin" &
            Files.Localization.Text ("info.extra.extension.suffix"),
            "info pane snapshot uses item fields without reading a backing file");
      end;

      Write_File (Join (Root, "more.txt"), "efgh");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Filter (Model, ".txt");
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert (Natural (Snapshot.Selected_Info.Length) = 2, "info snapshot includes all selected items");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Name) = "meta.txt",
         "multi-selection info preserves first selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Name) = "more.txt",
         "multi-selection info preserves second selected item order");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes first filetype detail");
      Assert
        (To_String (Snapshot.Selected_Info.Element (2).Filetype_Detail) =
         Files.Localization.Text ("info.kind.text"),
         "multi-selection info localizes second filetype detail");
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      declare
         Layout       : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
         Info_Layout  : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line_Height => 20);
         --  A multi-item selection draws a COALESCED, field-major layout: each
         --  section label appears once and each value row is postfixed with its
         --  item name, so there is no dedicated Name section.
         Name_Label       : constant String := Files.Localization.Text ("info.name");
         Name_Label_Count : Natural := 0;
         Meta_Postfixed   : Boolean := False;
         More_Postfixed   : Boolean := False;

         function Ends_With (Text : Unbounded_String; Suffix : String) return Boolean is
         begin
            return Length (Text) >= Suffix'Length
              and then Slice (Text, Length (Text) - Suffix'Length + 1, Length (Text)) = Suffix;
         end Ends_With;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_Layout.X then
               if To_String (Text.Text) = Name_Label then
                  Name_Label_Count := Name_Label_Count + 1;
               elsif Ends_With (Text.Text, " (meta.txt)") then
                  Meta_Postfixed := True;
               elsif Ends_With (Text.Text, " (more.txt)") then
                  More_Postfixed := True;
               end if;
            end if;
         end loop;

         Assert
           (Name_Label_Count = 0,
            "coalesced info pane has no dedicated Name section");
         Assert
           (Meta_Postfixed and then More_Postfixed,
            "each selected item's rows are postfixed with its own name");
      end;
   end Test_Info_Pane_Metadata_Snapshot;
