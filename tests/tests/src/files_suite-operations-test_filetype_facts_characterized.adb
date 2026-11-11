with Files.File_Types;
separate (Files_Suite.Operations)
   --  What every filetype is labelled with, what extra line it falls back to
   --  and which icon it shows -- recorded from the cascades the one MIME table
   --  in Files.File_Types replaced (the kind label in the snapshot's
   --  Filetype_Detail, the extra-info fallback in Filetype_Extra, the icon in
   --  three cascades of Add_Icon), for every filetype they knew plus a few
   --  they did not. Each is checked in the table and end to end through a
   --  snapshot, so a change to either shows here.
   procedure Test_Filetype_Facts_Characterized (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.File_Types.Icon_Kind;

      Docx : constant String := "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
      Xlsx : constant String := "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;

      --  Check one filetype. Label and Extra are catalog keys, "" where the
      --  file's extension names it; Icon is the icon a file of the type shows
      --  when its icon identifier names no bundled icon.
      procedure Check
        (Mime  : String;
         Label : String;
         Extra : String;
         Icon  : Files.File_Types.Icon_Kind)
      is
         Facts : constant Files.File_Types.Filetype_Facts := Files.File_Types.Facts_For (Mime);
         Items : Files.Items.Item_Vectors.Vector;
         Item  : Files.Items.Directory_Item :=
           Files.File_System.Make_Item
             (Parent_Path => Root,
              Name        => "sample.dat",
              Kind        => Files.Types.Regular_File_Item,
              Filetype    => Mime);
      begin
         Files_Suite.Support.Assert_Equal
           (Files.File_Types.Label_Key (Facts.Label), Label, "the kind label key of '" & Mime & "'");
         Files_Suite.Support.Assert_Equal
           (Files.File_Types.Extra_Key (Facts.Extra), Extra, "the extra fallback key of '" & Mime & "'");
         Assert (Facts.Icon = Icon, "the icon of '" & Mime & "'");

         --  Through a snapshot: the words on screen and the icon drawn.
         Item.Filetype := To_Unbounded_String (Mime);
         Item.Icon_Id := To_Unbounded_String ("not-a-bundled-icon");
         Items.Append (Item);
         Files.Model.Initialize (Model, Root, Items, Root);
         Files.Model.Select_Visible (Model, 1);
         Files.Model.Toggle_Info_Pane (Model);
         Snapshot := Files.Rendering.Build_Snapshot (Model);
         Files_Suite.Support.Assert_Equal
           (To_String (Snapshot.Items.Element (1).Filetype_Detail),
            (if Label = "" then "DAT" else Files.Localization.Text (Label)),
            "the type column shows the kind of '" & Mime & "'");
         Files_Suite.Support.Assert_Equal
           (To_String (Snapshot.Selected_Info.Element (1).Filetype_Extra),
            (if Extra = "" then Detail_Value ("info.extra.extension", "extension", "dat")
             else Files.Localization.Text (Extra)),
            "the info pane's extra line for '" & Mime & "'");
         Assert (Snapshot.Items.Element (1).Icon = Icon, "the snapshot draws '" & Mime & "' with its icon");
      end Check;
   begin
      Reset_Root;

      --  Every filetype the cascades named.
      Check ("text/plain", "info.kind.text", "info.extra.text", Files.File_Types.Text_Icon);
      Check ("text/markdown", "info.kind.markdown", "info.extra.markdown", Files.File_Types.Markdown_Icon);
      Check ("text/x-ada", "info.kind.source.ada", "", Files.File_Types.Text_Icon);
      Check ("application/json", "info.kind.source.json", "", Files.File_Types.Unknown_Icon);
      Check ("application/xml", "info.kind.source.xml", "", Files.File_Types.Unknown_Icon);
      Check ("image/png", "info.kind.image.png", "info.extra.image", Files.File_Types.Image_Icon);
      Check ("image/jpeg", "info.kind.image.jpeg", "info.extra.image", Files.File_Types.Image_Icon);
      Check ("application/pdf", "info.kind.document.pdf", "", Files.File_Types.Unknown_Icon);
      Check (Docx, "info.kind.document.word", "", Files.File_Types.Unknown_Icon);
      Check (Xlsx, "info.kind.document.spreadsheet", "", Files.File_Types.Unknown_Icon);
      Check ("application/zip", "info.kind.archive", "", Files.File_Types.Unknown_Icon);
      Check ("application/x-tar", "info.kind.archive", "", Files.File_Types.Unknown_Icon);
      Check ("application/gzip-tar", "info.kind.archive", "", Files.File_Types.Unknown_Icon);
      Check ("application/gzip", "info.kind.archive", "", Files.File_Types.Unknown_Icon);
      Check ("audio/mpeg", "info.kind.audio", "", Files.File_Types.Unknown_Icon);
      Check ("audio/wav", "info.kind.audio", "", Files.File_Types.Unknown_Icon);
      Check ("video/mp4", "info.kind.video", "", Files.File_Types.Unknown_Icon);
      Check ("application/octet-stream", "", "", Files.File_Types.Unknown_Icon);

      --  Filetypes they did not name: by family, else by extension.
      Check ("image/gif", "", "info.extra.image", Files.File_Types.Image_Icon);
      Check ("text/csv", "", "", Files.File_Types.Text_Icon);
      Check ("video/webm", "", "", Files.File_Types.Unknown_Icon);
      Check ("application/x-custom", "", "", Files.File_Types.Unknown_Icon);
      Check ("IMAGE/PNG", "", "", Files.File_Types.Unknown_Icon);
      Check ("", "", "", Files.File_Types.Unknown_Icon);

      --  An icon identifier naming a bundled icon is that icon, whatever the
      --  kind or filetype; otherwise a folder, link or program shows its kind.
      for Icon in Files.File_Types.Icon_Kind loop
         Assert
           (Files.File_Types.Resolve_Icon
              (Files.Types.Regular_File_Item, "application/octet-stream", Files.File_Types.Icon_Name (Icon)) = Icon,
            "the bundled identifier '" & Files.File_Types.Icon_Name (Icon) & "' is its own icon");
      end loop;
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Directory_Item, "inode/directory", "text")
         = Files.File_Types.Text_Icon,
         "a settings mapping to a bundled icon wins over the kind");
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Directory_Item, "inode/directory", "custom")
         = Files.File_Types.Folder_Icon,
         "a folder mapped to no bundled icon shows the folder");
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Symlink_Item, "image/png", "custom")
         = Files.File_Types.Link_Icon,
         "a link mapped to no bundled icon shows the link, not its filetype's");
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Executable_Item, "text/plain", "Folder")
         = Files.File_Types.Executable_Icon,
         "icon identifiers match exactly, and a program shows the program icon");
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Other_Item, "image/png", "custom")
         = Files.File_Types.Image_Icon,
         "any other item shows its filetype's icon");
      Assert
        (Files.File_Types.Resolve_Icon (Files.Types.Unknown_Item, "", "")
         = Files.File_Types.Unknown_Icon,
         "an item nothing is known about shows the unknown icon");

      --  The default settings' mappings, as loaded items carry them.
      declare
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;

         function Loaded (Kind : Files.Types.Item_Kind; Mime : String) return Files.File_Types.Icon_Kind is
           (Files.File_Types.Resolve_Icon (Kind, Mime, Files.File_Types.Icon_Id_For (Settings, Kind, Mime)));
      begin
         Assert (Loaded (Files.Types.Directory_Item, "inode/directory") = Files.File_Types.Folder_Icon,
                 "a loaded folder shows the folder icon");
         Assert (Loaded (Files.Types.Regular_File_Item, "text/x-ada") = Files.File_Types.Ada_Icon,
                 "Ada sources show the Ada icon by default");
         Assert (Loaded (Files.Types.Regular_File_Item, "text/markdown") = Files.File_Types.Text_Icon,
                 "Markdown shows the text icon by default");
         Assert (Loaded (Files.Types.Regular_File_Item, "image/png") = Files.File_Types.Image_Icon,
                 "PNG images show the image icon by default");
         Assert (Loaded (Files.Types.Regular_File_Item, "application/x-custom") = Files.File_Types.Unknown_Icon,
                 "an unmapped filetype shows the unknown icon");
      end;
   end Test_Filetype_Facts_Characterized;
