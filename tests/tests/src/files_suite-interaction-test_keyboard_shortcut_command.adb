separate (Files_Suite.Interaction)
   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      --  Ctrl+3 is the Select_Details shortcut.
      Action   : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_3, Ctrl);
   begin
      Files_Suite.Support.Assert_Equal
        (Action.Kind,
         Files.Events.Command_Input_Action,
         "a known shortcut translates to a command input action");
      Files_Suite.Support.Assert_Equal
        (Action.Command,
         Files.Commands.Select_Details_Command,
         "Ctrl+3 selects the details-view command");

      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => Action,
         Current_Font_Size => Base_Font,
         Modifiers         => Ctrl,
         Result            => Result);

      Files_Suite.Support.Assert_Equal

        (Result.Command,

         Files.Commands.Select_Details_Command,

         "the result echoes the dispatched command id");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Types.Details,
         "dispatching the shortcut switches the model to the details view");
   end Test_Keyboard_Shortcut_Command;
