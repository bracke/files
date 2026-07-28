separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Hover_Tooltip is
      Padding     : constant Natural := 6;
      --  Even inset on every side; the vertical inset is derived so the box
      --  is comfortably taller than the text with matching top/bottom bands.
      Padding_V   : constant Natural := Natural'Max (Padding, Line_Height / 3 + 2);
      Margin      : constant Natural := 4;
      Horizontal_Gap : constant Natural := 12;
      Vertical_Gap   : constant Natural := 18;
      Text        : constant UString := Tooltip_At (Hover_X, Hover_Y);
      Text_Raw    : constant String := To_String (Text);
      Text_Len    : constant Natural := Files.UTF8.Display_Units (Text_Raw);
      Cell_W      : constant Natural := Natural'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
      Max_Tip_W   : constant Natural :=
        (if Width > 2 * Margin then Width - 2 * Margin else Width);
      Raw_Text_W  : constant Natural := Saturating_Multiply (Text_Len, Cell_W);
      Text_W      : constant Natural :=
        (if Max_Tip_W > 2 * Padding
         then Natural'Min (Raw_Text_W, Max_Tip_W - 2 * Padding)
         else 0);

      --  Greedily wrap Raw at whitespace so each row fits in Cap cells; a
      --  token wider than Cap is hard-split. Rows are joined with LF and
      --  whitespace runs collapse — tooltip text is a single logical line.
      function Wrap_Words (Raw : String; Cap : Positive) return String is
         Out_Str   : UString := Null_Unbounded_String;
         Have_Line : Boolean := False;
         Cur       : UString := Null_Unbounded_String;
         Cur_Units : Natural := 0;

         procedure Flush is
         begin
            if Have_Line then
               Append (Out_Str, ASCII.LF);
            end if;
            Append (Out_Str, Cur);
            Have_Line := True;
            Cur := Null_Unbounded_String;
            Cur_Units := 0;
         end Flush;

         procedure Add_Word (Word : String) is
            Word_Units : constant Natural := Files.UTF8.Display_Units (Word);
         begin
            if Word_Units = 0 then
               return;
            elsif Word_Units > Cap then
               --  Longer than a whole row: flush, then hard-split the token.
               if Cur_Units > 0 then
                  Flush;
               end if;
               declare
                  Pos : Integer := Word'First;
               begin
                  while Pos <= Word'Last loop
                     declare
                        Piece : constant String :=
                          Files.UTF8.Prefix_By_Units (Word (Pos .. Word'Last), Cap);
                        Stop  : constant Integer :=
                          (if Piece'Length = 0 then Word'Last else Pos + Piece'Length - 1);
                     begin
                        Cur := To_Unbounded_String (Word (Pos .. Stop));
                        Cur_Units := Files.UTF8.Display_Units (Word (Pos .. Stop));
                        exit when Stop >= Word'Last;
                        Flush;
                        Pos := Stop + 1;
                     end;
                  end loop;
               end;
            elsif Cur_Units = 0 then
               Cur := To_Unbounded_String (Word);
               Cur_Units := Word_Units;
            elsif Cur_Units + 1 + Word_Units <= Cap then
               Append (Cur, ' ');
               Append (Cur, Word);
               Cur_Units := Cur_Units + 1 + Word_Units;
            else
               Flush;
               Cur := To_Unbounded_String (Word);
               Cur_Units := Word_Units;
            end if;
         end Add_Word;

         Word_First : Integer := Raw'First;
         In_Word    : Boolean := False;
      begin
         for Pos in Raw'Range loop
            if Raw (Pos) = ' ' or else Raw (Pos) = ASCII.LF
              or else Raw (Pos) = ASCII.CR or else Raw (Pos) = ASCII.HT
            then
               if In_Word then
                  Add_Word (Raw (Word_First .. Pos - 1));
                  In_Word := False;
               end if;
            elsif not In_Word then
               Word_First := Pos;
               In_Word := True;
            end if;
         end loop;
         if In_Word then
            Add_Word (Raw (Word_First .. Raw'Last));
         end if;
         if Cur_Units > 0 or else not Have_Line then
            Flush;
         end if;
         return To_String (Out_Str);
      end Wrap_Words;

      --  Row count of an LF-joined block.
      function Line_Count (Block : String) return Positive is
         Count : Positive := 1;
      begin
         for Ch of Block loop
            if Ch = ASCII.LF then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Line_Count;

      --  Display width of the widest row in an LF-joined block.
      function Longest_Line_Units (Block : String) return Natural is
         Best  : Natural := 0;
         First : Integer := Block'First;

         procedure Consider (A, B : Integer) is
            Units : constant Natural :=
              (if B < A then 0 else Files.UTF8.Display_Units (Block (A .. B)));
         begin
            if Units > Best then
               Best := Units;
            end if;
         end Consider;
      begin
         for Pos in Block'Range loop
            if Block (Pos) = ASCII.LF then
               Consider (First, Pos - 1);
               First := Pos + 1;
            end if;
         end loop;
         Consider (First, Block'Last);
         return Best;
      end Longest_Line_Units;

      --  Wrap once; the box height and width and the drawn rows all derive
      --  from this single wrapped block so they cannot disagree.
      Capacity    : constant Natural := Text_W / Cell_W;
      Wrapped     : constant String :=
        (if Capacity = 0 then Text_Raw else Wrap_Words (Text_Raw, Capacity));
      Row_Count   : constant Positive := Line_Count (Wrapped);
      Line_Units  : constant Natural := Longest_Line_Units (Wrapped);
      Draw_Text_W : constant Natural :=
        (if Capacity > 0 and then Line_Units > 0
         then Saturating_Multiply (Line_Units, Cell_W) else Text_W);
      Tip_W       : constant Natural := Saturating_Add (Draw_Text_W, 2 * Padding);
      Tip_H       : constant Natural :=
        Saturating_Add (Saturating_Multiply (Row_Count, Line_Height), 2 * Padding_V);

      function Fits_Right return Boolean is
      begin
         return
           Width > Margin
           and then Hover_X <= Natural'Last - Horizontal_Gap
           and then Saturating_Add (Hover_X, Horizontal_Gap) <= Natural'Last - Tip_W
           and then Saturating_Add (Saturating_Add (Hover_X, Horizontal_Gap), Tip_W) <= Width - Margin;
      end Fits_Right;

      function Fits_Left return Boolean is
      begin
         return Hover_X >= Saturating_Add (Saturating_Add (Tip_W, Horizontal_Gap), Margin);
      end Fits_Left;

      function Fits_Below return Boolean is
      begin
         return
           Height > Margin
           and then Hover_Y <= Natural'Last - Vertical_Gap
           and then Saturating_Add (Hover_Y, Vertical_Gap) <= Natural'Last - Tip_H
           and then Saturating_Add (Saturating_Add (Hover_Y, Vertical_Gap), Tip_H) <= Height - Margin;
      end Fits_Below;

      function Fits_Above return Boolean is
      begin
         return Hover_Y >= Saturating_Add (Saturating_Add (Tip_H, Vertical_Gap), Margin);
      end Fits_Above;

      Tip_X       : constant Natural :=
        (if Fits_Right then Saturating_Add (Hover_X, Horizontal_Gap)
         elsif Fits_Left then Hover_X - Tip_W - Horizontal_Gap
         elsif Width > Saturating_Add (Tip_W, Margin)
         then Natural'Min (Hover_X, Width - Tip_W - Margin)
         else 0);
      Tip_Y       : constant Natural :=
        (if Fits_Below then Saturating_Add (Hover_Y, Vertical_Gap)
         elsif Fits_Above then Hover_Y - Tip_H - Vertical_Gap
         elsif Height > Saturating_Add (Tip_H, Margin)
         then Natural'Min (Hover_Y, Height - Tip_H - Margin)
         else 0);
   begin
      if not Has_Hover or else Text_Len = 0 or else Text_W = 0 then
         return;
      end if;

      --  Draw the box and border once, then lay the wrapped text rows on top.
      Guikit.Widgets.Draw_Tooltip
        (Rectangles      => Result.Overlay_Rectangles,
         Text            => Result.Overlay_Text,
         Clip_Width      => Layout.Width,
         Clip_Height     => Layout.Height,
         Box_X           => Tip_X,
         Box_Y           => Tip_Y,
         Box_Width       => Tip_W,
         Box_Height      => Tip_H,
         Fill_Color      => Overlay_Color,
         Border_Color    => Border_Color,
         Label_X         => Saturating_Add (Tip_X, Padding),
         Label_Y         => Saturating_Add (Tip_Y, Padding_V),
         Label_Width     => 0,
         Label_Height    => 0,
         Label_Text      => Null_Unbounded_String,
         Label_Truncated => False,
         Label_Color     => Text_Color);

      --  Draw each already-wrapped row of the block, one line height apart.
      declare
         Row        : Natural := 0;
         Line_First : Integer := Wrapped'First;

         procedure Emit_Line (First, Last : Integer) is
            Label_X : constant Natural := Saturating_Add (Tip_X, Padding);
            Label_Y : constant Natural :=
              Saturating_Add
                (Saturating_Add (Tip_Y, Padding_V), Saturating_Multiply (Row, Line_Height));
            Draw_W  : constant Natural := Clipped_Size (Label_X, Draw_Text_W, Layout.Width);
            Draw_H  : constant Natural := Clipped_Size (Label_Y, Line_Height, Layout.Height);
         begin
            if Last >= First and then Draw_W > 0 and then Draw_H > 0 then
               Result.Overlay_Text.Append
                 (Guikit.Draw.Text_Command'
                    (X => Label_X, Y => Label_Y, Width => Draw_W, Height => Draw_H,
                     Text => To_Unbounded_String (Wrapped (First .. Last)),
                     Color => Text_Color, Truncated => False,
                     Scale_To_Box => False, Italic => False));
            end if;
         end Emit_Line;
      begin
         for Position in Wrapped'Range loop
            if Wrapped (Position) = ASCII.LF then
               Emit_Line (Line_First, Position - 1);
               Line_First := Position + 1;
               Row := Saturating_Add (Row, 1);
            end if;
         end loop;
         Emit_Line (Line_First, Wrapped'Last);
      end;
   end Add_Hover_Tooltip;
