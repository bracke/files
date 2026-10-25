separate (Files_Suite.Model)
   procedure Test_Root_Selector_Eject_And_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/tmp/example-mount"),
            Label => To_Unbounded_String ("root.mount|example-mount|ext4"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("example-mount"),
            Ready => Files.File_System.Root_Ready,
            Removable => True));
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Eject_Selected_Root_Command, Model),
         "eject command is enabled for removable roots");
      Result := Files.Controller.Execute_Command (Files.Commands.Eject_Selected_Root_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Eject_Selected_Root_Command,
         "eject command reports command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Failed,
         "eject command reports unavailable native operation");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Error_Key),
         "error.root.eject_unavailable",
         "eject command reports localized unavailable error");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Operation.Path),
         "/tmp/example-mount",
         "eject command reports selected root path");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String (Target),
            Label => To_Unbounded_String ("root.mount|selected-root"),
            Kind  => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("selected-root"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      Files.Model.Open_Root_Selector (Model, Entries);
      Assert
        (not Files.Commands.Is_Enabled (Files.Commands.Eject_Selected_Root_Command, Model),
         "eject command is disabled for non-removable roots");
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Selected_Root_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Selected_Root_Command,
         "root-open command reports root activation command");
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root-open command navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "root-open loads selected root");

      --  Chosen from the palette, opened over the selector, it opens too.
      Files.Model.Navigate_To (Model, Root, Files.File_System.Item_Vectors.Empty_Vector);
      Files.Model.Open_Root_Selector (Model, Entries);
      Files.Model.Open_Command_Palette (Model);
      Result := Files.Controller.Execute_Command (Files.Commands.Open_Selected_Root_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Operation.Status,
         Files.Operations.Operation_Navigated,
         "root-open from the palette over the selector navigates");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Target),
         "root-open from the palette loads the selected root");
   end Test_Root_Selector_Eject_And_Open;
