with Files.Extra_Info;
separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Localized_Extras (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;

      procedure Assert_Localized_Extra
        (Name     : String;
         Filetype : String;
         Extra    : Files.Extra_Info.Info;
         Expected : String;
         Message  : String;
         Kind     : Files.Types.Item_Kind := Files.Types.Regular_File_Item)
      is
         Items : Files.Items.Item_Vectors.Vector;
         Item  : Files.Items.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => Name,
              Kind        => Kind,
              Filetype    => Filetype);
      begin
         Item.Filetype_Extra := Extra;
         Items.Append (Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Files_Suite.Support.Assert_Equal
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra),
            Expected,
            Message);
      end Assert_Localized_Extra;
   begin
      Reset_Root;
      Assert_Localized_Extra
        (Name     => "folder",
         Filetype => "inode/directory",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Directory_Count, Count => 7),
         Expected => Detail_Value ("info.extra.directory.count", "count", "7"),
         Message  => "item snapshot localizes directory count metadata",
         Kind     => Files.Types.Directory_Item);
      Assert_Localized_Extra
        (Name     => "program",
         Filetype => "application/x-executable",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Executable_Format, Value => "elf"),
         Expected =>
           Detail_Localized_Value ("info.extra.executable.format", "format", "info.extra.executable.format.elf"),
         Message  => "item snapshot localizes executable format metadata",
         Kind     => Files.Types.Executable_Item);
      Assert_Localized_Extra
        (Name     => "picture.png",
         Filetype => "image/png",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Image_Dimensions, Value => "32x16"),
         Expected =>
           Detail_Value ("info.extra.image.dimensions", "dimensions", "32x16"),
         Message  => "item snapshot localizes image dimension metadata");
      Assert_Localized_Extra
        (Name     => "link",
         Filetype => "inode/symlink",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Symlink_Target, Value => "target.txt"),
         Expected =>
           Detail_Value ("info.extra.symlink.target", "target", "target.txt"),
         Message  => "item snapshot localizes symlink target metadata",
         Kind     => Files.Types.Symlink_Item);
      --  Typed, not a "kind|value" string: a target holding '|' comes through whole.
      Assert_Localized_Extra
        (Name     => "piped",
         Filetype => "inode/symlink",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Symlink_Target, Value => "a|b|c"),
         Expected => Detail_Value ("info.extra.symlink.target", "target", "a|b|c"),
         Message  => "a link target holding '|' is shown whole",
         Kind     => Files.Types.Symlink_Item);
      Assert_Localized_Extra
        (Name     => "paper.pdf",
         Filetype => "application/pdf",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Pdf_Pages, Count => 3),
         Expected =>
           Detail_Value ("info.extra.document.pdf.pages", "pages", "3"),
         Message  => "item snapshot localizes PDF page metadata");
      Assert_Localized_Extra
        (Name     => "archive.tar",
         Filetype => "application/x-tar",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Archive_Format, Value => "tar"),
         Expected =>
           Detail_Localized_Value ("info.extra.archive.format", "format", "info.extra.archive.format.tar"),
         Message  => "item snapshot localizes archive format metadata");
      Assert_Localized_Extra
        (Name     => "bundle.zip",
         Filetype => "application/zip",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Archive_Entries, "zip", Count => 5),
         Expected => Detail_Value ("info.extra.archive.entries", "count", "5"),
         Message  => "item snapshot localizes archive entry metadata");
      Assert_Localized_Extra
        (Name     => "report.docx",
         Filetype => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Office_Entries, "docx", Count => 9),
         Expected => Detail_Value ("info.extra.office.docx", "count", "9"),
         Message  => "item snapshot localizes document package metadata");
      Assert_Localized_Extra
        (Name     => "track.mp3",
         Filetype => "audio/mpeg",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Media_Kind, Value => "audio"),
         Expected => Files.Localization.Text ("info.extra.media.audio"),
         Message  => "item snapshot localizes audio media metadata");
      Assert_Localized_Extra
        (Name     => "clip.mp4",
         Filetype => "video/mp4",
         Extra    => Files.Extra_Info.Make (Files.Extra_Info.Media_Kind, Value => "video"),
         Expected => Files.Localization.Text ("info.extra.media.video"),
         Message  => "item snapshot localizes video media metadata");
   end Test_Info_Pane_Localized_Extras;
