separate (Files_Suite.Operations)
   --  One very large action does not make the history journal refuse every
   --  later save (and with it every operation's start and every Undo): the
   --  oldest entries are left out of the journal until the rest fits.
   procedure Test_History_Journal_Fits_Large_Actions (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      History_Directory : constant String := Join (Root, "history-large");
      Long_Name : constant String := [1 .. 2_000 => 'x'];
      Undo      : Files.Model.Undo_Entry_Vectors.Vector;
      Model     : Files.Model.Window_Model;

      function Large (Tag : String) return Files.Model.Undo_Entry is
         Result : Files.Model.Undo_Entry;
      begin
         Result.Kind := Files.Model.Undo_Delete_Created;
         Result.Redoable := False;
         for Index in 1 .. 20_000 loop
            Result.From.Append (To_Unbounded_String ("/" & Tag & Long_Name & Index'Image));
            Result.Created_Identities.Append (To_Unbounded_String ("1:" & Index'Image));
            Result.Created_Tree_Revisions.Append (To_Unbounded_String ("rev"));
         end loop;
         return Result;
      end Large;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (History_Directory);
      --  About 40 MB each: two do not fit under the 64 MiB cap.
      Undo.Append (Large ("older"));
      Undo.Append (Large ("newer"));
      Files.History_Journal.Save_Stacks
        (History_Directory, Undo, Files.Model.Undo_Entry_Vectors.Empty_Vector, Required => True);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      Assert (Files.History_Journal.Restore (History_Directory, Model), "the journal is saved and reads back");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_History (Model).Length), 1, "with the newest action, the older left out");
      Assert (Ada.Strings.Fixed.Index
                (To_String (Files.Model.Undo_History (Model).First_Element.From.First_Element), "/newer") = 1,
              "the one kept is the newest");
      Reset_Root;
   end Test_History_Journal_Fits_Large_Actions;
