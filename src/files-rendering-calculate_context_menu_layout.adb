separate (Files.Rendering)
   function Calculate_Context_Menu_Layout
     (Snapshot    : View_Snapshot;
      Width       : Natural;
      Height      : Natural;
      Line_Height : Positive := 20)
      return Context_Menu_Layout
   is
      Result : Context_Menu_Layout;

      use type Files.Commands.Context_Menu_Row_Kind;
      use type Files.Model.Context_Menu_Target;
   begin
      if not Snapshot.Context_Menu_Open
        or else Snapshot.Context_Menu_Target = Files.Model.Context_Menu_None
      then
         return Result;
      end if;

      --  The row set (which commands, and where the separators fall) is shared
      --  with the controller's keyboard navigation via Files.Commands so both
      --  agree on the menu; here it is only laid out and hit-tested.
      declare
         Rows : constant Files.Commands.Context_Menu_Rows :=
           Files.Commands.Context_Menu_Rows_For (Snapshot.Context_Menu_Target);
      begin
         Result.Row_Count := Rows.Count;
         for Row in 1 .. Rows.Count loop
            Result.Commands (Row) := Rows.Rows (Row).Command;
            Result.Row_Kinds (Row) :=
              (if Rows.Rows (Row).Kind = Files.Commands.Menu_Command
               then Command_Row
               else Separator_Row);
         end loop;
      end;

      Result.Padding := 4;
      Result.Row_Height :=
        Saturating_Add (Line_Height, Saturating_Multiply (Result.Padding, 2));
      --  A separator is just a 1px divider line surrounded by the row padding,
      --  so it takes noticeably less vertical space than a command row.
      Result.Separator_Height :=
        Saturating_Add (1, Saturating_Multiply (Result.Padding, 2));

      --  Size the menu to the widest command label (using the same monospace
      --  cell metric and edge padding the renderer draws rows with) so labels
      --  are not truncated, then clamp to the available screen width.
      declare
         Cell_W    : constant Positive :=
           Positive'Max (1, Saturating_Multiply (Line_Height, 12) / 20);
         Edge_Pad  : constant Natural :=
           Saturating_Multiply (Guikit.Layout.Input_Field_Padding, 2);
         Max_Label : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            if Result.Row_Kinds (Row) = Command_Row then
               declare
                  Label : constant String :=
                    Files.Localization.Text
                      (Files.Commands.Name_Key (Result.Commands (Row)));
                  Label_W : constant Natural :=
                    Saturating_Multiply (Files.UTF8.Display_Units (Label), Cell_W);
               begin
                  Max_Label := Natural'Max (Max_Label, Label_W);
               end;
            end if;
         end loop;

         Result.Width :=
           Natural'Max
             (Natural'Max (Saturating_Multiply (Line_Height, 9), 180),
              Saturating_Add (Max_Label, Edge_Pad));

         if Width > 0 and then Result.Width > Width then
            Result.Width := Width;
         end if;
      end;

      declare
         Rows_Height : Natural := 0;
      begin
         for Row in 1 .. Result.Row_Count loop
            Rows_Height :=
              Saturating_Add
                (Rows_Height,
                 (if Result.Row_Kinds (Row) = Separator_Row
                  then Result.Separator_Height
                  else Result.Row_Height));
         end loop;
         Result.Height :=
           Saturating_Add
             (Rows_Height, Saturating_Multiply (Result.Padding, 2));
      end;

      --  Anchor to the cursor but keep the menu fully on-screen.
      Result.X :=
        (if Snapshot.Context_Menu_X + Result.Width > Width
         then (if Width > Result.Width then Width - Result.Width else 0)
         else Snapshot.Context_Menu_X);
      Result.Y :=
        (if Snapshot.Context_Menu_Y + Result.Height > Height
         then (if Height > Result.Height then Height - Result.Height else 0)
         else Snapshot.Context_Menu_Y);
      Result.Visible := Result.Width > 0 and then Result.Height > 0;

      return Result;
   end Calculate_Context_Menu_Layout;
