with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  After the session's Stop, a window that still draws or closes does not
   --  register the application with the screen reader again.
   procedure Test_A11y_Stop_Is_Final (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame  : constant Frame_Commands := Build_Frame_Commands
        (Sample_Snapshot (2, Files.Preference_Types.Small_Icons), Width => 800, Height => 600, Line_Height => 20);
      Window : constant Files.Application.Accessibility.Window_Key := Files.Application.Accessibility.New_Window_Key;
   begin
      Files.Application.Accessibility.Stop;
      Assert (Files.Application.Accessibility.Testing.Published_Windows = 0, "Stop forgets every window");
      Files.Application.Accessibility.Publish (Window, Frame);
      Assert (Files.Application.Accessibility.Testing.Published_Windows = 0,
              "a frame drawn after Stop is not published");
      Files.Application.Accessibility.Set_Active (Window);
      Files.Application.Accessibility.Forget (Window);
      Assert (Files.Application.Accessibility.Testing.Published_Windows = 0,
              "closing a window after Stop publishes nothing");
   end Test_A11y_Stop_Is_Final;
