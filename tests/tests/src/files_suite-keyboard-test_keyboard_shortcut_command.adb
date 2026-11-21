with Files.Preference_Types;
with Files.Input_Actions;
with Files_Suite.Support.Models;
separate (Files_Suite.Keyboard)
   procedure Test_Keyboard_Shortcut_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      --  Ctrl+3 is the Select_Details shortcut.
      Action   : constant Files.Input_Actions.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_3, Ctrl);
   begin
      Files_Suite.Support.Assert_Equal
        (Action.Kind,
         Files.Input_Actions.Command_Input_Action,
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
         Modifiers         => Ctrl,
         Result            => Result);

      Files_Suite.Support.Assert_Equal

        (Result.Command,

         Files.Commands.Select_Details_Command,

         "the result echoes the dispatched command id");
      Files_Suite.Support.Assert_Equal
        (Files.Model.View_Mode_Of (Model),
         Files.Preference_Types.Details,
         "dispatching the shortcut switches the model to the details view");
   end Test_Keyboard_Shortcut_Command;
