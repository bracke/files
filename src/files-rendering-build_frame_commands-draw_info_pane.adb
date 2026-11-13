separate (Files.Rendering.Build_Frame_Commands)
   procedure Draw_Info_Pane is
   begin
      if Snapshot.Info_Pane_Open then
         Add_Rect
           (Info_Pane.X,
            Info_Pane.Y,
            Info_Pane.Width,
            Natural'Min (Guikit.Layout.Scaled (2, Line_Height), Info_Pane.Height),
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
            --  are reserved above the list: sections start at the top of the pane.
            Row_Y  : constant Integer :=
              Integer (Saturating_Add (Info_Pane.Y, Info_Pane_Padding (Line_Height)))
              - Integer (Info_Pane.Scroll_Pixels);
            Text_X : constant Natural := Saturating_Add (Info_Pane.X, Info_Pane_Padding (Line_Height));
            Info_Bottom : constant Natural := Saturating_Add (Info_Pane.Y, Info_Pane.Height);
            --  The width the layout counted rows at, which always leaves the
            --  scrollbar's column: wrapping wider when it is hidden drew fewer
            --  rows than the pane was sized for.
            Text_W : constant Natural :=
              Info_Text_Width (Layout, Scrollbar_W => Natural'Min (Scrollbar_Width (Layout), Layout.Info_Pane_Width));

            --  What a screen reader hears for an item, in the locale's words
            --  and punctuation: its type and size, then (in the single-item
            --  layout) when it was modified and any metadata error.
            function Info_Description (Info : Info_Snapshot; Full : Boolean) return String is
               function Arg (Name, Value : String) return Files.Localization.Argument is
                 ((To_Unbounded_String (Name), To_Unbounded_String (Value)));
               Summary : constant String :=
                 Files.Localization.Text
                   ("accessibility.info.summary",
                    Files.Localization.Argument_List'
                    [Arg ("type_label", Files.Localization.Text ("info.filetype")),
                     Arg ("type", To_String (Info_Field_Value (Info, Info_Filetype))),
                     Arg ("size_label", Files.Localization.Text ("info.size")),
                     Arg ("size", To_String (Info_Field_Value (Info, Info_Size)))]);
               Modified : constant String :=
                 (if Full
                  then Files.Localization.Text
                    ("accessibility.info.summary_modified",
                     Files.Localization.Argument_List'
                     [Arg ("summary", Summary),
                      Arg ("modified",
                           To_String (Time_Text (Info.Modified_Available, Info.Modified_Time, "info.modified")))])
                  else Summary);
            begin
               if not Full or else not Info.Metadata_Error then
                  return Modified;
               end if;
               return Files.Localization.Text
                 ("accessibility.info.metadata_error",
                  Files.Localization.Argument_List'
                  [Arg ("summary", Modified),
                   Arg ("error_label", Files.Localization.Text ("info.metadata_error")),
                   Arg ("error", Files.Localization.Text (To_String (Info.Error_Key)))]);
            end Info_Description;

            --  Text helpers shared by the multi-item and the single-item layout.
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
               Raw : constant String := To_String (Text);

               procedure Add_Line (Line : Natural; First : Integer; Last : Integer) is
               begin
                  if Last >= First then
                     Add_Info_Text
                       (Saturating_Add (Row, Line), To_Unbounded_String (Raw (First .. Last)), Color, Fit => False);
                  end if;
               end Add_Line;
            begin
               For_Each_Wrapped_Line (Raw, Text_W, Line_Height, Add_Line'Access);
            end Add_Info_Wrapped_Value;
         begin

            if Snapshot.Selected_Info.Is_Empty then
               declare
                  Text_Y : constant Natural :=
                    Saturating_Add (Info_Pane.Y, Info_Pane_Padding (Line_Height));
               begin
                  if Text_Y < Info_Bottom then
                     Add_Text
                       (Saturating_Add (Info_Pane.X, Info_Pane_Padding (Line_Height)),
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
                  Sections : constant Coalesced_Section_Vectors.Vector :=
                    Coalesced_Info_Sections (Snapshot);
                  Current_Row : Natural := 0;
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
                                To_Unbounded_String (Info_Description (Info, Full => False));
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
                        Cell_Inset : constant Natural := Guikit.Layout.Scaled (6, Line_Height);
                        Cell : constant Natural :=
                          Natural'Max (Cell_Inset, (if Line_Height > Cell_Inset then Line_Height - Cell_Inset else 0));
                        Gap  : constant Natural := Natural'Max (Guikit.Layout.Scaled (2, Line_Height), Line_Height / 6);
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
                        Header_Pad : constant Natural := Centered (Cell, Char_W);
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
                                        (Guikit.Utf8.Display_Units_Before
                                           (Raw, Snapshot.Text_Cursor_Position),
                                         Char_W));
                              begin
                                 --  A 2 px stroke, inset from the row by a
                                 --  scaled margin above and below.
                                 Add_Rect
                                   (Caret_X,
                                    Saturating_Add (Natural (Cell_Y), Guikit.Layout.Scaled (2, Line_Height)),
                                    2,
                                    (if Line_Height > Guikit.Layout.Scaled (4, Line_Height)
                                     then Line_Height - Guikit.Layout.Scaled (4, Line_Height)
                                     else Line_Height),
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
                        Description : constant Unbounded_String :=
                          To_Unbounded_String (Info_Description (Info, Full => True));
                     begin
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
