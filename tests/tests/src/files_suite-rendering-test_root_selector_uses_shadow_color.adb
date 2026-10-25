separate (Files_Suite.Rendering)
   --  The selector floats over file content.  Its two offset strips are a
   --  drop shadow, not an opaque second pane: using Pane_Color here produces
   --  a conspicuous solid ledge in the light theme.
   procedure Test_Root_Selector_Uses_Shadow_Color
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap         : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Shadow_Count : Natural := 0;
   begin
      Snap.Root_Selector_Open := True;
      Snap.Root_Selected_Index := 1;
      Snap.Root_Paths.Append (To_Unbounded_String ("/"));
      Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));

      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 480, 360, 20);
         Root   : constant Root_Selector_Layout := Calculate_Root_Selector_Layout (Snap, Layout, 20);
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snap, 480, 360, 20);
         Dismiss : constant Files.Events.Input_Action :=
           Files.Events.Translate_Click
             (Snap, Frame, X => 479, Y => 359, Width => 480, Height => 360, Line_Height => 20);
         A11y_Count : Natural := 0;
      begin
         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Shadow_Color then
               Shadow_Count := Shadow_Count + 1;
            end if;
         end loop;
         Assert
           (Dismiss.Kind = Files.Events.Command_Input_Action
            and then Dismiss.Command = Files.Commands.Close_Command_Palette_Command,
            "a click outside the root selector dismisses it without activating the background");
         for Node of Frame.Accessibility loop
            A11y_Count := A11y_Count + 1;
            Files_Suite.Support.Assert_Inside
              (Node.X, Node.Y, Node.Width, Node.Height, Root.X, Root.Y, Root.Width, Root.Height,
               "the root selector exposes no background accessibility nodes");
         end loop;
         Assert (A11y_Count > 1, "the root selector retains its list choices and close button");
      end;

      Files_Suite.Support.Assert_Equal

        (Shadow_Count,

         Shadow_Rectangles,

         "the root selector emits the shared banded translucent drop shadow");
   end Test_Root_Selector_Uses_Shadow_Color;
