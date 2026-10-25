separate (Files_Suite.Interaction)
   procedure Test_Overlays_Contain_Wheel_Input (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Main_Y   : Natural;

      procedure Assert_Overlay_Swallows_Scroll
        (Snapshot : Files.Rendering.View_Snapshot;
         Name     : String)
      is
         Action : constant Files.Events.Input_Action :=
           Files.Events.Translate_Scroll_At
             (Snapshot, Target_W - 1, Main_Y, Target_W, Target_H,
              Y_Offset => -1, Line_Height => Line);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.No_Input_Action,
            Name & " swallows wheel input instead of scrolling the view behind it");
      end Assert_Overlay_Swallows_Scroll;
   begin
      Replay_Targeted_Scroll (Model, Settings);
      Main_Y := Targeted_Main_Y (Model, Settings);

      --  Every non-scrolling pointer overlay must contain wheel input.  These
      --  flags are tested directly on the rendering snapshot so each overlay's
      --  translation contract is covered without depending on how it is opened.
      declare
         Base : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Overlay : Files.Rendering.View_Snapshot;
      begin
         Overlay := Base;
         Overlay.Sort_Menu_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the sort menu");

         Overlay := Base;
         Overlay.Context_Menu_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the context menu");

         Overlay := Base;
         Overlay.Tree_Panel_Open := True;
         Overlay.Tree_Rows.Clear;
         for Index in 1 .. 40 loop
            Overlay.Tree_Rows.Append
              (Files.Folder_Tree.Visible_Row'
                 (Node_Index   => Index,
                  Path         => Ada.Strings.Unbounded.To_Unbounded_String
                    ("/tree/" & Natural'Image (Index)),
                  Name         => Ada.Strings.Unbounded.To_Unbounded_String
                    ("row" & Natural'Image (Index)),
                  Depth        => 0,
                  Expanded     => False,
                  Loaded       => True,
                  Has_Children => False));
         end loop;
         declare
            Tree_Layout : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Overlay, Target_W, Target_H, Line);
            Tree : constant Files.Rendering.Tree_Panel_Layout :=
              Files.Rendering.Calculate_Tree_Panel_Layout
                (Overlay, Tree_Layout, Line);
            Tree_Frame : constant Files.Rendering.Frame_Commands :=
              Files.Rendering.Build_Frame_Commands
                (Overlay, Target_W, Target_H, Line);
            Capacity : constant Natural :=
              Files.Rendering.Tree_Row_Capacity (Overlay, Tree);
            Maximum : constant Natural :=
              (if Natural (Overlay.Tree_Rows.Length) > Capacity
               then Natural (Overlay.Tree_Rows.Length) - Capacity
               else 0);
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Scroll_At
                (Overlay,
                 Tree.X + Tree.Width / 2,
                 Tree.Y + Tree.Height / 2,
                 Target_W, Target_H, Y_Offset => -1, Line_Height => Line);
            Drag_Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Overlay, Tree_Frame,
                 Tree.Scrollbar_X + Tree.Scrollbar_Width / 2,
                 Tree.Scrollbar_Thumb_Y + Tree.Scrollbar_Height / 2,
                 Target_W, Target_H, Line_Height => Line);
         begin
            Assert
              (Action.Kind = Files.Events.Scroll_Input_Action
               and then Action.Scroll_Area = Files.Events.Scroll_Tree_Panel,
               "wheel input over the folder tree targets the tree rather than the main view");
            Assert
              (Tree.Scrollbar_Visible,
               "the long folder tree exposes a draggable tree scrollbar thumb (scrollbar visible)");
            Files_Suite.Support.Assert_Equal
              (Drag_Action.Kind, Files.Events.Scrollbar_Drag_Begin_Input_Action,
               "the long folder tree exposes a draggable tree scrollbar thumb (action kind)");
            Assert
              (Drag_Action.Scroll_Area = Files.Events.Scroll_Tree_Panel,
               "the long folder tree exposes a draggable tree scrollbar thumb (scroll area)");

            if Maximum > 1 then
               declare
                  Near_End : constant Natural := Maximum / 2;
                  Expected : constant Natural :=
                    Natural'Min (Capacity, Maximum - Near_End);
               begin
                  Overlay.Tree_Panel_Scroll_Rows := Near_End;
                  declare
                     Paged_Tree : constant Files.Rendering.Tree_Panel_Layout :=
                       Files.Rendering.Calculate_Tree_Panel_Layout
                         (Overlay, Tree_Layout, Line);
                     Paged_Frame : constant Files.Rendering.Frame_Commands :=
                       Files.Rendering.Build_Frame_Commands
                         (Overlay, Target_W, Target_H, Line);
                     Page_Action : constant Files.Events.Input_Action :=
                       Files.Events.Translate_Click
                         (Overlay, Paged_Frame,
                          Paged_Tree.Scrollbar_X + Paged_Tree.Scrollbar_Width / 2,
                          Paged_Tree.Scrollbar_Y
                            + Paged_Tree.Scrollbar_Track_Height - 1,
                          Target_W, Target_H, Line_Height => Line);
                  begin
                     Files_Suite.Support.Assert_Equal
                       (Page_Action.Kind, Files.Events.Scroll_Input_Action,
                        "tree track paging clamps its delta at the final full page (action kind)");
                     Assert
                       (Page_Action.Scroll_Area = Files.Events.Scroll_Tree_Panel,
                        "tree track paging clamps its delta at the final full page (scroll area)");
                     Files_Suite.Support.Assert_Equal
                       (Page_Action.Scroll_Lines, Integer (Expected),
                        "tree track paging clamps its delta at the final full page (scroll lines)");
                  end;
               end;
            end if;

            Overlay.Tree_Panel_Scroll_Rows := Maximum;
            declare
               End_Action : constant Files.Events.Input_Action :=
                 Files.Events.Translate_Scroll_At
                   (Overlay,
                    Tree.X + Tree.Width / 2,
                    Tree.Y + Tree.Height / 2,
                    Target_W, Target_H, Y_Offset => -1, Line_Height => Line);
            begin
               Files_Suite.Support.Assert_Equal
                 (End_Action.Kind,
                  Files.Events.No_Input_Action,
                  "wheel input at the final full tree page does not accumulate an invisible offset");
            end;
            Overlay.Tree_Panel_Scroll_Rows := 0;
         end;

         Overlay.Tree_Pick_Active := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the destination picker");
         declare
            Tree_Layout : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout
                (Overlay, Target_W, Target_H, Line);
            Tree : constant Files.Rendering.Tree_Panel_Layout :=
              Files.Rendering.Calculate_Tree_Panel_Layout
                (Overlay, Tree_Layout, Line);
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Scroll_At
                (Overlay,
                 Tree.X + Tree.Width / 2,
                 Tree.Y + Tree.Height / 2,
                 Target_W, Target_H, Y_Offset => -1, Line_Height => Line);
         begin
            Assert
              (Action.Kind = Files.Events.Scroll_Input_Action
               and then Action.Scroll_Area = Files.Events.Scroll_Tree_Panel,
               "the modal destination picker still scrolls inside its tree");
         end;

         Overlay := Base;
         Overlay.Paste_Conflict_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the paste-conflict dialog");

         Overlay := Base;
         Overlay.Paste_Progress_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the paste-progress dialog");

         Overlay := Base;
         Overlay.Quick_Look_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "Quick Look");

         Overlay := Base;
         Overlay.Label_Picker_Open := True;
         Assert_Overlay_Swallows_Scroll (Overlay, "the label picker");
      end;
   end Test_Overlays_Contain_Wheel_Input;
