separate (Files_Suite.Interaction)
   procedure Test_Scrollbar_Drag_Begin (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Before   : Natural;
   begin
      --  A details list of many items overflows the main view so a draggable
      --  scrollbar thumb is laid out.
      for Index in 1 .. 60 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Main     : constant Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line);
         Action   : Files.Events.Input_Action;
         X, Y     : Natural;
      begin
         Assert (Main.Scrollbar_Visible, "the overflowing list lays out a scrollbar");
         X := Main.Scrollbar_X + Main.Scrollbar_Width / 2;
         Y := Main.Scrollbar_Thumb_Y + Main.Scrollbar_Height / 2;
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Scrollbar_Drag_Begin_Input_Action,
            "a click on the scrollbar thumb translates to a drag-begin action");
         Assert
           (Action.Scroll_Area = Files.Events.Scroll_Main_View,
            "the drag-begin action targets the main view");

         --  A track click pages only as far as the real end.  In particular,
         --  the fixed ten-line page size must not leave an oversized model
         --  offset that later consumes wheel input invisibly.
         declare
            Maximum : constant Natural :=
              1
              + (Main.Content_Height - Main.Scrollbar_Track_Height - 1) / Line;
            Near_End : constant Natural := Maximum - 5;
            Paged_Snapshot : Files.Rendering.View_Snapshot := Snapshot;
         begin
            Assert (Maximum > 5, "the scrollbar fixture has room for a near-end page click");
            Paged_Snapshot.Main_View_Scroll_Lines := Near_End;
            declare
               Paged_Frame : constant Files.Rendering.Frame_Commands :=
                 Files.Rendering.Build_Frame_Commands
                   (Paged_Snapshot, Window_W, Window_H, Line);
               Paged_Layout : constant Files.Rendering.Layout_Metrics :=
                 Files.Rendering.Calculate_Layout
                   (Paged_Snapshot, Window_W, Window_H, Line);
               Paged_Main : constant Files.Rendering.Main_View_Layout :=
                 Files.Rendering.Calculate_Main_View_Layout
                   (Paged_Snapshot, Paged_Layout, Line);
               Page_Action : constant Files.Events.Input_Action :=
                 Files.Events.Translate_Click
                   (Paged_Snapshot,
                    Paged_Frame,
                    Paged_Main.Scrollbar_X + Paged_Main.Scrollbar_Width / 2,
                    Paged_Main.Scrollbar_Y + Paged_Main.Scrollbar_Track_Height - 1,
                    Window_W,
                    Window_H,
                    Line_Height => Line);
            begin
               Assert
                 (Page_Action.Kind = Files.Events.Scroll_Input_Action
                  and then Page_Action.Scroll_Area = Files.Events.Scroll_Main_View,
                  "a click below the thumb translates to main-view paging");
               Files_Suite.Support.Assert_Equal
                 (Page_Action.Scroll_Lines,
                  5,
                  "a near-end track click is bounded to the five remaining lines");
            end;
         end;

         --  The reducer treats scrollbar-drag begin as a no-op: continuous drag
         --  state is owned by the GLFW shell, not the model (see the reducer
         --  comment). Applying it must therefore leave the model untouched.
         Before := Files.Model.Main_View_Scroll_Lines (Model);
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model),
            Before,
            "applying drag-begin leaves the main-view scroll offset to the shell");
         Assert
           (Result.Command = Files.Commands.No_Command and then not Result.Context_Menu_Changed,
            "the drag-begin reducer branch produces no command or menu effect");
      end;
   end Test_Scrollbar_Drag_Begin;
