separate (Files.Events.Translate_Click)
--  The main view: details header, items, and the empty-space marquee.
procedure Main_View_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   --  A press on a header separator begins a column resize and takes
   --  precedence over the sort click on the header cell behind it.
   declare
      Separator : constant Files.Rendering.Detail_Column_Separator :=
        Files.Rendering.Details_Header_Separator_At (Snapshot, Layout, X, Y, Line_Height);
   begin
      if Separator.Present then
         Result :=
           Column_Resize_Begin_Action
             (Separator.Column, Separator.Origin_X, Separator.Width);
         return;
      end if;
   end;

   --  A press on a header cell body either begins a column-reorder drag (for
   --  the optional columns) or, for the mandatory name column, sorts on the
   --  spot. The reorder-begin arms shell-owned drag state: the shell sorts on
   --  release when the press never crossed the drag threshold, so a reorder
   --  drag never also fires a sort click.
   declare
      Cell : constant Files.Rendering.Detail_Header_Cell :=
        Files.Rendering.Details_Header_Cell_At (Snapshot, Layout, X, Y, Line_Height);
   begin
      if Cell.Present then
         if Cell.Column in Files.Types.Optional_Detail_Column then
            Result := Column_Reorder_Begin_Action (Cell.Column, X, Cell.Command);
            return;
         elsif Cell.Command /= Files.Commands.No_Command then
            Result := Command_Action (Cell.Command, Activate);
            return;
         end if;
      end if;
   end;

   Item_Index := Files.Rendering.Item_At (Item_Layout, X, Y);
   if Item_Index /= 0 then
      if Snapshot.Rename_Active
        and then Item_Index <= Natural (Snapshot.Items.Length)
        and then Snapshot.Items.Element (Positive (Item_Index)).Renaming
      then
         declare
            Item_Rect : constant Files.Rendering.Item_Layout :=
              Item_Layout.Element (Positive (Item_Index));
            Snapshot_Item : constant Files.Rendering.Item_Snapshot :=
              Snapshot.Items.Element (Positive (Item_Index));
            Field_X : Natural;
            Field_W : Natural;
         begin
            Files.Rendering.Rename_Field_Extent
              (Item      => Item_Rect,
               View_Mode => Snapshot.View_Mode,
               Renaming  => True,
               Field_X   => Field_X,
               Field_W   => Field_W);
            if Within (X, Field_X, Field_W) then
               Result :=
                 Text_Click
                   (Files.Types.Focus_Rename_Input,
                    Cursor_At
                      (Text        => Snapshot_Item.Rename_Value,
                       Text_X      => Field_X,
                       Click_X     => X),
                    Item_Index);
               return;
            end if;
         end;
      end if;

      Result :=
        (Kind            => Item_Click_Input_Action,
         Command         => Files.Commands.No_Command,
         Direction       => Guikit.Input.Move_Right,
         Item_Index      => Item_Index,
         Root_Index      => 0,
         Result_Index    => 0,
         Click_X          => 0,
         Click_Y          => 0,
         Scroll_Lines    => 0,
         Scroll_Area     => Scroll_Auto,
         Focus_Target    => Files.Types.Focus_None,
         Cursor_Position => 0,
         Settings_Field  => 0,
         Settings_Option => 0,
         Activate        => Activate,
         Toggle_Selection =>
           Modifiers (Guikit.Input.Control_Key)
             and then not Modifiers (Guikit.Input.Shift_Key),
         Range_Selection  => Modifiers (Guikit.Input.Shift_Key),
         Scroll_Drag_Anchor => 0);
      return;
   end if;

   --  A press that reached here landed on empty main-grid space: every
   --  overlay, panel, toolbar/bottom-bar command, scrollbar, details header
   --  cell, and item hit-test above already returned. When it is inside the
   --  main view (and no bottom-bar sort menu is open, whose stray outside
   --  click still falls through here) it begins a rubber-band marquee whose
   --  origin and additive flag the shell tracks per frame; a press that never
   --  drags leaves the selection untouched, preserving the empty-click no-op.
   if not Snapshot.Sort_Menu_Open
     and then Within (X, Layout.Main_X, Layout.Main_Width)
     and then Within (Y, Layout.Main_Y, Layout.Main_Height)
   then
      Result :=
        Marquee_Begin_Action
          (Origin_X => X,
           Origin_Y => Y,
           Additive =>
             Modifiers (Guikit.Input.Control_Key)
             or else Modifiers (Guikit.Input.Shift_Key));
      return;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Main_View_Click;
