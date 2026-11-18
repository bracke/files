separate (Files_Suite.Rendering)
   --  Hebrew is drawn right to left, so the caret of a rename field standing
   --  before the first letter is on the right of the text and moves left as
   --  it advances; a click where each caret is drawn puts the caret back there.
   procedure Test_Right_To_Left_Caret_And_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Alef, bet, gimel: two bytes each.
      Hebrew : constant String :=
        Character'Val (16#D7#) & Character'Val (16#90#)
        & Character'Val (16#D7#) & Character'Val (16#91#)
        & Character'Val (16#D7#) & Character'Val (16#92#);
      Previous_X : Natural := Natural'Last;
   begin
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
               Item.Rename_Value := To_Unbounded_String (Hebrew);
               Item.Rename_Cursor := 2 * Cursor;
               Snapshot.Items.Replace_Element (1, Item);
            end;
            Snapshot.Selected_Count := 1;
            Snapshot.Rename_Active := True;
            Snapshot.Focus := Files.Types.Focus_Rename_Input;

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
                    (Action.Kind, Files.Events.Text_Click_Input_Action, "clicking the rename field edits it");
                  Files_Suite.Support.Assert_Equal
                    (Action.Cursor_Position,
                     2 * Cursor,
                     "a click at the caret drawn after" & Natural'Image (Cursor) & " letters puts it back there");
               end;
            end;
         end;
      end loop;
   end Test_Right_To_Left_Caret_And_Click;
