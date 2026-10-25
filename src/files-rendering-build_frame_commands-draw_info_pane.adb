separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Info_Pane is
   begin
      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (2, Info_Pane.Height),
            Border_Color);
         Add_Accessibility_Node
           (Role_Pane,
            Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Info_Pane.Height,
            Localized ("accessibility.info_pane"),
            (if Snapshot.Selected_Info.Is_Empty
             then Localized ("error.selection.empty")
             else Null_Unbounded_String));
         declare
            --  The combined selection total is rendered as the last line of the
            --  Contents section (see Coalesced_Info_Sections), so no header rows
            --  are reserved above the list.
            Section_Offset_Rows : Natural := 0;
         begin

            if Snapshot.Selected_Info.Is_Empty then
               declare
                  Text_Y : constant Natural :=
                    Saturating_Add (Info_Pane.Y, Info_Pane_Padding);
                  Info_Bottom : constant Natural :=
                    Saturating_Add (Info_Pane.Y, Info_Pane.Height);
               begin
                  if Text_Y < Info_Bottom then
                     Add_Text
                       (Saturating_Add (Info_Pane.X, Info_Pane_Padding),
                        Text_Y,
                        Info_Text_Width (Layout, Scrollbar_W => 0),
                        Natural'Min (Line_Height, Info_Bottom - Text_Y),
                        Localized ("error.selection.empty"),
                        Muted_Text_Color,
                        Fit => True);
                  end if;
               end;
            end if;

            if Natural (Snapshot.Selected_Info.Length) >= 2 then
               declare
                  --  Sections start at the top of the pane: the combined total is
                  --  now the Contents section's last line, not a reserved header.
                  Base_Y : constant Integer :=
                    Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding));
                  Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
                  Text_X : constant Natural := Saturating_Add (Layout.Main_Width, Info_Pane_Padding);
                  Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
                  Reserved_W : constant Natural :=
                    Saturating_Add
                      ((if Info_Pane.Scrollbar_Visible then Info_Pane.Scrollbar_Width else 0),
                       Saturating_Multiply (Info_Pane_Padding, 2));
                  Text_W : constant Natural :=
                    (if Layout.Info_Pane_Width > Reserved_W
                     then Layout.Info_Pane_Width - Reserved_W
                     else 0);
                  Sections : constant Coalesced_Section_Vectors.Vector :=
                    Coalesced_Info_Sections (Snapshot);
                  Current_Row : Natural := 0;

                  procedure Add_Info_Text
                    (Offset : Natural;
                     Text   : UString;
                     Color  : Render_Color := Text_Color;
                     Fit    : Boolean := True)
                  is
                     Y : constant Integer :=
                       Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
                  begin
                     if Y >= Integer (Info_Pane.Y)
                       and then Y < Integer (Info_Bottom)
                     then
                        Add_Text
                          (Text_X,
                           Natural (Y),
                           Text_W,
                           Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                           Text,
                           Color,
                           Fit => Fit);
                     end if;
                  end Add_Info_Text;

                  procedure Add_Info_Label
                    (Row : Natural;
                     Key : String)
                  is
                     Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
                  begin
                     Add_Info_Text (Row, Text, Text_Color);
                     if Text_W > 1 then
                        declare
                           Y : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                        begin
                           if Y >= Integer (Info_Pane.Y)
                             and then Y < Integer (Info_Bottom)
                           then
                              Add_Text
                                (Saturating_Add (Text_X, 1),
                                 Natural (Y),
                                 Text_W - 1,
                                 Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                                 Text,
                                 Text_Color,
                                 Fit => True);
                           end if;
                        end;
                     end if;

                     --  A "<key>.tooltip" catalog entry, when present, describes
                     --  the section on hover.
                     declare
                        Tip_Key : constant String := Key & ".tooltip";
                        Tip_Y   : constant Integer :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                     begin
                        if Text_W > 0
                          and then Tip_Y >= Integer (Info_Pane.Y)
                          and then Tip_Y < Integer (Info_Bottom)
                          and then Files.Localization.Text (Tip_Key) /= Tip_Key
                        then
                           Add_Tooltip
                             (Text_X,
                              Natural (Tip_Y),
                              Text_W,
                              Natural'Min (Line_Height, Info_Bottom - Natural (Tip_Y)),
                              Tip_Key);
                        end if;
                     end;
                  end Add_Info_Label;

                  procedure Add_Info_Wrapped_Value
                    (Row   : Natural;
                     Text  : UString;
                     Color : Render_Color := Text_Color)
                  is
                     Raw        : constant String := To_String (Text);
                     Cell_W     : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                     Capacity   : constant Natural := Text_W / Cell_W;
                     Line_Index : Natural := 0;

                     procedure Add_Wrapped_Segment
                       (Segment_First : Integer;
                        Segment_Last  : Integer)
                     is
                        Start : Integer := Segment_First;
                     begin
                        if Segment_Last < Segment_First then
                           Line_Index := Saturating_Add (Line_Index, 1);
                           return;
                        end if;

                        Start := Skip_Wrap_Whitespace (Raw, Start, Segment_Last);
                        while Start <= Segment_Last loop
                           declare
                              Last   : constant Integer :=
                                Wrapped_Line_Last (Raw, Start, Segment_Last, Capacity);
                           begin
                              Add_Info_Text
                                (Saturating_Add (Row, Line_Index),
                                 To_Unbounded_String (Raw (Start .. Last)),
                                 Color,
                                 Fit => False);
                              exit when Last >= Segment_Last;
                              Start := Skip_Wrap_Whitespace (Raw, Last + 1, Segment_Last);
                              Line_Index := Saturating_Add (Line_Index, 1);
                           end;
                        end loop;

                        Line_Index := Saturating_Add (Line_Index, 1);
                     end Add_Wrapped_Segment;

                     Line_First : Integer := Raw'First;
                  begin
                     if Raw'Length = 0 or else Capacity = 0 then
                        Add_Info_Text (Row, Text, Color, Fit => False);
                        return;
                     end if;

                     for Position in Raw'Range loop
                        if Raw (Position) = ASCII.LF then
                           Add_Wrapped_Segment (Line_First, Position - 1);
                           Line_First := Position + 1;
                        end if;
                     end loop;

                     if Line_First <= Raw'Last then
                        Add_Wrapped_Segment (Line_First, Raw'Last);
                     elsif Raw (Raw'Last) = ASCII.LF then
                        Add_Info_Text (Saturating_Add (Row, Line_Index), Null_Unbounded_String, Color, Fit => False);
                     end if;
                  end Add_Info_Wrapped_Value;
               begin
                  --  Field-major coalesced layout: each section's label once,
                  --  then one value row per selected item (see Coalesced_Info_Rows
                  --  for the matching row accounting).
                  for Section of Sections loop
                     Add_Info_Label (Current_Row, To_String (Section.Key));
                     Current_Row := Saturating_Add (Current_Row, 1);
                     for Value of Section.Values loop
                        Add_Info_Wrapped_Value (Current_Row, Value);
                        Current_Row :=
                          Saturating_Add (Current_Row, Wrapped_Line_Count (Value, Text_W, Line_Height));
                     end loop;
                     Current_Row := Saturating_Add (Current_Row, 1);
                  end loop;

                  --  One accessibility node per item, anchored at its value row in
                  --  the first rendered section (values start one row below its
                  --  label). Advance by that section's per-item wrapped height.
                  if not Sections.Is_Empty then
                     declare
                        First : constant Coalesced_Section := Sections.First_Element;
                        Item_Row : Natural := 1;
                        Item_Index : Positive := 1;
                     begin
                        for Info of Snapshot.Selected_Info loop
                           declare
                              Y : constant Integer :=
                                Saturating_Integer_Add (Row_Y, Saturating_Multiply (Item_Row, Line_Height));
                              Visible_Y : constant Integer := Integer'Max (Y, Integer (Info_Pane.Y));
                              Description : constant Unbounded_String :=
                                To_Unbounded_String
                                  (Files.Localization.Text ("info.filetype") & ": " &
                                   To_String (Info_Field_Value (Info, Info_Filetype)) & ", " &
                                   Files.Localization.Text ("info.size") & ": " &
                                   To_String (Info_Field_Value (Info, Info_Size)));
                           begin
                              if Y >= Integer (Info_Pane.Y)
                                and then Y < Integer (Info_Bottom)
                                and then Text_W > 0
                              then
                                 Add_Accessibility_Node
                                   (Role_List_Item,
                                    Info_Pane.X,
                                    Natural (Visible_Y),
                                    Text_W,
                                    Natural'Min
                                      (Line_Height, Info_Bottom - Natural (Visible_Y)),
                                    Info.Name,
                                    Description);
                              end if;
                              Item_Row :=
                                Saturating_Add
                                  (Item_Row,
                                   Wrapped_Line_Count (First.Values.Element (Item_Index), Text_W, Line_Height));
                              Item_Index := Item_Index + 1;
                           end;
                        end loop;
                     end;
                  end if;
               end;
            else
               for Index in 1 .. Natural (Snapshot.Selected_Info.Length) loop
                  declare
                     Info   : constant Info_Snapshot := Snapshot.Selected_Info.Element (Positive (Index));
                     Section_Offset : constant Natural := Saturating_Multiply (Section_Offset_Rows, Line_Height);
                     Base_Y : constant Integer :=
                       Saturating_Integer_Add
                         (Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding)), Section_Offset);
                     Row_Y  : constant Integer := Base_Y - Integer (Info_Pane.Scroll_Pixels);
                     Text_X : constant Natural := Saturating_Add (Layout.Main_Width, Info_Pane_Padding);
                     Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
                     Reserved_W : constant Natural :=
                       Saturating_Add
                         ((if Info_Pane.Scrollbar_Visible then Info_Pane.Scrollbar_Width else 0),
                          Saturating_Multiply (Info_Pane_Padding, 2));
                     Text_W : constant Natural :=
                       (if Layout.Info_Pane_Width > Reserved_W
                        then Layout.Info_Pane_Width - Reserved_W
                        else 0);

                     procedure Add_Info_Text
                       (Offset : Natural;
                        Text   : UString;
                        Color  : Render_Color := Text_Color;
                        Fit    : Boolean := True)
                     is
                        Y : constant Integer :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Offset, Line_Height));
                     begin
                        if Y >= Integer (Info_Pane.Y)
                          and then Y < Integer (Info_Bottom)
                        then
                           Add_Text
                             (Text_X,
                              Natural (Y),
                              Text_W,
                              Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                              Text,
                              Color,
                              Fit => Fit);
                        end if;
                     end Add_Info_Text;

                     procedure Add_Info_Label
                       (Row : Natural;
                        Key : String)
                     is
                        Text : constant UString := To_Unbounded_String (Files.Localization.Text (Key));
                     begin
                        Add_Info_Text (Row, Text, Text_Color);
                        if Text_W > 1 then
                           declare
                              Y : constant Integer :=
                                Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                           begin
                              if Y >= Integer (Info_Pane.Y)
                                and then Y < Integer (Info_Bottom)
                              then
                                 Add_Text
                                   (Saturating_Add (Text_X, 1),
                                    Natural (Y),
                                    Text_W - 1,
                                    Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                                    Text,
                                    Text_Color,
                                    Fit => True);
                              end if;
                           end;
                        end if;

                        --  A "<key>.tooltip" catalog entry, when present, describes
                        --  the section on hover.
                        declare
                           Tip_Key : constant String := Key & ".tooltip";
                           Tip_Y   : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Row, Line_Height));
                        begin
                           if Text_W > 0
                             and then Tip_Y >= Integer (Info_Pane.Y)
                             and then Tip_Y < Integer (Info_Bottom)
                             and then Files.Localization.Text (Tip_Key) /= Tip_Key
                           then
                              Add_Tooltip
                                (Text_X,
                                 Natural (Tip_Y),
                                 Text_W,
                                 Natural'Min (Line_Height, Info_Bottom - Natural (Tip_Y)),
                                 Tip_Key);
                           end if;
                        end;
                     end Add_Info_Label;

                     procedure Add_Info_Wrapped_Value
                       (Row   : Natural;
                        Text  : UString;
                        Color : Render_Color := Text_Color)
                     is
                        Raw        : constant String := To_String (Text);
                        Cell_W     : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                        Capacity   : constant Natural := Text_W / Cell_W;
                        Line_Index : Natural := 0;

                        procedure Add_Wrapped_Segment
                          (Segment_First : Integer;
                           Segment_Last  : Integer)
                        is
                           Start : Integer := Segment_First;
                        begin
                           if Segment_Last < Segment_First then
                              Line_Index := Saturating_Add (Line_Index, 1);
                              return;
                           end if;

                           Start := Skip_Wrap_Whitespace (Raw, Start, Segment_Last);
                           while Start <= Segment_Last loop
                              declare
                                 Last   : constant Integer :=
                                   Wrapped_Line_Last (Raw, Start, Segment_Last, Capacity);
                              begin
                                 Add_Info_Text
                                   (Saturating_Add (Row, Line_Index),
                                    To_Unbounded_String (Raw (Start .. Last)),
                                    Color,
                                    Fit => False);
                                 exit when Last >= Segment_Last;
                                 Start := Skip_Wrap_Whitespace (Raw, Last + 1, Segment_Last);
                                 Line_Index := Saturating_Add (Line_Index, 1);
                              end;
                           end loop;

                           Line_Index := Saturating_Add (Line_Index, 1);
                        end Add_Wrapped_Segment;

                        Line_First : Integer := Raw'First;
                     begin
                        if Raw'Length = 0 or else Capacity = 0 then
                           Add_Info_Text (Row, Text, Color, Fit => False);
                           return;
                        end if;

                        for Position in Raw'Range loop
                           if Raw (Position) = ASCII.LF then
                              Add_Wrapped_Segment (Line_First, Position - 1);
                              Line_First := Position + 1;
                           end if;
                        end loop;

                        if Line_First <= Raw'Last then
                           Add_Wrapped_Segment (Line_First, Raw'Last);
                        elsif Raw (Raw'Last) = ASCII.LF then
                           Add_Info_Text (Saturating_Add (Row, Line_Index), Null_Unbounded_String, Color, Fit => False);
                        end if;
                     end Add_Info_Wrapped_Value;

                     Current_Row : Natural := 0;

                     procedure Add_Info_Heading is
                        Y : constant Integer :=
                          Saturating_Integer_Add
                            (Row_Y, Saturating_Multiply (Current_Row, Line_Height));
                     begin
                        Add_Info_Text (Current_Row, Info.Name, Text_Color, Fit => True);
                        if Text_W > 1
                          and then Y >= Integer (Info_Pane.Y)
                          and then Y < Integer (Info_Bottom)
                        then
                           Add_Text
                             (Saturating_Add (Text_X, 1),
                              Natural (Y),
                              Text_W - 1,
                              Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                              Info.Name,
                              Text_Color,
                              Fit => True);
                        end if;
                        Current_Row := Saturating_Add (Current_Row, 2);
                     end Add_Info_Heading;

                     procedure Add_Info_Field
                       (Field : Info_Section_Field;
                        Color : Render_Color := Text_Color)
                     is
                        Display_Value : constant UString := Info_Field_Display_Value (Info, Field);
                        Value_Rows : constant Natural := Wrapped_Line_Count (Display_Value, Text_W, Line_Height);
                     begin
                        Add_Info_Label (Current_Row, Info_Field_Label_Key (Field));
                        Current_Row := Saturating_Add (Current_Row, 1);
                        Add_Info_Wrapped_Value (Current_Row, Display_Value, Color);
                        Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                     end Add_Info_Field;

                     --  Draw the permissions matrix: a "Permissions" label, an
                     --  R/W/E column header, a 3x3 rwx grid (rows user/group/other,
                     --  columns read/write/execute) with a per-row label, and -- when
                     --  editable -- one click hit region per cell. Cell index Bit
                     --  maps to POSIX mode bit 2 ** (8 - Bit); a filled cell is set.
                     procedure Add_Permission_Grid is
                        Cell : constant Natural := Natural'Max (6, Line_Height - 6);
                        Gap  : constant Natural := Natural'Max (2, Line_Height / 6);
                        --  Approximate glyph advance, used to horizontally centre a
                        --  header letter over its column.
                        Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                        --  The glyph box is ~4/5 of the line height and sits at the
                        --  bottom of the row (the leading is above it), so centre the
                        --  cell square within that font box -- not the whole line --
                        --  to line it up with the row label text.
                        Font_H : constant Natural := Saturating_Multiply (Line_Height, 4) / 5;
                        Cell_Top : constant Natural :=
                          (if 2 * Line_Height > Font_H + Cell then Line_Height - (Font_H + Cell) / 2 + 1 else 0);
                        --  Horizontal inset that centres a header letter over a cell.
                        Header_Pad : constant Natural := (if Cell > Char_W then (Cell - Char_W) / 2 else 0);
                        --  The row labels sit just past the three columns.
                        Labels_X : constant Natural :=
                          Saturating_Add
                            (Text_X, Saturating_Add (Saturating_Multiply (3, Cell + Gap), Gap));
                        Labels_W : constant Natural :=
                          (if Text_W > Labels_X - Text_X then Text_W - (Labels_X - Text_X) else 0);

                        --  Draw a clipped label/glyph at a section-row offset.
                        procedure Add_At (X : Natural; Section_Row : Natural; Width : Natural; Text : String) is
                           Y : constant Integer :=
                             Saturating_Integer_Add (Row_Y, Saturating_Multiply (Section_Row, Line_Height));
                        begin
                           if Width > 0
                             and then Y >= Integer (Info_Pane.Y)
                             and then Y < Integer (Info_Bottom)
                           then
                              Add_Text
                                (X,
                                 Natural (Y),
                                 Width,
                                 Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
                                 To_Unbounded_String (Text), Muted_Text_Color, Fit => True);
                           end if;
                        end Add_At;

                        Column_Header : constant array (0 .. 2) of Character := ('R', 'W', 'E');

                        function Row_Label_Key (Row : Natural) return String is
                          (case Row is
                              when 0      => "info.permissions.user",
                              when 1      => "info.permissions.group",
                              when others => "info.permissions.other");
                     begin
                        Add_Info_Label (Current_Row, Info_Field_Label_Key (Info_Permissions));

                        --  R/W/E header, one letter centred over each column.
                        for Col in 0 .. 2 loop
                           Add_At
                             (Saturating_Add
                                (Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap)), Header_Pad),
                              Current_Row + 1, Char_W, [1 => Column_Header (Col)]);
                        end loop;

                        for Bit in 0 .. 8 loop
                           declare
                              Col   : constant Natural := Bit mod 3;
                              Row   : constant Natural := Bit / 3;
                              Cell_X : constant Natural :=
                                Saturating_Add (Text_X, Saturating_Multiply (Col, Cell + Gap));
                              Cell_Y : constant Integer :=
                                Saturating_Integer_Add
                                  (Saturating_Integer_Add
                                     (Row_Y,
                                      Saturating_Multiply (Saturating_Add (Current_Row + 2, Row), Line_Height)),
                                   Cell_Top);
                              Is_Set : constant Boolean :=
                                (Info.Mode_Bits / (2 ** (8 - Bit))) mod 2 = 1;
                           begin
                              if Cell_Y >= Integer (Info_Pane.Y)
                                and then Cell_Y + Integer (Cell) <= Integer (Info_Bottom)
                              then
                                 Add_Rect (Cell_X, Natural (Cell_Y), Cell, Cell, Border_Color);
                                 if Cell > 2 then
                                    Add_Rect
                                      (Saturating_Add (Cell_X, 1),
                                       Natural (Cell_Y) + 1,
                                       Cell - 2,
                                       Cell - 2,
                                       (if Is_Set then Selection_Color else Input_Color));
                                 end if;
                                 if Snapshot.Permissions_Editable then
                                    Result.Permission_Hits.Append
                                      (Permission_Hit_Region'
                                         (Present => True,
                                          Bit     => Bit,
                                          X       => Cell_X,
                                          Y       => Natural (Cell_Y),
                                          Width   => Cell,
                                          Height  => Cell));
                                 end if;
                              end if;
                           end;
                        end loop;

                        --  Per-row labels: user / group / other.
                        for Row in 0 .. 2 loop
                           Add_At
                             (Labels_X, Current_Row + 2 + Row, Labels_W,
                              Files.Localization.Text (Row_Label_Key (Row)));
                        end loop;

                        Current_Row := Saturating_Add (Current_Row, Permission_Grid_Rows);
                     end Add_Permission_Grid;

                     --  Draw an editable owner or group value and register one
                     --  click hit region over it. While editing, the value shows
                     --  the editor buffer with an underline and a text caret.
                     procedure Add_Ownership_Field
                       (Field   : Info_Section_Field;
                        Editing : Boolean)
                     is
                        Value      : constant UString := Info_Field_Value (Info, Field);
                        Value_Rows : constant Natural := Wrapped_Line_Count (Value, Text_W, Line_Height);
                        Value_Row  : Natural;
                        Cell_Y     : Integer;
                     begin
                        Add_Info_Label (Current_Row, Info_Field_Label_Key (Field));
                        Current_Row := Saturating_Add (Current_Row, 1);
                        Value_Row := Current_Row;
                        Add_Info_Wrapped_Value
                          (Value_Row, Value, (if Editing then Text_Color else Muted_Text_Color));
                        Cell_Y :=
                          Saturating_Integer_Add (Row_Y, Saturating_Multiply (Value_Row, Line_Height));
                        if Cell_Y >= Integer (Info_Pane.Y)
                          and then Cell_Y + Integer (Line_Height) <= Integer (Info_Bottom)
                          and then Text_W > 0
                        then
                           Result.Ownership_Hits.Append
                             (Ownership_Hit_Region'
                                (Present  => True,
                                 Is_Group => Field = Info_Group,
                                 X        => Text_X,
                                 Y        => Natural (Cell_Y),
                                 Width    => Text_W,
                                 Height   => Line_Height));
                           if Editing then
                              Add_Rect
                                (Text_X,
                                 Saturating_Add (Natural (Cell_Y), Line_Height - 1),
                                 Text_W,
                                 1,
                                 Selection_Color);
                              declare
                                 Char_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
                                 Raw     : constant String := To_String (Value);
                                 Caret_X : constant Natural :=
                                   Saturating_Add
                                     (Text_X,
                                      Saturating_Multiply
                                        (Files.UTF8.Display_Units_Before
                                           (Raw, Snapshot.Text_Cursor_Position),
                                         Char_W));
                              begin
                                 Add_Rect
                                   (Caret_X,
                                    Saturating_Add (Natural (Cell_Y), 2),
                                    2,
                                    (if Line_Height > 4 then Line_Height - 4 else Line_Height),
                                    Text_Color);
                              end;
                           end if;
                        end if;
                        Current_Row := Saturating_Add (Current_Row, Saturating_Add (Value_Rows, 1));
                     end Add_Ownership_Field;
                  begin
                     Add_Info_Heading;
                     --  One ordered section list (Info_Section_Field) drives both
                     --  this drawing and Info_Section_Row_Count. Permissions render
                     --  as a labelled matrix (no text summary), clickable only when
                     --  editable (gated inside Add_Permission_Grid); owner and
                     --  group are inline-editable values.
                     for Field in Info_Section_Field loop
                        if Info_Field_Shown (Info, Field) then
                           case Field is
                              when Info_Permissions =>
                                 Add_Permission_Grid;
                              when Info_Owner =>
                                 Add_Ownership_Field (Field, Info.Owner_Editing);
                              when Info_Group =>
                                 Add_Ownership_Field (Field, Info.Group_Editing);
                              when others =>
                                 Add_Info_Field (Field);
                           end case;
                        end if;
                     end loop;
                     declare
                        Section_H : constant Natural :=
                          Natural'Min
                            (Saturating_Multiply
                               (Line_Height,
                                Info_Section_Row_Count (Info, Text_W, Line_Height)),
                             Info_Pane.Height);
                        Visible_Y : constant Integer := Integer'Max (Row_Y, Integer (Info_Pane.Y));
                        Raw_Bottom : constant Integer :=
                          Integer'Min
                            (Saturating_Integer_Add (Row_Y, Section_H),
                             Integer (Info_Bottom));
                        Visible_H : constant Natural :=
                          (if Raw_Bottom > Visible_Y then Natural (Raw_Bottom - Visible_Y) else 0);
                        Size_Text : constant String := To_String (Info_Field_Value (Info, Info_Size));
                        Modified_Text : constant String :=
                          To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified"));
                        Description : Unbounded_String :=
                          To_Unbounded_String
                            (Files.Localization.Text ("info.filetype") & ": " &
                             To_String (Info_Field_Value (Info, Info_Filetype)) & ", " &
                             Files.Localization.Text ("info.size") & ": " &
                             Size_Text & ", " &
                             Modified_Text);
                     begin
                        if Info.Metadata_Error then
                           Append
                             (Description,
                              ", " &
                              Files.Localization.Text ("info.metadata_error") & ": " &
                              Files.Localization.Text (To_String (Info.Error_Key)));
                        end if;

                        if Visible_H > 0 and then Text_W > 0 then
                           Add_Accessibility_Node
                             (Role_List_Item,
                              Info_Pane.X,
                              Natural (Visible_Y),
                              Text_W,
                              Visible_H,
                              Info.Name,
                              Description);
                        end if;
                     end;
                     Section_Offset_Rows :=
                       Saturating_Add
                         (Section_Offset_Rows,
                          Info_Section_Row_Count (Info, Text_W, Line_Height));
                  end;
               end loop;
            end if;
         end;

         if Info_Pane.Scrollbar_Visible then
            Add_Scrollbar
              (Info_Pane.Scrollbar_X,
               Info_Pane.Scrollbar_Y,
               Info_Pane.Scrollbar_Width,
               Info_Pane.Scrollbar_Track_Height,
               Info_Pane.Scrollbar_Thumb_Y,
               Info_Pane.Scrollbar_Height);
         end if;
         --  Keep the close button clear of the scrollbar column on the right.
         Draw_Close_Button
           (Info_Pane.X,
            Info_Pane.Y,
            (if Info_Pane.Scrollbar_Visible and then Info_Pane.Width > Info_Pane.Scrollbar_Width
             then Info_Pane.Width - Info_Pane.Scrollbar_Width
             else Info_Pane.Width),
            Info_Pane.Height,
            Overlay => False);
      end if;
   end Draw_Info_Pane;
