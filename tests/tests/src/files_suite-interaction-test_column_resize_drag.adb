separate (Files_Suite.Interaction)
   procedure Test_Column_Resize_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Detail_Column;
      use type Files.Types.Sort_Field;

      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      for Index in 1 .. 8 loop
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
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Found    : Boolean := False;
         Sep_X    : Natural;
         Base_W   : Natural;
         Header_Y : Natural;
         Action   : Files.Events.Input_Action;
         Sort_Before : Files.Types.Sort_Field;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
               Found := True;
               exit;
            end if;
         end loop;
         Assert (Found, "the details list lays out a first data row");
         Sep_X    := Row.Size_X;
         Base_W   := Row.Size_Width;
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Assert (Base_W > Files.Types.Minimum_Detail_Column_Width,
                 "the sample size column starts above the minimum width");

         --  A press on the size column's left-edge separator translates to a
         --  resize-begin action carrying the target column, origin, and width.
         Action :=
           Files.Events.Translate_Click
             (Snapshot, Frame, Sep_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Column_Resize_Begin_Input_Action,
            "a press on a header separator begins a column resize");
         Files_Suite.Support.Assert_Equal
           (Files.Types.Detail_Column'Val (Action.Item_Index),
            Files.Types.Size_Column,
            "the resize targets the column whose left edge was pressed");
         Assert (Action.Cursor_Position = Sep_X and then Action.Scroll_Drag_Anchor = Base_W,
                 "the drag-begin action carries the separator origin and column width");

         --  Applying the begin action must not change the sort field: the
         --  separator suppresses the header cell's sort click behind it.
         Sort_Before := Files.Model.Sort_Field_Of (Model);
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Sort_Field_Of (Model),
            Sort_Before,
            "pressing a separator does not change the sort field");

         --  Dragging the separator left by 40 px widens the size column by ~40.
         Files.Interaction.Apply_Column_Resize
           (Settings, Files.Types.Size_Column,
            Origin_X     => Action.Cursor_Position,
            Origin_Width => Action.Scroll_Drag_Anchor,
            Current_X    => Sep_X - 40,
            Result       => Result);
         Assert (Result.Settings_Changed, "the resize step reports a width change");
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            Base_W + 40,
            "dragging the separator left widens the persisted column width by the drag distance");

         --  The details layout reflects the new width on the next snapshot.
         declare
            After_Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            After_Layout   : constant Files.Rendering.Layout_Metrics :=
              Files.Rendering.Calculate_Layout (After_Snapshot, Window_W, Window_H, Line);
            After_Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
              Files.Rendering.Calculate_Item_Layout (After_Snapshot, After_Layout, Line);
         begin
            for Cell of After_Rows loop
               if Cell.Visible_Index = 1 then
                  Files_Suite.Support.Assert_Equal
                    (Cell.Size_Width,
                     Base_W + 40,
                     "the details layout reflects the resized column width");
                  exit;
               end if;
            end loop;
         end;

         --  A far rightward drag (raw width below the minimum) clamps up to it.
         Files.Interaction.Apply_Column_Resize
           (Settings, Files.Types.Size_Column,
            Origin_X     => Action.Cursor_Position,
            Origin_Width => Action.Scroll_Drag_Anchor,
            Current_X    => Sep_X + (Base_W - 10),
            Result       => Result);
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            Files.Types.Minimum_Detail_Column_Width,
            "a drag that shrinks the column past the minimum clamps up to it");

         --  The public reducer must clamp extreme synthetic coordinates rather
         --  than overflowing before the ordinary width rules can run.
         Files.Interaction.Apply_Column_Resize
           (Settings, Files.Types.Size_Column,
            Origin_X     => Integer'Last,
            Origin_Width => Natural'Last,
            Current_X    => Integer'First,
            Result       => Result);
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            Natural'Last,
            "an overflowing positive resize delta saturates at Natural'Last");
         Files.Interaction.Apply_Column_Resize
           (Settings, Files.Types.Size_Column,
            Origin_X     => Integer'First,
            Origin_Width => 0,
            Current_X    => Integer'Last,
            Result       => Result);
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Widths (Files.Types.Size_Column),
            0,
            "an overflowing negative resize delta clamps to the default width");
      end;
   end Test_Column_Resize_Drag;
