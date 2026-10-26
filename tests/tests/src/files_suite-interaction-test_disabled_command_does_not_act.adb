with Files.Commands.Status;
separate (Files_Suite.Interaction)
   procedure Test_Disabled_Command_Does_Not_Act (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "disabled-noop");
      Extract  : constant String := Files_Suite.Support.Join (Dir, "report");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "report.txt"), "payload");
      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");

      --  Extract is disabled on a plain-file selection. Dispatching it through the
      --  real menu seam must be gated by Execute_Command (Is_Enabled) and act on
      --  nothing.
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled for the plain-file selection");
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
      Assert (Found, "the disabled command is still offered by the menu");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Extract_Archive_Command,
         "the result echoes the dispatched command id");
      Assert (not Result.Command_Executed,
              "the disabled command does not report execution");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "the gated dispatch returns an ignored controller status");
      Assert (not Ada.Directories.Exists (Extract),
              "the disabled extract command creates no folder");
   end Test_Disabled_Command_Does_Not_Act;
