separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  One item of the grid or list: nothing for an item the layout put off
   --  screen, a caption for a group header, otherwise the whole cell.
   procedure Draw_Item (Index : Positive) is
      Item_Rect : constant Item_Layout := Items.Element (Index);
   begin
      --  Layout marks off-screen items with Height = 0 (Details rows that
      --  fall outside the scrolled viewport and icon cells past the
      --  bottom). Skip them so we don't pay per-item draw/accessibility
      --  cost for hundreds of invisible rows.
      if Item_Rect.Height = 0 or else Item_Rect.Width = 0 then
         return;
      end if;

      declare
         Item      : Item_Snapshot renames Snapshot.Items (Index);
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
            return;
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
               Alternate_Color => Alternate_Row_Color,
               Line_Height     => Line_Height);
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
            Star_Color    => Accent_Gold_Color,
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
                 (Files.Localization.Text
                    ("accessibility.item.details",
                     Files.Localization.Argument_List'
                       [(To_Unbounded_String ("modified_label"), To_Unbounded_String (Detail_Modified_Label)),
                        (To_Unbounded_String ("modified"), Detail_Modified),
                        (To_Unbounded_String ("size_label"), To_Unbounded_String (Detail_Size_Label)),
                        (To_Unbounded_String ("size"), Detail_Size),
                        (To_Unbounded_String ("type_label"), To_Unbounded_String (Detail_Filetype_Label)),
                        (To_Unbounded_String ("type"), Item.Filetype_Detail)]))
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
   end Draw_Item;
