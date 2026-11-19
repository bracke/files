separate (Files.Rendering.Build_Frame_Commands.Draw_Main_View)
   --  One item of the grid or list: nothing for an item the layout put off
   --  screen, a caption for a group header, otherwise the whole cell.
   procedure Draw_Item (Index : Positive) is
      Item_Rect : constant Item_Layout := Items.Element (Index);
      Item      : Item_Snapshot renames Snapshot.Items (Index);
      Details   : constant Boolean := Snapshot.View_Mode = Files.Types.Details;

      --  Grouping band header: a non-selectable caption row. It draws its
      --  own subdued background and label and none of the per-item drawing
      --  (icon, columns, selection, hover).
      procedure Draw_Group_Header is
      begin
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
      end Draw_Group_Header;

      --  The cell's background: the drop target, selection, hover or the
      --  alternate Details row shade, in that order of precedence.
      procedure Draw_Background (Hovered, Drop_Target : Boolean) is
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
      end Draw_Background;

      --  The icon (or thumbnail), with the favorite star (top-left) and the
      --  color-label dot (bottom-right) over it in every view mode; each
      --  draws only when set, so a bare icon means neither.
      procedure Draw_Icon is
      begin
         if Snapshot.View_Mode = Files.Types.Details then
            Add_Icon (Item, Item_Rect.Icon_X, Item_Rect.Icon_Y, Item_Rect.Icon_Size);
         else
            Add_Icon
              (Item,
               Item_Rect.Icon_X,
               Item_Rect.Icon_Y,
               Item_Rect.Icon_Size,
               Use_Thumbnail => Snapshot.View_Mode = Files.Types.Large_Icons);
         end if;

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
      end Draw_Icon;

      --  The name, or the rename field while the item is being renamed.
      procedure Draw_Name is
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
            Focused          => Snapshot.Focus = Files.UI_Types.Focus_Rename_Input,
            Dim              => Item.Cut_Pending,
            Text             => (if Renaming then Item.Rename_Value else Displayed_Name (Item)),
            Cursor           => Item.Rename_Cursor,
            Line_Height      => Line_Height,
            Text_Color       => Text_Color,
            Dim_Color        => Disabled_Text_Color,
            Border_Color     => Border_Color,
            Focus_Ring_Color => Snapshot.Theme_Focus_Ring,
            Caret_Color      => Text_Color);
      end Draw_Name;

      --  The Details row's columns. The full-date tooltips of the time cells
      --  only for the row under the pointer: only its tooltip can show in
      --  this frame.
      procedure Draw_Details_Columns (Hovered : Boolean; Cells : Detail_Column_Texts) is
      begin
         Guikit.Item_Grid.Draw_Details_Row
           (Rectangles       => Result.Rectangles,
            Text_Commands    => Result.Text,
            Tooltips         => Result.Tooltips,
            Clip_Width       => Layout.Width,
            Clip_Height      => Layout.Height,
            Cell             => Item_Rect,
            Line_Height      => Line_Height,
            Modified         => Cells (Files.Types.Modified_Column),
            Size             => Cells (Files.Types.Size_Column),
            Filetype         => Cells (Files.Types.Filetype_Column),
            Created          => Cells (Files.Types.Created_Column),
            Permissions      => Cells (Files.Types.Permissions_Column),
            Modified_Tooltip =>
              (if Hovered and then Item.Modified_Available
               then To_Unbounded_String (Full_Time_Text (Item.Modified_Time))
               else Null_Unbounded_String),
            --  A hidden column has no width, where Draw_Details_Row draws
            --  neither its text nor its tooltip.
            Created_Tooltip  =>
              (if Hovered and then Item.Creation_Available
               then To_Unbounded_String (Full_Time_Text (Item.Creation_Time))
               else Null_Unbounded_String),
            Dim              => Item.Cut_Pending,
            Value_Color      => Text_Color,
            Dim_Color        => Disabled_Text_Color,
            Border_Color     => Border_Color);
      end Draw_Details_Columns;

      --  The Details row's cell texts for the columns shown, empty for the
      --  hidden ones and in the icon views.
      function Detail_Cells return Detail_Column_Texts is
         Shown  : Files.Types.Detail_Column_Visibility renames Snapshot.Detail_Columns_Visible;
         Result : Detail_Column_Texts := [others => Null_Unbounded_String];
      begin
         if not Details then
            return Result;
         end if;
         if Shown (Files.Types.Modified_Column) then
            Result (Files.Types.Modified_Column) :=
              Detail_Time_Text (Item.Modified_Available, Item.Modified_Time, Snapshot.Now);
         end if;
         if Shown (Files.Types.Size_Column) then
            Result (Files.Types.Size_Column) := Detail_Size_Text (Item);
         end if;
         if Shown (Files.Types.Filetype_Column) then
            Result (Files.Types.Filetype_Column) := Item.Filetype_Detail;
         end if;
         if Shown (Files.Types.Created_Column) then
            Result (Files.Types.Created_Column) :=
              Detail_Time_Text (Item.Creation_Available, Item.Creation_Time, Snapshot.Now);
         end if;
         if Shown (Files.Types.Permissions_Column) then
            Result (Files.Types.Permissions_Column) := Item.Permissions;
         end if;
         return Result;
      end Detail_Cells;

      --  The item's accessibility node: a table row in Details, else a list
      --  item; focused when it is the primary selection and the keyboard is
      --  on the grid.
      procedure Add_Item_Accessibility (Cells : Detail_Column_Texts) is
      begin
         Add_Accessibility_Node
           ((if Details then Role_Table_Row else Role_List_Item),
            Item_Rect.X,
            Item_Rect.Y,
            Item_Rect.Width,
            Item_Rect.Height,
            Item.Name,
            Item_Accessible_Description
              (Detail_Column_Labels, Cells, Snapshot.Detail_Column_Order, Snapshot.Detail_Columns_Visible,
               Item, Details),
            Enabled  => True,
            Selected => Item.Selected,
            Focused  =>
              Item.Selected
              and then Snapshot.Focus = Files.UI_Types.Focus_None
              and then not Snapshot.Tree_Keyboard_Active
              and then not Snapshot.Tree_Pick_Active
              and then Item.Visible_Index =
                Snapshot.Primary_Selected_Visible_Index);
      end Add_Item_Accessibility;
   begin
      --  Layout marks off-screen items with Height = 0 (Details rows that
      --  fall outside the scrolled viewport and icon cells past the
      --  bottom). Skip them so we don't pay per-item draw/accessibility
      --  cost for hundreds of invisible rows.
      if Item_Rect.Height = 0 or else Item_Rect.Width = 0 then
         return;
      elsif Item.Is_Group_Header then
         Draw_Group_Header;
         return;
      end if;

      declare
         --  No hover while an overlay (the context menu, Quick Look, a paste
         --  dialog, ...) is open: Has_Hover is then off for the main view,
         --  so the cell under the cursor does not light up under it.
         Hovered   : constant Boolean :=
           Has_Hover
           and then Contains_Point
             (Item_Rect.X, Item_Rect.Y, Item_Rect.Width, Item_Rect.Height, Hover_X, Hover_Y);
         Drop_Target : constant Boolean :=
           Has_Drag
           and then Drag_Item_Index /= 0
           and then Item.Visible_Index /= Drag_Item_Index
           and then Item.Kind = Files.Types.Directory_Item
           and then Hovered;
         --  The Details row's cells, each formatted once for both the row and
         --  its accessibility description, and only for a shown column: the
         --  icon views draw none of them.
         Cells : constant Detail_Column_Texts := Detail_Cells;
      begin
         Draw_Background (Hovered, Drop_Target);
         Draw_Icon;
         Draw_Name;
         if Details then
            Draw_Details_Columns (Hovered, Cells);
         end if;
         Add_Item_Accessibility (Cells);
      end;
   end Draw_Item;
