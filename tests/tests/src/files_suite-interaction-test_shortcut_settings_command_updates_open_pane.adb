separate (Files_Suite.Interaction)
   --  A settings command run by its shortcut, with the settings pane open,
   --  updates the pane as a click does, so the pane's next save keeps it.
   procedure Test_Shortcut_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the override this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
   begin
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Toggle_Hidden_Files_Command, (True, Guikit.Input.Key_H, Ctrl));
      Files.Interaction.Execute_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Toggle_Settings_Pane_Command,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "the settings pane is open");
      Files.Interaction.Handle_Key
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Key               => Guikit.Input.Key_H,
         Modifiers         => Ctrl,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Settings.Show_Hidden_Files, "the shortcut turns hidden files on");
      Files_Suite.Support.Assert_Equal
        (Ada.Strings.Unbounded.To_String
           (Files.Model.Settings_Draft_Of (Model).Scalars (Files.Settings.Show_Hidden_Files_Setting)),
         "true",
         "the open pane shows the shortcut's change");
   end Test_Shortcut_Settings_Command_Updates_Open_Pane;
