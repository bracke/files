with Ada.Real_Time;
with Files.Window_Policy;
with Guikit.Settings_Panel;

separate (Files_Suite.Interaction)
   --  The window layer's decisions, without a window: which held keys
   --  repeat, the framebuffer ratio and the text size it gives, what an
   --  assistive technology's request does, and when a wheel zoom is saved.
   procedure Test_Window_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package P renames Files.Window_Policy;
      use type Ada.Real_Time.Time;
      Now : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Sort_By_Size : constant Files.Commands.Command_Id := Files.Commands.Sort_Command (Files.Types.Sort_Size);
   begin
      Assert (P.Key_Repeats (Guikit.Input.Key_Down) and then P.Key_Repeats (Guikit.Input.Key_Backspace)
              and then P.Key_Repeats (Guikit.Input.Key_Equal),
              "moving, deleting and zooming keys repeat");
      Assert (not P.Key_Repeats (Guikit.Input.Key_Return) and then not P.Key_Repeats (Guikit.Input.Key_Space)
              and then not P.Key_Repeats (Guikit.Input.Key_A),
              "a held Enter, Space or letter acts once");

      Assert (P.Pixel_Ratio (1600, 800, 1.0) = 2.0, "a 2x framebuffer is ratio 2");
      Assert (P.Pixel_Ratio (400, 800, 2.0) = 1.0, "never below 1");
      Assert (P.Pixel_Ratio (16_000, 800, 1.0) = 8.0, "never above 8");
      Assert (P.Pixel_Ratio (1600, 0, 1.5) = 1.5, "an unknown window size keeps the ratio in use");
      Files_Suite.Support.Assert_Equal (P.Scaled_Font_Size (16, 2.0), 32, "text is drawn at the ratio");
      Files_Suite.Support.Assert_Equal (P.Scaled_Font_Size (16, 1.25), 20, "a fractional scale too");

      declare
         Item   : constant Files.Events.Input_Action :=
           (Kind => Files.Events.Item_Click_Input_Action, Item_Index => 3, others => <>);
         Header : constant Files.Events.Input_Action :=
           (Kind => Files.Events.Column_Reorder_Begin_Input_Action, Sort_Command => Sort_By_Size, others => <>);
         Fixed  : constant Files.Events.Input_Action :=
           (Kind => Files.Events.Column_Reorder_Begin_Input_Action, others => <>);
         Opened : constant Files.Events.Input_Action := P.Accessibility_Action (Item, Activate => True);
         Picked : constant Files.Events.Input_Action := P.Accessibility_Action (Item, Activate => False);
         Sorted : constant Files.Events.Input_Action := P.Accessibility_Action (Header, Activate => True);
      begin
         Assert (Opened.Kind = Files.Events.Item_Click_Input_Action and then Opened.Activate,
                 "Activate on an item opens it, as a double-click does");
         Assert (not Picked.Activate, "Select or Focus only selects it");
         Assert (Sorted.Kind = Files.Events.Command_Input_Action and then Sorted.Command = Sort_By_Size,
                 "a header cell sorts by its column instead of arming a drag");
         Assert (P.Accessibility_Action (Fixed, Activate => True).Kind = Files.Events.No_Input_Action,
                 "a header that does not sort does nothing");
      end;

      Assert (P.Activation_Presses_Space (True, Files.Types.Focus_Settings_Input, Guikit.Settings_Panel.Toggle),
              "activating a focused toggle presses Space");
      Assert (not P.Activation_Presses_Space (False, Files.Types.Focus_Settings_Input, Guikit.Settings_Panel.Toggle),
              "selecting it does not");
      Assert (not P.Activation_Presses_Space (True, Files.Types.Focus_None, Guikit.Settings_Panel.Toggle),
              "nor does activating anything else");

      Assert (not P.Zoom_Save_Due (True, False, Now, Now), "a zoom still moving is not saved");
      Assert (P.Zoom_Save_Due (True, False, Now + P.Zoom_Save_Delay, Now), "it is once the wheel has rested");
      Assert (P.Zoom_Save_Due (True, True, Now, Now), "or at once when a window closes");
      Assert (not P.Zoom_Save_Due (False, True, Now, Now), "and never when nothing is unsaved");
   end Test_Window_Policy;
