separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Main_View is
   begin
      if Snapshot.View_Mode = Files.Types.Details then
         declare
            Content : constant Content_Rectangle := Main_Content_Rect (Layout);
            Content_X : constant Natural := Content.X;
            Content_Y : constant Natural := Content.Y;
            Content_W : constant Natural := Content.Width;
            Content_H : constant Natural := Content.Height;
            Header_H  : constant Natural :=
              Natural'Min
                (Saturating_Add (Line_Height, Saturating_Multiply (Details_Row_Padding, 2)), Content_H);
            Header_Y  : constant Natural := Content_Y;
            Header_W  : constant Natural := Content_W;
            Header_Pad : constant Natural := Natural'Min (Details_Row_Padding, Header_H);
            --  Optically centre the label in the header field: sit it two pixels
            --  above the geometric inset, matching the bottom bar's text baseline
            --  (Bottom_Content_Y), so the glyphs read as centred rather than low.
            Text_Y    : constant Natural :=
              Saturating_Add (Header_Y, (if Header_Pad >= 2 then Header_Pad - 2 else 0));
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Header_Pad);

            function Cell_X (Column_X : Natural) return Natural is
            begin
               return Saturating_Add (Column_X, Details_Column_Padding);
            end Cell_X;

            function Cell_W (Column_W : Natural) return Natural is
            begin
               return (if Column_W > Details_Column_Padding then Column_W - Details_Column_Padding else 0);
            end Cell_W;

            function Header_Label (Column : Files.Types.Detail_Column) return String is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     return "details.name";
                  when Files.Types.Modified_Column =>
                     return "details.modified";
                  when Files.Types.Size_Column =>
                     return "details.size";
                  when Files.Types.Filetype_Column =>
                     return "details.filetype";
                  when Files.Types.Created_Column =>
                     return "details.created";
                  when Files.Types.Permissions_Column =>
                     return "details.permissions";
               end case;
            end Header_Label;

            function Column_Sort_Field
              (Column : Files.Types.Detail_Column;
               Field  : out Files.Model.Sort_Field)
               return Boolean is
            begin
               case Column is
                  when Files.Types.Name_Column =>
                     Field := Files.Model.Sort_Name;
                     return True;
                  when Files.Types.Modified_Column =>
                     Field := Files.Model.Sort_Changed;
                     return True;
                  when Files.Types.Size_Column =>
                     Field := Files.Model.Sort_Size;
                     return True;
                  when Files.Types.Filetype_Column =>
                     Field := Files.Model.Sort_Type;
                     return True;
                  when Files.Types.Created_Column =>
                     Field := Files.Model.Sort_Created;
                     return True;
                  when Files.Types.Permissions_Column =>
                     Field := Files.Model.Sort_Name;
                     return False;
               end case;
            end Column_Sort_Field;

            function Header_Text (Column : Files.Types.Detail_Column) return UString is
               Label : constant String := Files.Localization.Text (Header_Label (Column));
               Field : Files.Model.Sort_Field;
            begin
               if Column_Sort_Field (Column, Field) and then Snapshot.Sort_Field = Field then
                  return To_Unbounded_String (Label & " " & Direction_Text);
               else
                  return To_Unbounded_String (Label);
               end if;
            end Header_Text;

            function Header_Description return UString is
               Result : Unbounded_String := Null_Unbounded_String;
            begin
               for Column in Files.Types.Detail_Column loop
                  if Columns (Column).Visible then
                     if Length (Result) > 0 then
                        Append (Result, ", ");
                     end if;
                     Append (Result, Files.Localization.Text (Header_Label (Column)));
                  end if;
               end loop;
               return Result;
            end Header_Description;
         begin
            Add_Rect (Content_X, Header_Y, Header_W, Header_H, Pane_Color);
            Add_Border (Content_X, Header_Y, Header_W, Header_H, Border_Color);
            for Column in Files.Types.Detail_Column loop
               if Columns (Column).Visible then
                  Add_Text
                    (Cell_X (Columns (Column).X),
                     Text_Y,
                     Cell_W (Columns (Column).Width),
                     Line_Height,
                     Header_Text (Column),
                     Muted_Text_Color,
                     Fit => True);
               end if;
            end loop;
            Add_Accessibility_Node
              (Role_Table_Row,
               Content_X,
               Header_Y,
               Header_W,
               Header_H,
               To_Unbounded_String (Files.Localization.Text ("details.header")),
               Header_Description);

            if Header_H > 0 then
               for Column in Files.Types.Optional_Detail_Column loop
                  if Columns (Column).Visible then
                     Add_Rect
                       ((if Columns (Column).X > 2 then Columns (Column).X - 2 else 0),
                        Header_Y, 1, Header_H, Border_Color);
                  end if;
               end loop;
               Add_Rect
                 (Content_X,
                  Saturating_Add (Header_Y, Header_H - Natural'Min (2, Header_H)),
                  Header_W,
                  Natural'Min (2, Header_H),
                  Selection_Color);
            end if;
         end;
      end if;

      for Index in 1 .. Natural (Items.Length) loop
         declare
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
         begin
            --  Layout marks off-screen items with Height = 0 (Details rows that
            --  fall outside the scrolled viewport and icon cells past the
            --  bottom). Skip them so we don't pay per-item draw/accessibility
            --  cost for hundreds of invisible rows.
            if Item_Rect.Height = 0 or else Item_Rect.Width = 0 then
               goto Continue_Item_Loop;
            end if;
         end;

         declare
            Item      : Item_Snapshot renames Snapshot.Items (Positive (Index));
            Item_Rect : constant Item_Layout := Items.Element (Positive (Index));
            --  Suppress the main-grid item hover highlight while the context
            --  menu is open: the pointer is interacting with the menu, so the
            --  cell under the cursor must not also light up. The menu's own row
            --  hover (drawn separately) is unaffected.
            Hovered   : constant Boolean :=
              Has_Hover
              and then not Snapshot.Context_Menu_Open
              and then Contains_Point
                (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_X, Hover_Y);
            Drop_Target : constant Boolean :=
              Has_Drag
              and then Drag_Item_Index /= 0
              and then Item.Visible_Index /= Drag_Item_Index
              and then Item.Kind = Files.Types.Directory_Item
              and then Hovered;
            --  Details mode needs the formatted modified/size text twice -- once
            --  to draw the row, once for the accessibility description. Format
            --  each once here; other view modes never touch them.
            Detail_Modified : constant UString :=
              (if Snapshot.View_Mode = Files.Types.Details
               then Detail_Time_Text (Item) else Null_Unbounded_String);
            Detail_Size : constant UString :=
              (if Snapshot.View_Mode = Files.Types.Details
               then Detail_Size_Text (Item) else Null_Unbounded_String);

         begin
            --  Grouping band header: a non-selectable caption row. It draws its
            --  own subdued background and label and then skips all per-item
            --  drawing (icon, columns, selection, hover).
            if Item.Is_Group_Header then
               Guikit.Item_Grid.Draw_Group_Header
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Accessibility    => Result.Accessibility,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  Label            => Item.Group_Label,
                  Line_Height      => Line_Height,
                  Background_Color => Pane_Color,
                  Label_Color      => Muted_Text_Color,
                  Border_Color     => Border_Color);
               goto Continue_Item_Loop;
            end if;

            declare
               Kind : constant Guikit.Item_Grid.Background_Kind :=
                 (if Drop_Target then Guikit.Item_Grid.Drop_Target
                  elsif Item.Selected then Guikit.Item_Grid.Selected
                  elsif Hovered then Guikit.Item_Grid.Hovered
                  elsif Snapshot.View_Mode = Files.Types.Details and then Index mod 2 = 0
                  then Guikit.Item_Grid.Alternate
                  else Guikit.Item_Grid.No_Background);
            begin
               Guikit.Item_Grid.Draw_Item_Background
                 (Rectangles      => Result.Rectangles,
                  Clip_Width      => Layout.Width,
                  Clip_Height     => Layout.Height,
                  Cell            => Item_Rect,
                  Kind            => Kind,
                  Selection_Color => Selection_Color,
                  Hover_Color     => Hover_Color,
                  Border_Color    => Border_Color,
                  Alternate_Color => Detail_Alternate_Color);
            end;

            if Snapshot.View_Mode = Files.Types.Details then
               Add_Details_Icon (Item, Item_Rect.Icon_X, Item_Rect.Icon_Y, Item_Rect.Icon_Size);
            else
               Add_Icon
                 (Item,
                  Item_Rect.Icon_X,
                  Item_Rect.Icon_Y,
                  Item_Rect.Icon_Size,
                  Use_Thumbnail => Snapshot.View_Mode = Files.Types.Large_Icons);
            end if;

            --  Favorite indicator: a small filled star tucked into the
            --  top-left corner of the item's icon in every view mode. Drawn
            --  only for favorited items, so a bare icon means "not favorited".
            --  Favorite star (top-left) and color-label dot (bottom-right) over
            --  the icon; each draws only when set.
            Guikit.Item_Grid.Draw_Item_Indicators
              (Rectangles    => Result.Rectangles,
               Text_Commands => Result.Text,
               Clip_Width    => Layout.Width,
               Clip_Height   => Layout.Height,
               Cell          => Item_Rect,
               Line_Height   => Line_Height,
               Favorite      => Item.Is_Favorite,
               Star_Glyph    => To_Unbounded_String (Favorite_Star_Filled_Text),
               Star_Color    => Favorite_Star_Color,
               Has_Label     => Item.Label /= Files.Types.No_Label,
               Label_Color   => Label_Render_Color (Item.Label));
            declare
               Renaming : constant Boolean := Item.Renaming;
            begin
               Guikit.Item_Grid.Draw_Name_Field
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  View             => Grid_View (Snapshot.View_Mode),
                  Renaming         => Renaming,
                  Focused          => Snapshot.Focus = Files.Types.Focus_Rename_Input,
                  Dim              => Item.Cut_Pending,
                  Text             => (if Renaming then Item.Rename_Value else Displayed_Name (Item)),
                  Cursor           => Item.Rename_Cursor,
                  Line_Height      => Line_Height,
                  Text_Color       => Text_Color,
                  Dim_Color        => Disabled_Text_Color,
                  Border_Color     => Border_Color,
                  Focus_Ring_Color => Snapshot.Theme_Focus_Ring,
                  Caret_Color      => Text_Color);
            end;

            if Snapshot.View_Mode = Files.Types.Details and then Item_Rect.Height > 0 then
               Guikit.Item_Grid.Draw_Details_Row
                 (Rectangles       => Result.Rectangles,
                  Text_Commands    => Result.Text,
                  Tooltips         => Result.Tooltips,
                  Clip_Width       => Layout.Width,
                  Clip_Height      => Layout.Height,
                  Cell             => Item_Rect,
                  Line_Height      => Line_Height,
                  Modified         => Detail_Modified,
                  Size             => Detail_Size,
                  Filetype         => Item.Filetype_Detail,
                  Created          => Detail_Created_Text (Item),
                  Permissions      => Item.Permissions,
                  Modified_Tooltip =>
                    (if Item.Modified_Available
                     then To_Unbounded_String (Full_Time_Text (Item.Modified_Time))
                     else Null_Unbounded_String),
                  Created_Tooltip  =>
                    (if Item.Creation_Available
                     then To_Unbounded_String (Full_Time_Text (Item.Creation_Time))
                     else Null_Unbounded_String),
                  Dim              => Item.Cut_Pending,
                  Value_Color      => Text_Color,
                  Dim_Color        => Disabled_Text_Color,
                  Border_Color     => Border_Color);
            end if;

            declare
               Row_Description : constant UString :=
                 (if Snapshot.View_Mode = Files.Types.Details
                  then To_Unbounded_String
                    (Detail_Modified_Label & ": " &
                     To_String (Detail_Modified) & ", " &
                     Detail_Size_Label & ": " &
                     To_String (Detail_Size) & ", " &
                     Detail_Filetype_Label & ": " &
                     To_String (Item.Filetype_Detail))
                  else Item.Filetype_Detail);
            begin
               Add_Accessibility_Node
                 ((if Snapshot.View_Mode = Files.Types.Details then Role_Table_Row else Role_List_Item),
                  Item_Rect.X,
                  Item_Rect.Y,
                  Item_Rect.Width,
                  Item_Rect.Height,
                  Item.Name,
                  Row_Description,
                  Enabled  => True,
                  Selected => Item.Selected,
                  Focused  =>
                    Item.Selected
                    and then Snapshot.Focus = Files.Types.Focus_None
                    and then not Snapshot.Tree_Keyboard_Active
                    and then not Snapshot.Tree_Pick_Active
                    and then Item.Visible_Index =
                      Snapshot.Primary_Selected_Visible_Index);
            end;
         end;

         <<Continue_Item_Loop>>
         null;
      end loop;

      if Snapshot.View_Mode = Files.Types.Details and then not Items.Is_Empty then
         declare
            Content   : constant Content_Rectangle := Main_Content_Rect (Layout);
            Content_X : constant Natural := Content.X;
            Content_W : constant Natural := Content.Width;
            Content_Y : constant Natural := Content.Y;
            Separator_Y : constant Natural := Content_Y;
            --  Bottom edge of the content viewport (excludes the bottom bar).
            Content_Bottom : constant Natural := Saturating_Add (Content_Y, Content.Height);

            --  The dividers span the visible rows only: down to the bottom edge of
            --  the last row that is actually on screen, clamped to the viewport.
            --  They must not descend past the last visible line into empty space
            --  below the list (nor through the bottom bar).
            function Last_Visible_Bottom return Natural is
               Result : Natural := Content_Y;
            begin
               for Row of Items loop
                  declare
                     Row_Bottom : constant Natural := Saturating_Add (Row.Y, Row.Height);
                  begin
                     if Row.Y < Content_Bottom and then Row_Bottom > Content_Y then
                        Result := Natural'Max (Result, Natural'Min (Row_Bottom, Content_Bottom));
                     end if;
                  end;
               end loop;
               return Result;
            end Last_Visible_Bottom;

            Separator_H : constant Natural := Last_Visible_Bottom - Separator_Y;
            Columns   : constant Detail_Column_Geometry_Array :=
              Compute_Detail_Columns
                (Snapshot.Detail_Columns_Visible,
                 Snapshot.Detail_Column_Widths,
                 Snapshot.Detail_Column_Order,
                 Content_X,
                 Content_W,
                 Line_Height,
                 Natural'Min (Details_Row_Padding, Line_Height));

            procedure Add_Column_Separator (Column_X : Natural) is
            begin
               Add_Rect ((if Column_X > 2 then Column_X - 2 else 0), Separator_Y, 1, Separator_H, Border_Color);
            end Add_Column_Separator;
         begin
            for Column in Files.Types.Optional_Detail_Column loop
               if Columns (Column).Visible then
                  Add_Column_Separator (Columns (Column).X);
               end if;
            end loop;
         end;
      end if;

      --  Rubber-band (marquee) selection rectangle: a translucent fill plus a
      --  solid selection-colored border over the grid while an empty-space drag
      --  is in progress. The items it touches are already drawn selected via the
      --  selection set, so this only shows the drag region itself.
      if Marquee_Active
        and then Marquee_W > 0
        and then Marquee_H > 0
        and then Width > 0
        and then Height > 0
      then
         Guikit.Widgets.Draw_Marquee
           (Rectangles   => Result.Rectangles,
            Clip_Width   => Layout.Width,
            Clip_Height  => Layout.Height,
            X            => Marquee_X,
            Y            => Marquee_Y,
            Width        => Marquee_W,
            Height       => Marquee_H,
            Fill_Color   => Marquee_Color,
            Border_Color => Selection_Color);
      end if;

      if Has_Drag
        and then Drag_Item_Index /= 0
        and then not Snapshot.Items.Is_Empty
        and then Width > 0
        and then Height > 0
      then
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            declare
               Item : Item_Snapshot renames Snapshot.Items (Positive (Index));
            begin
               if Item.Visible_Index = Drag_Item_Index then
                  declare
                     Desired_Icon : constant Natural :=
                       Natural'Min (Natural'Max (Line_Height, 28), 48);
                     Desired_H : constant Natural :=
                       Saturating_Add (Desired_Icon, 16);
                     Panel_H   : constant Natural := Natural'Min (Desired_H, Height);
                     Panel_W   : constant Natural :=
                       Natural'Min
                         (Natural'Max
                            (Saturating_Add
                               (Saturating_Add (Desired_Icon, 8),
                                Saturating_Multiply (Line_Height, 8)),
                             Saturating_Add (Desired_Icon, 16)),
                          Natural'Max (1, Width));
                     Offset    : constant Natural := 14;
                     Panel_X   : constant Natural :=
                       (if Drag_X <= Natural'Last - Offset
                          and then Drag_X + Offset <= Width
                          and then Width > Panel_W
                        then Natural'Min (Drag_X + Offset, Width - Panel_W)
                        elsif Width > Panel_W
                        then Width - Panel_W
                        else 0);
                     Panel_Y   : constant Natural :=
                       (if Drag_Y <= Natural'Last - Offset
                          and then Drag_Y + Offset <= Height
                          and then Height > Panel_H
                        then Natural'Min (Drag_Y + Offset, Height - Panel_H)
                        elsif Height > Panel_H
                        then Height - Panel_H
                        else 0);
                     Pad       : constant Natural :=
                       Natural'Min (8, Natural'Min (Panel_W / 4, Panel_H / 4));
                     Inner_W   : constant Natural :=
                       (if Panel_W > Saturating_Multiply (Pad, 2)
                        then Panel_W - Saturating_Multiply (Pad, 2)
                        else 0);
                     Inner_H   : constant Natural :=
                       (if Panel_H > Saturating_Multiply (Pad, 2)
                        then Panel_H - Saturating_Multiply (Pad, 2)
                        else 0);
                     Fitted_Icon : constant Natural := Natural'Min (Desired_Icon, Inner_H);
                     Icon_Size : constant Natural :=
                       (if Inner_W > Saturating_Add (Fitted_Icon, Saturating_Multiply (Line_Height, 2))
                        then Fitted_Icon
                        else 0);
                     Gap       : constant Natural :=
                       (if Icon_Size > 0 then Natural'Min (8, Inner_W - Icon_Size) else 0);
                     Icon_X    : constant Natural := Saturating_Add (Panel_X, Pad);
                     Icon_Y    : constant Natural :=
                       Saturating_Add
                         (Panel_Y,
                          Saturating_Add
                            (Pad, (if Inner_H > Icon_Size then (Inner_H - Icon_Size) / 2 else 0)));
                     Text_X    : constant Natural :=
                       Saturating_Add (Icon_X, Saturating_Add (Icon_Size, Gap));
                     Text_W    : constant Natural :=
                       (if Inner_W > Saturating_Add (Icon_Size, Gap)
                        then Inner_W - Icon_Size - Gap
                        else 0);
                     Text_H    : constant Natural := Natural'Min (Line_Height, Inner_H);
                     Text_Y    : constant Natural :=
                       Saturating_Add
                         (Panel_Y, Saturating_Add
                            (Pad, (if Inner_H > Text_H then (Inner_H - Text_H) / 2 else 0)));
                  begin
                     Add_Overlay_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Hover_Color);
                     Add_Overlay_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Selection_Color);
                     Add_Icon (Item, Icon_X, Icon_Y, Icon_Size, Overlay => True);
                     Add_Overlay_Text
                       (Text_X, Text_Y, Text_W, Text_H, Item.Name, Fit => True);
                  end;

                  exit;
               end if;
            end;
         end loop;
      end if;

      if Empty_State_Key /= "" and then Layout.Main_Width > 0 and then Layout.Main_Height > 0 then
         declare
            Panel_W : constant Natural :=
              Natural'Min (Natural'Max (240, Layout.Main_Width / 2), Layout.Main_Width);
            Panel_H : constant Natural := Natural'Min (Saturating_Multiply (Line_Height, 3), Layout.Main_Height);
            Panel_X : constant Natural :=
              Saturating_Add
                (Layout.Main_X,
                 (if Layout.Main_Width > Panel_W then (Layout.Main_Width - Panel_W) / 2 else 0));
            Panel_Y : constant Natural :=
              Saturating_Add
                (Layout.Main_Y,
                 (if Layout.Main_Height > Panel_H then (Layout.Main_Height - Panel_H) / 2 else 0));
            Text_H : constant Natural := Natural'Min (Line_Height, Panel_H);
            Text_Y : constant Natural :=
              Saturating_Add (Panel_Y, (if Panel_H > Text_H then (Panel_H - Text_H) / 2 else 0));
            Side_Pad : constant Natural := Natural'Min (8, Panel_W / 4);
            Inner_X  : constant Natural := Saturating_Add (Panel_X, Side_Pad);
            Inner_W  : constant Natural :=
              (if Panel_W > Saturating_Multiply (Side_Pad, 2)
               then Panel_W - Saturating_Multiply (Side_Pad, 2)
               else 0);
            Desired_Icon : constant Natural := Natural'Min (Line_Height, Panel_H);
            --  Text is the useful empty-state explanation. Drop the decorative
            --  icon when a compact panel cannot leave two text cells beside it.
            Icon_Size : constant Natural :=
              (if Inner_W > Saturating_Add (Desired_Icon, Saturating_Multiply (Line_Height, 2))
               then Desired_Icon
               else 0);
            Icon_Gap : constant Natural :=
              (if Icon_Size > 0 then Natural'Min (8, Inner_W - Icon_Size) else 0);
            Icon_X : constant Natural := Inner_X;
            Text_X : constant Natural :=
              Saturating_Add (Inner_X, Saturating_Add (Icon_Size, Icon_Gap));
            Text_W : constant Natural :=
              (if Inner_W > Saturating_Add (Icon_Size, Icon_Gap)
               then Inner_W - Icon_Size - Icon_Gap
               else 0);
         begin
            Add_Rect (Panel_X, Panel_Y, Panel_W, Panel_H, Pane_Color);
            Add_Border (Panel_X, Panel_Y, Panel_W, Panel_H, Border_Color);
            if Icon_Size > 0 then
               Add_Rect
                 (Icon_X,
                  Text_Y,
                  Icon_Size,
                  Natural'Min (Icon_Size, Text_H),
                  Muted_Text_Color);
               if Icon_Size > 6 then
                  Add_Rect
                    (Saturating_Add (Icon_X, Icon_Size / 4),
                     Saturating_Add (Text_Y, Icon_Size / 2),
                     Icon_Size / 2,
                     1,
                     Pane_Color);
               end if;
            end if;
            Add_Text
              (Text_X,
               Text_Y,
               Text_W,
               Text_H,
               To_Unbounded_String (Files.Localization.Text (Empty_State_Key)),
               Muted_Text_Color,
               Fit => True);
         end;
      end if;

      if Main_View.Scrollbar_Visible then
         Add_Scrollbar
           (Main_View.Scrollbar_X,
            Main_View.Scrollbar_Y,
            Main_View.Scrollbar_Width,
            Main_View.Scrollbar_Track_Height,
            Main_View.Scrollbar_Thumb_Y,
            Main_View.Scrollbar_Height);
      end if;
   end Draw_Main_View;
