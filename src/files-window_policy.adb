with Files.Commands;
with Files.Timing;

package body Files.Window_Policy is

   use type Files.Commands.Command_Id;
   use type Files.Events.Input_Action_Kind;
   use type Files.Types.Focus_Target;

   function Accessibility_Action
     (Click    : Files.Events.Input_Action;
      Activate : Boolean)
      return Files.Events.Input_Action
   is
      Action : Files.Events.Input_Action := Click;
   begin
      if Activate and then Action.Kind = Files.Events.Item_Click_Input_Action then
         Action.Activate := True;
      elsif Action.Kind = Files.Events.Column_Reorder_Begin_Input_Action then
         Action :=
           (if Action.Sort_Command /= Files.Commands.No_Command
            then (Kind => Files.Events.Command_Input_Action, Command => Action.Sort_Command)
            else (Kind => Files.Events.No_Input_Action));
      end if;
      return Action;
   end Accessibility_Action;

   function Activation_Presses_Space
     (Activate : Boolean;
      Focus    : Files.Types.Focus_Target;
      Field    : Guikit.Settings_Panel.Field_Kind)
      return Boolean is
     (Activate
      and then Focus = Files.Types.Focus_Settings_Input
      and then Field in Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice);

   function Zoom_Save_Due
     (Unsaved   : Boolean;
      Force     : Boolean;
      Now       : Ada.Real_Time.Time;
      Zoomed_At : Ada.Real_Time.Time)
      return Boolean is
     (Unsaved and then (Force or else Files.Timing.Elapsed (Now, Zoomed_At, Zoom_Save_Delay)));

end Files.Window_Policy;
