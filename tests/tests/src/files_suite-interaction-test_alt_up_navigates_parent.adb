separate (Files_Suite.Interaction)
   procedure Test_Alt_Up_Navigates_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Guikit.Input.Navigation_Direction;
      Parent_Action : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_Up, Alt);
      Plain_Action  : constant Files.Events.Input_Action :=
        Files.Events.Translate_Key (Guikit.Input.Key_Up, Guikit.Input.No_Modifiers);
   begin
      --  Alt+Up is a modifier-specific shortcut, so it routes to the command.
      Files_Suite.Support.Assert_Equal
        (Parent_Action.Kind,
         Files.Events.Command_Input_Action,
         "alt+up translates to a command input action");
      Files_Suite.Support.Assert_Equal
        (Parent_Action.Command,
         Files.Commands.Navigate_Parent_Command,
         "alt+up dispatches the navigate-parent command");

      --  Plain Up is left for grid navigation so the selection still moves.
      Files_Suite.Support.Assert_Equal
        (Plain_Action.Kind,
         Files.Events.Selection_Input_Action,
         "plain up stays a selection movement action");
      Assert
        (Plain_Action.Direction = Guikit.Input.Move_Up,
         "plain up still moves the selection up in the grid");
   end Test_Alt_Up_Navigates_Parent;
