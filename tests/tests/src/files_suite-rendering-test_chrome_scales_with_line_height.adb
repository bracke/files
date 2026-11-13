with Files.File_Types;
with Files.Rendering.Testing;
with Guikit.Item_Grid;
with Guikit.Layout;

separate (Files_Suite.Rendering)
   --  On a 2x display the line height doubles, and chrome sized in fixed
   --  pixels did not: toolbar buttons half as wide as their text called for,
   --  icons capped at half size, 4-point scrollbars. Chrome now scales with
   --  the line height, and stays as it was at the reference one.
   procedure Test_Chrome_Scales_With_Line_Height (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Reference : constant Positive := Guikit.Layout.Reference_Line_Height;
      Button    : constant Natural := Guikit.Layout.Toolbar_Button_Width;
   begin
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, Reference).Button_Width,
         Guikit.Layout.Toolbar_Button_Width,
         "at the reference line height a toolbar button is as wide as ever");
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, 2 * Reference).Button_Width,
         2 * Guikit.Layout.Toolbar_Button_Width,
         "at twice the line height it is twice as wide");
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Calculate_Toolbar_Layout (2_000, Reference / 2).Button_Width,
         Guikit.Layout.Toolbar_Button_Width,
         "and a small font never shrinks it below the reference size");
      declare
         Doubled : constant Files.Commands.Command_Id :=
           Files.Rendering.Hit.Toolbar_Command_At (3 * Button, 2 * Reference, 2_000, 2 * Reference);
         Single  : constant Files.Commands.Command_Id :=
           Files.Rendering.Hit.Toolbar_Command_At (3 * Button / 2, Reference, 2_000, Reference);
      begin
         Assert (Single /= Files.Commands.No_Command, "the probe is on a toolbar button");
         Assert (Doubled = Single, "the hit test agrees: a point scaled with the display hits the same button");
      end;
      Files_Suite.Support.Assert_Equal
        (Guikit.Layout.Toolbar_Input_Height (2 * Reference),
         2 * Guikit.Layout.Toolbar_Input_Height (Reference),
         "the toolbar's input fields keep their proportions");
      --  Paddings and gaps too, here and in guikit's components.
      Files_Suite.Support.Assert_Equal
        (Files.UI.Field_Padding (2 * Reference), 2 * Files.UI.Field_Padding (Reference), "input field padding");
      Files_Suite.Support.Assert_Equal
        (Guikit.Item_Grid.Grid_Gap (2 * Reference), 2 * Guikit.Item_Grid.Main_Grid_Gap, "the item grid's gap");
      Files_Suite.Support.Assert_Equal
        (Guikit.Item_Grid.Column_Padding (2 * Reference), 2 * Guikit.Item_Grid.Details_Column_Padding,
         "a details column's padding");
      declare
         Snap : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      begin
         Snap.Root_Selector_Open := True;
         Files_Suite.Support.Assert_Equal
           (Calculate_Root_Selector_Layout (Snap, Calculate_Layout (Snap, 2000, 1600, 2 * Reference), 2 * Reference)
              .Padding,
            2 * Calculate_Root_Selector_Layout (Snap, Calculate_Layout (Snap, 2000, 1600, Reference), Reference)
              .Padding,
            "the root selector's padding");
      end;

      --  The context menu's padding and minimum width feed both its drawing
      --  and its hit-test, so the two stay in agreement at any line height.
      declare
         Snap : View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);

         function Menu_At (LH : Positive) return Context_Menu_Layout is
           (Calculate_Context_Menu_Layout (Snap, 2_000, 1_600, LH));
      begin
         Snap.Context_Menu_Open := True;
         Snap.Context_Menu_Target := Files.Types.Context_Menu_Item;
         Snap.Context_Menu_X := 100;
         Snap.Context_Menu_Y := 100;
         declare
            Single : constant Context_Menu_Layout := Menu_At (Reference);
            Double : constant Context_Menu_Layout := Menu_At (2 * Reference);
            Row_X  : constant Natural := Double.X + Double.Width / 2;
            Row_Y  : constant Natural :=
              Files.Rendering.Testing.Context_Menu_Row_Top (Double, 1) + Double.Row_Height / 2;
         begin
            Files_Suite.Support.Assert_Equal (Single.Padding, 4, "the context menu's padding at the reference");
            Assert (Single.Width >= 180, "the context menu is at least 180 px wide at the reference");
            Files_Suite.Support.Assert_Equal
              (Double.Padding, 2 * Single.Padding, "the context menu's padding doubles with the line height");
            Files_Suite.Support.Assert_Equal
              (Double.Width, 2 * Single.Width, "the context menu's width doubles with the line height");
            Assert (Double.Width >= 360, "and so does its minimum width");
            Files_Suite.Support.Assert_Equal
              (Double.Row_Height, 2 * Single.Row_Height, "a context-menu row doubles with the line height");
            Files_Suite.Support.Assert_Equal
              (Files.Rendering.Hit.Context_Menu_Row_At (Double, Row_X, Row_Y),
               1,
               "the hit-test agrees with the scaled menu: the first row's centre hits it");
         end;
      end;

      --  A hover tooltip's gap from the pointer and its padding.
      declare
         Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);

         --  Where the first row of a toolbar button's tooltip lands, relative
         --  to the pointer hovering the button's centre.
         procedure Tooltip_Offset (LH : Positive; DX, DY : out Natural) is
            Plain   : constant Frame_Commands := Build_Frame_Commands (Snap, 2_000, 1_600, LH);
            Toolbar : constant Natural := Files.UI.Toolbar_Height (LH);
            HX, HY  : Natural := 0;
         begin
            DX := 0;
            DY := 0;
            for Tip of Plain.Tooltips loop
               if Tip.Y + Tip.Height <= Toolbar then
                  HX := Tip.X + Tip.Width / 2;
                  HY := Tip.Y + Tip.Height / 2;
                  exit;
               end if;
            end loop;
            Assert (HX > 0, "a toolbar control carries a tooltip");
            declare
               Hovered : constant Frame_Commands :=
                 Build_Frame_Commands
                   (Snap, 2_000, 1_600, LH, Pointer => (Hover_X => HX, Hover_Y => HY, Has_Hover => True, others => <>));
               First   : constant Positive := Natural (Plain.Overlay_Text.Length) + 1;
            begin
               Assert (Natural (Hovered.Overlay_Text.Length) >= First, "hovering the control shows its tooltip");
               DX := Hovered.Overlay_Text.Element (First).X - HX;
               DY := Hovered.Overlay_Text.Element (First).Y - HY;
            end;
         end Tooltip_Offset;

         Single_X, Single_Y, Double_X, Double_Y : Natural;
      begin
         Tooltip_Offset (Reference, Single_X, Single_Y);
         Tooltip_Offset (2 * Reference, Double_X, Double_Y);
         Files_Suite.Support.Assert_Equal
           (Single_X, 12 + 6, "at the reference the tooltip text sits a 12 px gap and 6 px padding right");
         Files_Suite.Support.Assert_Equal
           (Single_Y, 18 + 8, "at the reference the tooltip text sits an 18 px gap and 8 px padding below");
         Files_Suite.Support.Assert_Equal
           (Double_X, 2 * Single_X, "the tooltip's gap and padding double with the line height");
         Files_Suite.Support.Assert_Equal
           (Double_Y, 36 + 17, "below the pointer too (the vertical padding follows the text height)");
      end;

      --  Dialog and status-field padding.
      Files_Suite.Support.Assert_Equal (Files.UI.Dialog_Padding (Reference), 12, "a dialog's padding at the reference");
      Files_Suite.Support.Assert_Equal
        (Files.UI.Dialog_Padding (2 * Reference), 24, "a dialog's padding doubles with the line height");
      Files_Suite.Support.Assert_Equal
        (Files.UI.Status_Field_Padding (Reference), 4, "a status field's inset at the reference");
      Files_Suite.Support.Assert_Equal
        (Files.UI.Status_Field_Padding (2 * Reference), 8, "a status field's inset doubles with the line height");
      Files_Suite.Support.Assert_Equal
        (Files.UI.Bottom_Bar_Height (2 * Reference),
         2 * Files.UI.Bottom_Bar_Height (Reference),
         "the bottom bar's padding scales with its text");
      declare
         Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);

         function Conflict_Inset (LH : Positive) return Natural is
            Dialog : constant Conflict_Dialog_Layout :=
              Calculate_Conflict_Dialog_Layout (Calculate_Layout (Snap, 2_000, 1_600, LH), LH);
         begin
            return Dialog.Message_X - Dialog.X;
         end Conflict_Inset;

         function Progress_Inset (LH : Positive) return Natural is
            Dialog : constant Paste_Progress_Layout :=
              Files.Rendering.Testing.Calculate_Paste_Progress_Layout (Calculate_Layout (Snap, 2_000, 1_600, LH), LH);
         begin
            return Dialog.Message_X - Dialog.X;
         end Progress_Inset;
      begin
         Files_Suite.Support.Assert_Equal (Conflict_Inset (Reference), 12, "the conflict dialog's inset");
         Files_Suite.Support.Assert_Equal (Conflict_Inset (2 * Reference), 24, "the conflict dialog's inset doubles");
         Files_Suite.Support.Assert_Equal (Progress_Inset (Reference), 12, "the progress dialog's inset");
         Files_Suite.Support.Assert_Equal (Progress_Inset (2 * Reference), 24, "the progress dialog's inset doubles");
      end;

      --  The info-pane toggle's label inset in the bottom bar.
      declare
         Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);

         function Toggle_Inset (LH : Positive) return Natural is
            Frame    : constant Frame_Commands := Build_Frame_Commands (Snap, 2_000, 1_600, LH);
            Bar      : constant Guikit.Layout.Bottom_Bar_Layout :=
              Files.UI.Calculate_Bottom_Bar_Layout (2_000, Snap.Sort_Field, LH);
            Bottom_Y : constant Natural := 1_600 - Files.UI.Bottom_Bar_Height (LH);
         begin
            for C of Frame.Text loop
               if C.Y >= Bottom_Y
                 and then C.X >= Bar.Info_Pane_X
                 and then C.X < Bar.Info_Pane_X + Bar.Info_Pane_Width
               then
                  return C.X - Bar.Info_Pane_X;
               end if;
            end loop;
            return Natural'Last;
         end Toggle_Inset;
      begin
         Files_Suite.Support.Assert_Equal (Toggle_Inset (Reference), 4, "the info toggle's label inset");
         Files_Suite.Support.Assert_Equal (Toggle_Inset (2 * Reference), 8, "the info toggle's label inset doubles");
      end;

      --  A toolbar icon's margins inside its button.
      declare
         Snap : constant View_Snapshot := Sample_Snapshot (3, Files.Types.Details);

         function Toolbar_Icon_Size (LH : Positive) return Natural is
         begin
            for Icon of Build_Frame_Commands (Snap, 2_000, 1_600, LH).Icons loop
               if Icon.Class = Placed_Icon then
                  return Icon.Size;
               end if;
            end loop;
            return 0;
         end Toolbar_Icon_Size;
      begin
         Assert (Toolbar_Icon_Size (Reference) > 0, "the toolbar draws its icons");
         Assert
           (Toolbar_Icon_Size (Reference) <= Guikit.Layout.Calculate_Toolbar_Layout (2_000, Reference).Button_Width - 8,
            "at the reference a toolbar icon keeps 4 px either side inside its button");
         Files_Suite.Support.Assert_Equal
           (Toolbar_Icon_Size (2 * Reference),
            2 * Toolbar_Icon_Size (Reference),
            "a toolbar icon, and its margins, double with the line height");
      end;

      --  A dragged item's preview: its icon's size clamps, offset and padding.
      declare
         Folder_Blue : constant Guikit.Draw.Icon_Rgb := (R => 82, G => 128, B => 209);
         Snap        : View_Snapshot := Sample_Snapshot (3, Files.Types.Details);

         procedure Preview (LH : Positive; DX, DY, Size : out Natural; Base : out Guikit.Draw.Icon_Rgb) is
            Frame : constant Frame_Commands :=
              Build_Frame_Commands
                (Snap, 2_000, 1_600, LH,
                 Pointer =>
                   (Has_Drag => True, Drag_Item_Index => 1, Drag_X => 300, Drag_Y => 300, others => <>));
         begin
            DX := Natural'Last;
            DY := Natural'Last;
            Size := 0;
            Base := Guikit.Draw.Default_Icon_Base_Color;
            for Icon of Frame.Icons loop
               if Icon.Overlay then
                  DX := Icon.X - 300;
                  DY := Icon.Y - 300;
                  Size := Icon.Size;
                  Base := Icon.Base_Color;
               end if;
            end loop;
         end Preview;

         Single_X, Single_Y, Single_Size, Double_X, Double_Y, Double_Size : Natural;
         Single_Base, Double_Base : Guikit.Draw.Icon_Rgb;
      begin
         Snap.Items (1).Kind := Files.Types.Directory_Item;
         Snap.Items (1).Icon := Files.File_Types.Folder_Icon;
         Preview (Reference, Single_X, Single_Y, Single_Size, Single_Base);
         Preview (2 * Reference, Double_X, Double_Y, Double_Size, Double_Base);
         Files_Suite.Support.Assert_Equal (Single_Size, 28, "at the reference a drag preview's icon is 28 px");
         Files_Suite.Support.Assert_Equal (Double_Size, 56, "its clamps double with the line height");
         Files_Suite.Support.Assert_Equal
           (Single_X, 14 + 8, "at the reference the preview sits 14 px past the pointer, its icon 8 px in");
         Files_Suite.Support.Assert_Equal (Single_Y, 14 + 8, "below the pointer too");
         Files_Suite.Support.Assert_Equal (Double_X, 2 * Single_X, "the offset and padding double");
         Files_Suite.Support.Assert_Equal (Double_Y, 2 * Single_Y, "below the pointer too, doubled");
         --  The backend no longer recognizes a folder by its name: files says
         --  which colour the atlas tile is drawn in.
         Assert
           (Single_Base = Folder_Blue and then Double_Base = Folder_Blue,
            "a dragged folder's atlas icon asks for the folder blue");
         Snap.Theme_Palette := Guikit.Draw.Theme_Light;
         Preview (Reference, Single_X, Single_Y, Single_Size, Single_Base);
         Assert
           (Single_Base = Guikit.Draw.Icon_Rgb_For (Guikit.Draw.Icon_Folder_Color, Guikit.Draw.Theme_Light)
            and then Single_Base /= Folder_Blue,
            "under the light theme a dragged folder asks for the light theme's folder blue");
         Snap.Theme_Palette := Guikit.Draw.Theme_Dark;
         Snap.Items (1).Kind := Files.Types.Regular_File_Item;
         Snap.Items (1).Icon := Files.File_Types.Text_Icon;
         Preview (Reference, Single_X, Single_Y, Single_Size, Single_Base);
         Assert
           (Single_Base = Guikit.Draw.Default_Icon_Base_Color,
            "a dragged document's atlas icon keeps the neutral grey");
      end;
   end Test_Chrome_Scales_With_Line_Height;
