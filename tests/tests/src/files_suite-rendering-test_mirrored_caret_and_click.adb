with Guikit.Bidi;
separate (Files_Suite.Rendering)
   --  In a mirrored (right-to-left) window a field's text keeps its reading
   --  order but stands against the field's mirrored edge, so in the frame as
   --  drawn before mirroring the caret moves left as it advances; a click
   --  where each caret is drawn puts the caret back there.
   procedure Test_Mirrored_Caret_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Previous_X : Natural := Natural'Last;
   begin
      Guikit.Bidi.Set_Mirrored_Layout (True);
      for Cursor in 0 .. 3 loop
         declare
            Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
            CX, CY, CW, CH : Natural;
            Found          : Boolean;
         begin
            declare
               Item : Item_Snapshot := Snapshot.Items.Element (1);
            begin
               Item.Selected := True;
               Item.Renaming := True;
               Item.Rename_Value := To_Unbounded_String ("abc");
               Item.Rename_Cursor := Cursor;
               Snapshot.Items.Replace_Element (1, Item);
            end;
            Snapshot.Selected_Count := 1;
            Snapshot.Rename_Active := True;
            Snapshot.Focus := Files.UI_Types.Focus_Rename_Input;

            declare
               Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
            begin
               Find_Caret (Frame, CX, CY, CW, CH, Found);
               Assert (Found, "the focused rename row draws a caret");
               Assert
                 (CX < Previous_X,
                  "the caret after" & Natural'Image (Cursor) & " letters is left of the one before it");
               Previous_X := CX;
               declare
                  Action : constant Files.Events.Input_Action :=
                    Files.Events.Translate_Click
                      (Snapshot, Frame, X => CX, Y => CY + CH / 2, Width => 1000, Height => 800, Line_Height => 20);
               begin
                  Files_Suite.Support.Assert_Equal
                    (Action.Cursor_Position,
                     Cursor,
                     "a click at the caret drawn after" & Natural'Image (Cursor) & " letters puts it back there");
               end;
            end;
         end;
      end loop;
      Guikit.Bidi.Set_Mirrored_Layout (False);
   exception
      when others =>
         Guikit.Bidi.Set_Mirrored_Layout (False);
         raise;
   end Test_Mirrored_Caret_And_Click;
