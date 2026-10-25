separate (Files_Suite.Rendering)
   --  Menus float over the file view.  Use the same opaque overlay surface and
   --  translucent banded shadow as the root selector instead of rendering a
   --  flat pane that visually merges with the content beneath it.
   procedure Test_Floating_Menus_Have_Elevation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      declare
         Snap : View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);
      begin
         Snap.Context_Menu_Open := True;
         Snap.Context_Menu_Target := Files.Model.Context_Menu_Item;
         Snap.Context_Menu_X := 100;
         Snap.Context_Menu_Y := 100;

         declare
            Menu : constant Context_Menu_Layout :=
              Calculate_Context_Menu_Layout (Snap, Width, Height, LH);
            Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
            Shadow_Count : Natural := 0;
            Surface_Seen : Boolean := False;
            A11y_Count : Natural := 0;
         begin
            for Rect of Frame.Overlay_Rectangles loop
               if Rect.Color = Shadow_Color then
                  Shadow_Count := Shadow_Count + 1;
               elsif Rect.Color = Overlay_Color
                 and then Rect.X = Menu.X
                 and then Rect.Y = Menu.Y
                 and then Rect.Width = Menu.Width
                 and then Rect.Height = Menu.Height
               then
                  Surface_Seen := True;
               end if;
            end loop;
            Files_Suite.Support.Assert_Equal
              (Shadow_Count,
               Shadow_Rectangles,
               "the context menu uses the shared banded shadow");
            Assert (Surface_Seen, "the context menu uses the opaque overlay surface role");
            for Node of Frame.Accessibility loop
               A11y_Count := A11y_Count + 1;
               Files_Suite.Support.Assert_Inside
                 (Node.X, Node.Y, Node.Width, Node.Height, Menu.X, Menu.Y, Menu.Width, Menu.Height,
                  "the context menu exposes no background accessibility nodes");
            end loop;
            Assert (A11y_Count > 1, "the context menu retains its list and command choices");
         end;
      end;

      declare
         Snap : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      begin
         Snap.Sort_Menu_Open := True;
         declare
            Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
            Shadow_Count : Natural := 0;
            A11y_Count : Natural := 0;
            Dismiss : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snap, Frame, X => Width / 2, Y => 10,
                 Width => Width, Height => Height, Line_Height => LH);
         begin
            for Rect of Frame.Overlay_Rectangles loop
               if Rect.Color = Shadow_Color then
                  Shadow_Count := Shadow_Count + 1;
               end if;
            end loop;
            Files_Suite.Support.Assert_Equal
              (Shadow_Count,
               Shadow_Rectangles,
               "the sort menu uses the shared banded shadow");
            Assert
              (Dismiss.Kind = Files.Events.Command_Input_Action
               and then Dismiss.Command = Files.Commands.Close_Command_Palette_Command,
               "a click outside the sort menu dismisses it without activating the background");
            for Node of Frame.Accessibility loop
               A11y_Count := A11y_Count + 1;
               Assert
                 (Node.Role = Role_List or else Node.Role = Role_List_Item,
                  "the open sort menu exposes no background accessibility nodes");
            end loop;
            Files_Suite.Support.Assert_Equal (A11y_Count, 6, "the sort menu exposes its list and five sort choices");
         end;
      end;
   end Test_Floating_Menus_Have_Elevation;
