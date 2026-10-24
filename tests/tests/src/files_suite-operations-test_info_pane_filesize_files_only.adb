separate (Files_Suite.Operations)
   procedure Test_Info_Pane_Filesize_Files_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Snapshot : Files.Rendering.View_Snapshot;
      Frame    : Files.Rendering.Frame_Commands;

      --  Distinct rows a label occupies within the info pane.
      function Size_Label_Rows return Natural is
         Label : constant String := Files.Localization.Text ("info.size");
         Info_X : constant Natural := Frame.Layout.Main_Width;
         Rows  : Natural := 0;
         Last  : Integer := -1;
      begin
         for Text of Frame.Text loop
            if Text.X >= Info_X
              and then To_String (Text.Text) = Label
              and then Integer (Text.Y) /= Last
            then
               Rows := Rows + 1;
               Last := Integer (Text.Y);
            end if;
         end loop;
         return Rows;
      end Size_Label_Rows;
   begin
      Assert (Files.Localization.Text ("info.size", "en") = "Filesize",
              "the file-size label reads Filesize in the default catalog");

      --  Single folder: no Filesize field (it carries no byte size).
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "onlydir"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Size_Label_Rows = 0, "a single selected folder shows no Filesize field");

      --  All folders: the Filesize section is omitted.
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "d1"));
      Ada.Directories.Create_Path (Join (Root, "d2"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Files.Model.Selected_Count (Model) = 2, "two folders are selected");
      Assert (Size_Label_Rows = 0, "an all-folder selection shows no Filesize section");

      --  Mixed file + folder: the Filesize section appears (once) for the file.
      Reset_Root;
      Ada.Directories.Create_Path (Join (Root, "mixdir"));
      Write_File (Join (Root, "mixfile.txt"), "data");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Info_Pane (Model);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Frame := Files.Rendering.Build_Frame_Commands (Snapshot, Width => 800, Height => 1200, Line_Height => 20);
      Assert (Size_Label_Rows = 1, "a mixed selection shows the Filesize section for its file");
   end Test_Info_Pane_Filesize_Files_Only;
