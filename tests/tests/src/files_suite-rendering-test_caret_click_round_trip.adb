separate (Files_Suite.Rendering)
   --  The caret renderer and the click hit-test measure text with one shared
   --  advance width, so a click at the pixel a caret draws for cursor k must
   --  resolve back to cursor k.
   procedure Test_Caret_Click_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      CX, CY, CW, CH : Natural;
      Found          : Boolean;
   begin
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("abcdef");
         Item.Rename_Cursor := 3;
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
         declare
            Action : constant Files.Events.Input_Action :=
              Files.Events.Translate_Click
                (Snapshot, Frame,
                 X      => CX,
                 Y      => CY + CH / 2,
                 Width  => 1000,
                 Height => 800);
         begin
            Files_Suite.Support.Assert_Equal
              (Action.Kind,
               Files.Events.Text_Click_Input_Action,
               "clicking the rename field produces a text-click action");
            Files_Suite.Support.Assert_Equal
              (Action.Focus_Target,
               Files.Types.Focus_Rename_Input,
               "the click targets the rename input");
            Files_Suite.Support.Assert_Equal
              (Action.Cursor_Position,
               3,
               "the click at the caret pixel resolves back to the drawn cursor index");
            Files_Suite.Support.Assert_Equal (Action.Item_Index, 1, "the click carries the clicked row index");
         end;
      end;
   end Test_Caret_Click_Round_Trip;
