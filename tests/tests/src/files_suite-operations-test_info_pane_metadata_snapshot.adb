separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Metadata_Snapshot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      Reset_Root;
      Write_Info_Metadata_Fixtures;
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Extra_Info_Token (Join (Root, "zheader.png"), Files.Types.Regular_File_Item, "image/png"),
         "image.dimensions|32x16",
         "PNG metadata reads dimensions only from a valid leading IHDR");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Extra_Info_Token (Join (Root, "zbad.png"), Files.Types.Regular_File_Item, "image/png"),
         "",
         "PNG metadata rejects dimensions outside a leading IHDR");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Extra_Info_Token (Join (Root, "zlate.jpg"), Files.Types.Regular_File_Item, "image/jpeg"),
         "",
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
      Files_Suite.Support.Assert_Equal
        (Natural (Snapshot.Selected_Info.Length),
         1,
         "snapshot contains selected item info");
      Assert (Snapshot.Selected_Info.Element (1).Name = To_Unbounded_String ("meta.txt"), "info name is captured");
      Assert (Snapshot.Items.Element (1).Size_Available, "item snapshot captures size availability");
      Files_Suite.Support.Assert_Equal
        (Snapshot.Items.Element (1).Size,
         Long_Long_Integer (Ada.Directories.Size (Join (Root, "meta.txt"))),
         "item snapshot captures size value");
      Assert (Snapshot.Items.Element (1).Modified_Available, "item snapshot captures modified availability");
      Assert
        (Snapshot.Items.Element (1).Modified_Time = Ada.Directories.Modification_Time (Join (Root, "meta.txt")),
         "item snapshot captures modified time value");
      Assert
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra) =
         Detail_Lines_Encoding
           ("info.extra.text.lines.prefix",
            "1",
            "info.extra.text.lines.suffix",
            "info.extra.encoding.ascii"),
         "item snapshot captures filesystem-backed filetype extra metadata");
      Assert (not Snapshot.Items.Element (1).Metadata_Error, "item snapshot captures metadata error state");
      Assert (Snapshot.Selected_Info.Element (1).Size_Available, "info size availability is captured");
      Files_Suite.Support.Assert_Equal
        (Snapshot.Selected_Info.Element (1).Size,
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
      Files_Suite.Support.Assert_Equal
        (To_String (Snapshot.Selected_Info.Element (1).Filetype_Detail),
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
   end Test_Info_Pane_Metadata_Snapshot;
