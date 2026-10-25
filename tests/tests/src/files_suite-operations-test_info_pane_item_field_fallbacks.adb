separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Item_Field_Fallbacks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;
   begin
      Reset_Root;
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
   end Test_Info_Pane_Item_Field_Fallbacks;
