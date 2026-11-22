separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Check_Toggle is
   begin
      for Attempt in 1 .. 50 loop
         exit when Files.Model.Settings_Pane.Focused_Kind (Runtime.Model) = Guikit.Settings_Panel.Toggle;
         Press (Guikit.Input.Key_Tab);
      end loop;
      Expect (Files.Model.Settings_Pane.Focused_Kind (Runtime.Model) = Guikit.Settings_Panel.Toggle);
      declare
         Before : constant String := Files.Model.Settings_Pane.Focused_Value (Runtime.Model);
      begin
         Press (Guikit.Input.Key_Space, Typed => " ");
         Expect (Files.Model.Settings_Pane.Focused_Value (Runtime.Model) /= Before);
         --  The change applies without a save error: the smoke has no
         --  settings file, which turns persistence off rather than failing.
         Expect (Files.Model.Last_Error_Key (Runtime.Model) = "");
         Press (Guikit.Input.Key_Right);
         Expect (Files.Model.Settings_Pane.Focused_Value (Runtime.Model) = Before);

         Click_Toggle_Switch (Before);
         Activate_Toggle;
      end;
   end Check_Toggle;
