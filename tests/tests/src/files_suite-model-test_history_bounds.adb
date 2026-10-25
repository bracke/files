separate (Files_Suite.Model)
   procedure Test_History_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model;
      Empty : Files.File_System.Item_Vectors.Vector;
      History_Path : constant String := Join (Root, "history-entry");
   begin
      --  Recording far more undo entries than the cap keeps only the most recent
      --  ones; the reachable LIFO history is bounded rather than growing forever.
      Reset_Root;
      Write_Binary_File (History_Path, "history");
      for Index in 1 .. 260 loop
         declare
            Image : constant String := Integer'Image (Index);
            pragma Unreferenced (Image);
            From : Files.Types.String_Vectors.Vector;
         begin
            From.Append (To_Unbounded_String (History_Path));
            Files.Operations.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, From => From,
               To => Files.Types.String_Vectors.Empty_Vector, Redoable => False);
         end;
      end loop;
      declare
         Count  : Natural := 0;
         Action : Files.Model.Undo_Entry;
         Found  : Boolean;
      begin
         loop
            Files.Model.Take_Undo (Model, Action, Found);
            exit when not Found;
            Count := Count + 1;
         end loop;
         Files_Suite.Support.Assert_Equal (Count, 200, "the undo stack is capped at 200 entries; kept" & Count'Image);
      end;

      --  Back-navigation history is bounded the same way.
      for Index in 1 .. 260 loop
         Files.Model.Navigate_To (Model, "/dir/" & Integer'Image (Index), Empty);
      end loop;
      declare
         Count : Natural := 0;
      begin
         while Files.Model.Can_Go_Back (Model) loop
            Files.Model.Go_Back (Model);
            Count := Count + 1;
         end loop;
         Files_Suite.Support.Assert_Equal
           (Count,
            200,
            "back-navigation history is capped at 200; went back" & Count'Image);
      end;
   end Test_History_Bounds;
