separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Type_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      Reset_Root;
      Write_Info_Metadata_Fixtures;
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "meta.txt");
      Files.Model.Toggle_Info_Pane (Model);
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
   end Test_Info_Pane_Type_Metadata;
