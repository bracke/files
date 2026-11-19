with Ada.Containers.Vectors;
separate (Files.Rendering.Build_Frame_Commands)
   procedure Add_Hover_Tooltip is
      --  Chrome sizes at the reference line height, scaled with the text.
      Padding     : constant Natural := Guikit.Layout.Scaled (6, Line_Height);
      --  Even inset on every side; the vertical inset is derived so the box
      --  is comfortably taller than the text with matching top/bottom bands.
      Padding_V   : constant Natural :=
        Natural'Max (Padding, Guikit.Layout.Saturating_Add (Line_Height / 3, Guikit.Layout.Scaled (2, Line_Height)));
      Margin      : constant Natural := Guikit.Layout.Scaled (4, Line_Height);
      Horizontal_Gap : constant Natural := Guikit.Layout.Scaled (12, Line_Height);
      Vertical_Gap   : constant Natural := Guikit.Layout.Scaled (18, Line_Height);
      Cell_W      : constant Natural := Guikit.Layout.Caret_Advance_Width (Line_Height);
      Max_Tip_W   : constant Natural :=
        (if Width > 2 * Margin then Width - 2 * Margin else Width);

      --  One drawn row of the tooltip: a slice of its text.
      type Text_Row is record
         First : Integer;
         Last  : Integer;
      end record;

      package Row_Vectors is new Ada.Containers.Vectors (Positive, Text_Row);

      --  Lay out and draw Raw, Text_W pixels at most, beside the pointer.
      procedure Draw_Tip (Raw : String; Text_W : Positive) is
         Capacity : constant Natural := Text_W / Cell_W;
         Rows     : Row_Vectors.Vector;

         procedure Add_Row (Row : Natural; First : Integer; Last : Integer) is
            pragma Unreferenced (Row);
         begin
            Rows.Append (Text_Row'(First, Last));
         end Add_Row;

         --  The rows Raw already holds, for a box too narrow to wrap in.
         procedure Split_Lines is
            First : Integer := Raw'First;
         begin
            for Position in Raw'Range loop
               if Raw (Position) = ASCII.LF then
                  Rows.Append (Text_Row'(First, Position - 1));
                  First := Position + 1;
               end if;
            end loop;
            Rows.Append (Text_Row'(First, Raw'Last));
         end Split_Lines;
      begin
         --  Wrapped as the info pane wraps (For_Each_Wrapped_Line), so the
         --  same text breaks the same way in both; the box size and the drawn
         --  rows all derive from these rows.
         if Capacity = 0 then
            Split_Lines;
         else
            For_Each_Wrapped_Line (Raw, Text_W, Line_Height, Add_Row'Access);
         end if;
         if Rows.Is_Empty then
            Rows.Append (Text_Row'(Raw'First, Raw'First - 1));
         end if;

         declare
            Line_Units  : Natural := 0;
         begin
            for Row of Rows loop
               if Row.Last >= Row.First then
                  Line_Units := Natural'Max (Line_Units, Guikit.Utf8.Display_Units (Raw (Row.First .. Row.Last)));
               end if;
            end loop;

            declare
               Draw_Text_W : constant Natural :=
                 (if Capacity > 0 and then Line_Units > 0
                  then Saturating_Multiply (Line_Units, Cell_W) else Text_W);
               Tip_W       : constant Natural :=
                 Guikit.Layout.Saturating_Add (Draw_Text_W, Saturating_Multiply (Padding, 2));
               Tip_H       : constant Natural :=
                 Guikit.Layout.Saturating_Add
                   (Saturating_Multiply (Natural (Rows.Length), Line_Height),
                    Saturating_Multiply (Padding_V, 2));

               function Fits_Right return Boolean is
                 (Width > Margin
                  and then Hover_X <= Natural'Last - Horizontal_Gap
                  and then Guikit.Layout.Saturating_Add (Hover_X, Horizontal_Gap) <= Natural'Last - Tip_W
                  and then Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Hover_X, Horizontal_Gap), Tip_W)
                    <= Width - Margin);

               function Fits_Left return Boolean is
                 (Hover_X
                  >= Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Tip_W, Horizontal_Gap), Margin));

               function Fits_Below return Boolean is
                 (Height > Margin
                  and then Hover_Y <= Natural'Last - Vertical_Gap
                  and then Guikit.Layout.Saturating_Add (Hover_Y, Vertical_Gap) <= Natural'Last - Tip_H
                  and then Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Hover_Y, Vertical_Gap), Tip_H)
                    <= Height - Margin);

               function Fits_Above return Boolean is
                 (Hover_Y
                  >= Guikit.Layout.Saturating_Add (Guikit.Layout.Saturating_Add (Tip_H, Vertical_Gap), Margin));

               Tip_X   : constant Natural :=
                 (if Fits_Right then Guikit.Layout.Saturating_Add (Hover_X, Horizontal_Gap)
                  elsif Fits_Left then Hover_X - Tip_W - Horizontal_Gap
                  elsif Width > Guikit.Layout.Saturating_Add (Tip_W, Margin)
                  then Natural'Min (Hover_X, Width - Tip_W - Margin)
                  else 0);
               Tip_Y   : constant Natural :=
                 (if Fits_Below then Guikit.Layout.Saturating_Add (Hover_Y, Vertical_Gap)
                  elsif Fits_Above then Hover_Y - Tip_H - Vertical_Gap
                  elsif Height > Guikit.Layout.Saturating_Add (Tip_H, Margin)
                  then Natural'Min (Hover_Y, Height - Tip_H - Margin)
                  else 0);
               Label_X : constant Natural := Guikit.Layout.Saturating_Add (Tip_X, Padding);
               Draw_W  : constant Natural := Clipped_Size (Label_X, Draw_Text_W, Layout.Width);
               Line    : Natural := 0;
            begin
               --  The box and border once, then the rows on top, one line
               --  height apart.
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
                  Label_X         => Label_X,
                  Label_Y         => Guikit.Layout.Saturating_Add (Tip_Y, Padding_V),
                  Label_Width     => 0,
                  Label_Height    => 0,
                  Label_Text      => Null_Unbounded_String,
                  Label_Truncated => False,
                  Label_Color     => Text_Color);

               for Row of Rows loop
                  declare
                     Label_Y : constant Natural :=
                       Guikit.Layout.Saturating_Add
                         (Guikit.Layout.Saturating_Add (Tip_Y, Padding_V), Saturating_Multiply (Line, Line_Height));
                     Draw_H  : constant Natural := Clipped_Size (Label_Y, Line_Height, Layout.Height);
                  begin
                     if Row.Last >= Row.First and then Draw_W > 0 and then Draw_H > 0 then
                        Result.Overlay_Text.Append
                          (Guikit.Draw.Text_Command'
                             (X => Label_X, Y => Label_Y, Width => Draw_W, Height => Draw_H,
                              Text => To_Unbounded_String (Raw (Row.First .. Row.Last)),
                              Color => Text_Color, Truncated => False,
                              Scale_To_Box => False, Align_End => False, Italic => False));
                     end if;
                  end;
                  Line := Guikit.Layout.Saturating_Add (Line, 1);
               end loop;
            end;
         end;
      end Draw_Tip;
   begin
      if not Has_Hover or else Has_Drag then
         return;
      end if;

      declare
         Text_Raw   : constant String := To_String (Tooltip_At (Hover_X, Hover_Y));
         Raw_Text_W : constant Natural := Saturating_Multiply (Guikit.Utf8.Display_Units (Text_Raw), Cell_W);
         Text_W     : constant Natural :=
           (if Max_Tip_W > 2 * Padding
            then Natural'Min (Raw_Text_W, Max_Tip_W - 2 * Padding)
            else 0);
      begin
         if Text_W > 0 then
            Draw_Tip (Text_Raw, Text_W);
         end if;
      end;
   end Add_Hover_Tooltip;
