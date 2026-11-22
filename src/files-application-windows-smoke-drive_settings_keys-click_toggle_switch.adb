separate (Files.Application.Windows.Smoke.Drive_Settings_Keys)
   procedure Click_Toggle_Switch (Before : String) is
      --  The nodes of the frame shown, the settings pane merged in
      --  (Shown_Frame, as the pane is open). A copy: each click
      --  re-renders, which replaces the shown frame.
      Shown   : constant Guikit.Draw.Accessibility_Node_Vectors.Vector := Runtime.Shown_Frame.Accessibility;
      Flipped : Boolean := False;
   begin
      for Node of Shown loop
         if Node.Focused and then Node.Width > 0 then
            --  Clicks hit-test the last drawn layout, so no frame is
            --  drawn between them; 4 px steps cannot miss a switch.
            for Step in 0 .. Node.Width / 4 loop
               exit when Node.Width < 4 * Step + 1;
               Click_At (Node.X + Node.Width - 1 - 4 * Step, Node.Y + Node.Height / 2);
               Flipped := Files.Model.Settings_Pane.Focused_Value (Runtime.Model) /= Before;
               exit when Flipped;
            end loop;
            Render_Window (Runtime);
            exit;
         end if;
      end loop;
      Expect (Flipped);
   end Click_Toggle_Switch;
