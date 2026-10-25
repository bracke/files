separate (Files_Suite.Rendering)
   procedure Test_Tooltip_Wraps_When_Narrow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Base : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);

      --  Centre of the longest-text tooltip region in the frame.
      procedure Longest_Tooltip
        (Frame : Frame_Commands; HX, HY : out Natural;
         Text : out Ada.Strings.Unbounded.Unbounded_String; Found : out Boolean)
      is
         Best : Natural := 0;
      begin
         HX := 0;
         HY := 0;
         Text := Ada.Strings.Unbounded.Null_Unbounded_String;
         Found := False;
         for C of Frame.Tooltips loop
            if Files.UTF8.Display_Units (To_String (C.Text)) > Best then
               Best := Files.UTF8.Display_Units (To_String (C.Text));
               HX := C.X + C.Width / 2;
               HY := C.Y + C.Height / 2;
               Text := C.Text;
               Found := True;
            end if;
         end loop;
      end Longest_Tooltip;

      --  Overlay rows whose text is a slice of the tooltip's text (its wrapped
      --  lines), i.e. how many rows the tooltip occupies.
      function Tooltip_Rows (Frame : Frame_Commands; Full : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Frame.Overlay_Text loop
            if Length (C.Text) > 0 and then Ada.Strings.Fixed.Index (Full, To_String (C.Text)) > 0 then
               Count := Count + 1;
            end if;
         end loop;
         return Count;
      end Tooltip_Rows;

      --  The wrapped rows (in draw order) rejoined with single spaces.
      function Rows_Joined (Frame : Frame_Commands; Full : String) return String is
         Joined : Ada.Strings.Unbounded.Unbounded_String;
         First  : Boolean := True;
      begin
         for C of Frame.Overlay_Text loop
            if Length (C.Text) > 0 and then Ada.Strings.Fixed.Index (Full, To_String (C.Text)) > 0 then
               if not First then
                  Ada.Strings.Unbounded.Append (Joined, ' ');
               end if;
               Ada.Strings.Unbounded.Append (Joined, C.Text);
               First := False;
            end if;
         end loop;
         return Ada.Strings.Unbounded.To_String (Joined);
      end Rows_Joined;

      --  Collapse whitespace runs to single spaces and trim.
      function Squeeze (S : String) return String is
         R          : Ada.Strings.Unbounded.Unbounded_String;
         Prev_Space : Boolean := True;
      begin
         for Ch of S loop
            if Ch = ' ' or else Ch = ASCII.LF or else Ch = ASCII.CR or else Ch = ASCII.HT then
               if not Prev_Space then
                  Ada.Strings.Unbounded.Append (R, ' ');
                  Prev_Space := True;
               end if;
            else
               Ada.Strings.Unbounded.Append (R, Ch);
               Prev_Space := False;
            end if;
         end loop;
         declare
            Str : constant String := Ada.Strings.Unbounded.To_String (R);
         begin
            return (if Str'Length > 0 and then Str (Str'Last) = ' '
                    then Str (Str'First .. Str'Last - 1) else Str);
         end;
      end Squeeze;

      HX, HY : Natural;
      Tip    : Ada.Strings.Unbounded.Unbounded_String;
      Found  : Boolean;
   begin
      declare
         Probe : constant Frame_Commands := Build_Frame_Commands (Base, 260, 800, 20);
      begin
         Longest_Tooltip (Probe, HX, HY, Tip, Found);
         Assert (Found and then Files.UTF8.Display_Units (To_String (Tip)) >= 24,
                 "a long toolbar tooltip is present in a narrow window");
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Base, 260, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Assert (Tooltip_Rows (Frame, To_String (Tip)) >= 2,
                    "a narrow window wraps the tooltip onto multiple rows");
            Files_Suite.Support.Assert_Equal
              (Squeeze (Rows_Joined (Frame, To_String (Tip))),
               Squeeze (To_String (Tip)),
               "wrapped rows rejoin to the original text (no mid-word breaks)");
         end;
      end;

      declare
         Probe : constant Frame_Commands := Build_Frame_Commands (Base, 1000, 800, 20);
      begin
         Longest_Tooltip (Probe, HX, HY, Tip, Found);
         Assert (Found, "a tooltip is present in a wide window");
         declare
            Frame : constant Frame_Commands :=
              Build_Frame_Commands (Base, 1000, 800, 20, Hover_X => HX, Hover_Y => HY, Has_Hover => True);
         begin
            Files_Suite.Support.Assert_Equal
              (Tooltip_Rows (Frame, To_String (Tip)),
               1,
               "a wide window shows the tooltip on a single row");
         end;
      end;
   end Test_Tooltip_Wraps_When_Narrow;
