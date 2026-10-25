separate (Files_Suite.Rendering)
   --  Folder-tree destination picker: the Choose/Cancel button bar. Covers the
   --  Tree_Pick_Active render + hit-test path, which no other test exercises.
   procedure Test_Tree_Pick_Buttons_Hit_Test (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap       : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout     : Guikit.Draw.Layout_Metrics;
      Panel      : Tree_Panel_Layout;
      Buttons    : Tree_Pick_Button_Layout;
      Frame      : Frame_Commands;
      Choose_Hit : Files.Events.Input_Action;
      Cancel_Hit : Files.Events.Input_Action;
      Outside_Hit : Files.Events.Input_Action;
      Backdrop_Seen : Boolean := False;
      A11y_Count : Natural := 0;
   begin
      Snap.Tree_Panel_Open  := True;
      Snap.Tree_Pick_Active := True;
      Layout  := Calculate_Layout (Snap, Width, Height, LH);
      Panel   := Calculate_Tree_Panel_Layout (Snap, Layout, LH);
      Buttons := Tree_Pick_Buttons (Panel, LH);
      Frame   := Build_Frame_Commands (Snap, Width, Height, LH);

      Assert (Buttons.Visible, "the active tree destination picker shows a Choose/Cancel bar");
      Assert
        (Buttons.Button_Width > 0 and then Buttons.Height > 0,
         "the pick buttons have a non-empty click area");
      Assert (Buttons.Choose_X < Buttons.Cancel_X, "Choose sits left of Cancel");
      Assert
        (Buttons.Choose_X + Buttons.Button_Width <= Buttons.Cancel_X,
         "the Choose and Cancel buttons do not overlap");
      Assert
        (Buttons.Choose_X >= Panel.X
           and then Buttons.Cancel_X + Buttons.Button_Width <= Panel.X + Panel.Width,
         "both pick buttons sit within the tree panel");

      --  Each button center is hit-testable and routes to the right action.
      Choose_Hit :=
        Files.Events.Translate_Click
          (Snap, Frame,
           X      => Buttons.Choose_X + Buttons.Button_Width / 2,
           Y      => Buttons.Y + Buttons.Height / 2,
           Width  => Width,
           Height => Height);
      Cancel_Hit :=
        Files.Events.Translate_Click
          (Snap, Frame,
           X      => Buttons.Cancel_X + Buttons.Button_Width / 2,
           Y      => Buttons.Y + Buttons.Height / 2,
           Width  => Width,
           Height => Height);
      Outside_Hit :=
        Files.Events.Translate_Click
          (Snap, Frame,
           X      => Panel.X + Panel.Width + 20,
           Y      => Panel.Y + 20,
           Width  => Width,
           Height => Height);
      Files_Suite.Support.Assert_Equal
        (Choose_Hit.Kind,
         Files.Events.Tree_Pick_Confirm_Input_Action,
         "clicking Choose confirms the destination pick");
      Assert
        (Cancel_Hit.Kind = Files.Events.Command_Input_Action
           and then Cancel_Hit.Command = Files.Commands.Toggle_Folder_Tree_Command,
         "clicking Cancel closes the picker");
      Files_Suite.Support.Assert_Equal
        (Outside_Hit.Kind,
         Files.Events.No_Input_Action,
         "a destination-picker click outside the tree cannot activate the background");

      for Rect of Frame.Overlay_Rectangles loop
         if Rect.Color = Modal_Backdrop_Color
           and then Rect.X = 0
           and then Rect.Y = 0
           and then Rect.Width = Width
           and then Rect.Height = Height
         then
            Backdrop_Seen := True;
         end if;
      end loop;
      Assert (Backdrop_Seen, "the modal destination picker dims the inactive file view");

      for Node of Frame.Accessibility loop
         A11y_Count := A11y_Count + 1;
         Files_Suite.Support.Assert_Inside
           (Node.X, Node.Y, Node.Width, Node.Height, Panel.X, Panel.Y, Panel.Width, Panel.Height,
            "the modal destination picker exposes no background accessibility nodes");
      end loop;
      Assert
        (A11y_Count >= 3,
         "the destination picker retains its tree and Choose/Cancel accessibility nodes");
   end Test_Tree_Pick_Buttons_Hit_Test;
