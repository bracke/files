with Files.Item_Lists;
with Files.Rendering.Layouts.Details;
with Files.Preference_Types;
with Files.Input_Actions;
with Files.Rendering.Layouts;
with Files_Suite.Support.Disk;
with Files.Text_Basics;

separate (Files_Suite.Drags)
   procedure Test_Marquee_Selection_Drag (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      --  A small details list leaves ample empty space below the rows and lays
      --  out no scrollbar, so an empty-grid press is unambiguous.
      for Index in 1 .. 6 loop
         Items.Append
           (Files.Item_Lists.Make_Item
              (Files_Suite.Support.Disk.Root, "item-" & Files.Text_Basics.Natural_Text (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Disk.Root, Items, Files_Suite.Support.Disk.Root,
         Default_View_Mode => Files.Preference_Types.Details);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Layouts.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Cells    : constant Files.Rendering.Layouts.Item_Layout_Vectors.Vector :=
           Files.Rendering.Layouts.Calculate_Item_Layout (Snapshot, Layout, Line);
         Cell_1   : constant Files.Rendering.Layouts.Item_Layout := Cells.Element (1);
         Cell_2   : constant Files.Rendering.Layouts.Item_Layout := Cells.Element (2);
         Bottom_Y : constant Natural :=
           Cells.Element (Cells.Last_Index).Y
           + Cells.Element (Cells.Last_Index).Height + 20;
         Empty_X  : constant Natural := Layout.Main_X + 10;

         --  The rectangle a drag from item 1's cell to item 2's cell describes.
         Rect_X, Rect_Y, Rect_W, Rect_H : Natural;
         Empty    : Files.Rendering.Visible_Index_Vectors.Vector;
         Hits     : Files.Rendering.Visible_Index_Vectors.Vector;
         Base     : Files.Types.String_Vectors.Vector;
         X, Y     : Natural;
         Found    : Boolean;
      begin
         Assert (Bottom_Y < Layout.Main_Y + Layout.Main_Height,
                 "the six-row list leaves empty grid space below the last row");

         --  Details rows share an X, so span a nonzero width across rows 1..2.
         Files.Rendering.Layouts.Marquee_Rect
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
            Action : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
            Additive : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Modifiers => Ctrl, Line_Height => Line);
         begin
            Files_Suite.Support.Assert_Equal
              (Action.Kind,
               Files.Input_Actions.Marquee_Begin_Input_Action,
               "an empty-space press begins a marquee");
            Assert (not Action.Additive,
                    "a plain empty-space marquee is not additive");
            Assert (Additive.Kind = Files.Input_Actions.Marquee_Begin_Input_Action
                    and then Additive.Additive,
                    "a Ctrl empty-space press begins an additive marquee");
         end;

         --  Precedence: a press ON an item is a normal click, not a marquee; a
         --  press on the details header is a header action, not a marquee.
         Item_Center (Model, 1, X, Y, Found);
         Assert (Found, "a layout cell exists for the target item");
         declare
            Action : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, X, Y, Window_W, Window_H, Line_Height => Line);
         begin
            Files_Suite.Support.Assert_Equal
              (Action.Kind,
               Files.Input_Actions.Item_Click_Input_Action,
               "a press on an item stays a normal item click, not a marquee");
         end;
         declare
            Header_X : constant Natural := Layout.Main_X + Layout.Main_Width / 2;
            Header_Y : constant Natural :=
              (if Cell_1.Y > Line then Cell_1.Y - Line / 2 else Cell_1.Y);
            Header   : constant Files.Rendering.Layouts.Details.Detail_Header_Cell :=
              Files.Rendering.Hit.Details_Header_Cell_At (Snapshot, Layout, Header_X, Header_Y, Line);
            Action   : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Header_X, Header_Y, Window_W, Window_H, Line_Height => Line);
         begin
            Assert (Header.Present, "the details header spans the probed point");
            Assert (Action.Kind /= Files.Input_Actions.Marquee_Begin_Input_Action,
                    "a press on the details header does not begin a marquee");
         end;

         --  An empty-space marquee begin is a shell-owned no-op in the reducer:
         --  applying it must not disturb a prior selection (it is not a clear).
         Files.Model.Selection.Select_Visible (Model, 5);
         Assert (Files.Model.Selection.Is_Selected (Model, 5), "item 5 is selected before the marquee begins");
         declare
            Action : constant Files.Input_Actions.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame, Empty_X, Bottom_Y, Window_W, Window_H,
                 Line_Height => Line);
         begin
            Files.Interaction.Apply_Input_Action
              (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
         end;
         Assert (Files.Model.Selection.Is_Selected (Model, 5),
                 "beginning a marquee leaves the prior selection to the shell (no clear)");

         --  Dragging over items 1 and 2 (non-additive) selects exactly them and
         --  drops the pre-existing selection of item 5.
         Base := Files.Interaction.Marquee_Base (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => False, Base => Base);
         Assert (Files.Model.Selection.Is_Selected (Model, 1) and then Files.Model.Selection.Is_Selected (Model, 2),
                 "a non-additive marquee selects exactly the items it touches");
         Assert (not Files.Model.Selection.Is_Selected (Model, 3)
                 and then not Files.Model.Selection.Is_Selected (Model, 5),
                 "a non-additive marquee replaces the prior selection");

         --  Releasing keeps the selection: the reducer applies nothing on a
         --  marquee release, so the last applied set survives.
         declare
            Before : constant Natural := Files.Model.Selection.Selected_Count (Model);
         begin
            Files_Suite.Support.Assert_Equal (Before, 2, "the marquee selection holds after the drag");
         end;

         --  An additive marquee unions the touched items with the base snapshot.
         Files.Model.Selection.Clear (Model);
         Files.Model.Selection.Select_Visible (Model, 4);
         Base := Files.Interaction.Marquee_Base (Model);
         Files.Interaction.Apply_Marquee_Selection
           (Model, Hits, Additive => True, Base => Base);
         Assert
           (Files.Model.Selection.Is_Selected (Model, 1),
            "an additive marquee unions the touched items with the prior selection (item 1)");
         Assert
           (Files.Model.Selection.Is_Selected (Model, 2),
            "an additive marquee unions the touched items with the prior selection (item 2)");
         Assert
           (Files.Model.Selection.Is_Selected (Model, 4),
            "an additive marquee unions the touched items with the prior selection (item 4)");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Count (Model),
            3,
            "the additive marquee selects exactly the union");

         --  The same band again (a drag held still) changes nothing, so the
         --  view keeps the snapshot it has instead of rebuilding it.
         declare
            Revision : constant Natural := Files.Model.Revision (Model);
         begin
            Files.Interaction.Apply_Marquee_Selection (Model, Hits, Additive => True, Base => Base);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Revision (Model), Revision, "re-applying the same band leaves the revision alone");
         end;

         --  A zero-area marquee (a press that never dragged) selects nothing new.
         Empty := Files.Rendering.Hit.Items_In_Rect (Cells, Rect_X, Rect_Y, 0, 0);
         Assert (Empty.Is_Empty, "a zero-area marquee touches no items");

         --  A refresh lands mid-drag: a new item sorts in first, so every row
         --  moves down one. The additive base still names the items selected
         --  at the press, not the rows they used to be on.
         Files.Model.Selection.Clear (Model);
         Files.Model.Selection.Select_Visible (Model, 2);
         Files.Model.Selection.Toggle_Visible_Selection (Model, 4);
         Base := Files.Interaction.Marquee_Base (Model);
         declare
            Refreshed : Files.Items.Item_Vectors.Vector := Items;
         begin
            Refreshed.Prepend
              (Files.Item_Lists.Make_Item
                 (Files_Suite.Support.Disk.Root, "item-0", Files.Types.Regular_File_Item, "text/plain"));
            Files.Model.Replace_Items (Model, Refreshed);
         end;
         Files.Interaction.Apply_Marquee_Selection (Model, Empty, Additive => True, Base => Base);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Count (Model), 2, "the base keeps exactly its two items");
         Assert (Files.Model.Selection.Is_Selected (Model, 3) and then Files.Model.Selection.Is_Selected (Model, 5),
                 "item-2 and item-4, now on rows 3 and 5, stay selected");
         Assert (not Files.Model.Selection.Is_Selected (Model, 2)
                 and then not Files.Model.Selection.Is_Selected (Model, 4),
                 "the rows they used to be on (now item-1 and item-3) are not selected");
      end;
   end Test_Marquee_Selection_Drag;
