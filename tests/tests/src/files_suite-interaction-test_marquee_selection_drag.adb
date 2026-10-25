separate (Files_Suite.Interaction)
   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      --  A small details list leaves ample empty space below the rows and lays
      --  out no scrollbar, so an empty-grid press is unambiguous.
      for Index in 1 .. 6 loop
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
         Cells    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Cell_1   : constant Files.Rendering.Item_Layout := Cells.Element (1);
         Cell_2   : constant Files.Rendering.Item_Layout := Cells.Element (2);
         Bottom_Y : constant Natural :=
           Cells.Element (Cells.Last_Index).Y
           + Cells.Element (Cells.Last_Index).Height + 20;
         Empty_X  : constant Natural := Layout.Main_X + 10;

         --  The rectangle a drag from item 1's cell to item 2's cell describes.
         Rect_X, Rect_Y, Rect_W, Rect_H : Natural;
         Empty    : Files.Rendering.Visible_Index_Vectors.Vector;
         Hits     : Files.Rendering.Visible_Index_Vectors.Vector;
         Base     : Files.Rendering.Visible_Index_Vectors.Vector;
         X, Y     : Natural;
         Found    : Boolean;
      begin
         Assert (Bottom_Y < Layout.Main_Y + Layout.Main_Height,
                 "the six-row list leaves empty grid space below the last row");

         --  Details rows share an X, so span a nonzero width across rows 1..2.
         Files.Rendering.Marquee_Rect
           (Start_X   => Cell_1.X + 5,
            Start_Y   => Cell_1.Y + Cell_1.Height / 2,
            Current_X => Cell_1.X + 15,
            Current_Y => Cell_2.Y + Cell_2.Height / 2,
            X         => Rect_X,
            Y         => Rect_Y,
            Width     => Rect_W,
            Height    => Rect_H);
         Hits := Files.Rendering.Hit.Items_In_Rect (Cells, Rect_X, Rect_Y, Rect_W, Rect_H);

         --  Precedence: a press on empty grid space begins a marquee rather than
         --  clearing or ignoring, and it is not additive without a modifier.
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
            Additive : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Modifiers => Ctrl, Line_Height => Line);
         begin
            Files_Suite.Support.Assert_Equal
              (Action.Kind,
               Files.Events.Marquee_Begin_Input_Action,
               "an empty-space press begins a marquee");
            Assert (not Action.Toggle_Selection,
                    "a plain empty-space marquee is not additive");
            Assert (Additive.Kind = Files.Events.Marquee_Begin_Input_Action
                    and then Additive.Toggle_Selection,
                    "a Ctrl empty-space press begins an additive marquee");
         end;

         --  Precedence: a press ON an item is a normal click, not a marquee; a
         --  press on the details header is a header action, not a marquee.
         Item_Center (Model, 1, X, Y, Found);
         Assert (Found, "a layout cell exists for the target item");
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         begin
            Files_Suite.Support.Assert_Equal
              (Action.Kind,
               Files.Events.Item_Click_Input_Action,
               "a press on an item stays a normal item click, not a marquee");
         end;
         declare
            Header_X : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
            Header_Y : constant Natural :=
              (if Cell_1.Y > Line then Cell_1.Y - Line / 2 else Cell_1.Y);
            Header   : constant Files.Rendering.Detail_Header_Cell :=
              Files.Rendering.Hit.Details_Header_Cell_At (Snapshot, Layout, Header_X, Header_Y, Line);
            Action   : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Header_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         begin
            Assert (Header.Present, "the details header spans the probed point");
            Assert (Action.Kind /= Files.Events.Marquee_Begin_Input_Action,
                    "a press on the details header does not begin a marquee");
         end;

         --  An empty-space marquee begin is a shell-owned no-op in the reducer:
         --  applying it must not disturb a prior selection (it is not a clear).
         Files.Model.Select_Visible (Model, 5);
         Assert (Files.Model.Is_Selected (Model, 5), "item 5 is selected before the marquee begins");
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
         end;
         Assert (Files.Model.Is_Selected (Model, 5),
                 "beginning a marquee leaves the prior selection to the shell (no clear)");

         --  Dragging over items 1 and 2 (non-additive) selects exactly them and
         --  drops the pre-existing selection of item 5.
         Base := Files.Interaction.Selected_Visible_Indices (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => False, Base => Base);
         Assert (Files.Model.Is_Selected (Model, 1) and then Files.Model.Is_Selected (Model, 2),
                 "a non-additive marquee selects exactly the items it touches");
         Assert (not Files.Model.Is_Selected (Model, 3)
                 and then not Files.Model.Is_Selected (Model, 5),
                 "a non-additive marquee replaces the prior selection");

         --  Releasing keeps the selection: the reducer applies nothing on a
         --  marquee release, so the last applied set survives.
         declare
            Before : constant Natural := Files.Model.Selected_Count (Model);
         begin
            Files_Suite.Support.Assert_Equal (Before, 2, "the marquee selection holds after the drag");
         end;

         --  An additive marquee unions the touched items with the base snapshot.
         Files.Model.Clear_Selection (Model);
         Files.Model.Select_Visible (Model, 4);
         Base := Files.Interaction.Selected_Visible_Indices (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => True, Base => Base);
         Assert
           (Files.Model.Is_Selected (Model, 1),
            "an additive marquee unions the touched items with the prior selection (item 1)");
         Assert
           (Files.Model.Is_Selected (Model, 2),
            "an additive marquee unions the touched items with the prior selection (item 2)");
         Assert
           (Files.Model.Is_Selected (Model, 4),
            "an additive marquee unions the touched items with the prior selection (item 4)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Count (Model),
            3,
            "the additive marquee selects exactly the union");

         --  A zero-area marquee (a press that never dragged) selects nothing new.
         Empty := Files.Rendering.Hit.Items_In_Rect (Cells, Rect_X, Rect_Y, 0, 0);
         Assert (Empty.Is_Empty, "a zero-area marquee touches no items");
      end;
   end Test_Marquee_Selection_Drag;
