separate (Files.Commands.Status.Status_Of)
   function Overlay_Status (Command : Overlay_Command) return Command_Status is
   begin
      case Command is
         when Close_Overlay_Command =>
            --  Nothing open to close: Escape just does nothing.
            return Require (Files.Model.Has_Something_To_Close (Model));
         when Open_Selected_Root_Command =>
            return Require (Valid_Root_Selected, Root_Unselected_Reason);
         when Eject_Selected_Root_Command =>
            return
              All_Of
                (Require (Valid_Root_Selected, Root_Unselected_Reason),
                 Require
                   (Valid_Root_Selected
                    and then Files.Model.Root_Selector.Is_Removable
                      (Model, Files.Model.Root_Selector.Selected_Index (Model)),
                    Eject_Unavailable_Reason));
         when Clear_Filter_Command =>
            return Require (Files.Model.Filtering.Filter_Text (Model) /= "", Filter_Empty_Reason);
         when Search_Recursive_Command | Search_Contents_Command =>
            return
              All_Of
                (Require (Files.Model.Filtering.Filter_Text (Model) /= "", Filter_Empty_Reason),
                 Not_Recent_View, Has_Directory);
         when Save_Settings_Command
            | Reset_Settings_Command =>
            return Require (Files.Model.Settings_Pane.Is_Open (Model), Settings_Closed_Reason);
      end case;
   end Overlay_Status;
