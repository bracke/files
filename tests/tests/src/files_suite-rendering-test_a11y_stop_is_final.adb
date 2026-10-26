separate (Files_Suite.Rendering)
   --  After the session's Stop, a window that still draws or closes does not
   --  register the application with the screen reader again.
   procedure Test_A11y_Stop_Is_Final (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Frame  : constant Frame_Commands := Build_Frame_Commands
        (Sample_Snapshot (2, Files.Types.Small_Icons), Width => 800, Height => 600, Line_Height => 20);
      Window : constant Files.Accessibility.Window_Key := Files.Accessibility.New_Window_Key;
   begin
      Files.Accessibility.Stop;
      Assert (Files.Accessibility.Published_Windows = 0, "Stop forgets every window");
      Files.Accessibility.Publish (Window, Frame);
      Assert (Files.Accessibility.Published_Windows = 0, "a frame drawn after Stop is not published");
      Files.Accessibility.Set_Active (Window);
      Files.Accessibility.Forget (Window);
      Assert (Files.Accessibility.Published_Windows = 0, "closing a window after Stop publishes nothing");
   end Test_A11y_Stop_Is_Final;
