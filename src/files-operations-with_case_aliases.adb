separate (Files.Operations)
--  On a destination that folds case (Hostkit.Fs.Folds_Name_Case: Windows, a
--  macOS volume unless formatted case-sensitive, a DOS-rule volume anywhere)
--  `Report.txt` collides with an existing `report.txt`, but
--  the planner compares exact strings and saw no conflict; the copy then
--  failed mid-batch. Record each incoming path that matches an existing
--  entry only by case as existing too, so the normal conflict flow applies
--  and a Replace writes through the filesystem's own case rules.
--  Names fold with Fold_Case, which covers every script: To_Lower knows
--  only ASCII and Latin-1, so ПРИВЕТ.txt slipped past привет.txt.
function With_Case_Aliases
  (Work      : Files.Paste.Work_Item_Vectors.Vector;
   Existing  : Files.Types.String_Vectors.Vector;
   Directory : String)
   return Files.Types.String_Vectors.Vector
is
   Result : Files.Types.String_Vectors.Vector := Existing;
   Exact  : Archive_Name_Sets.Set;
   Folded : Archive_Name_Sets.Set;
begin
   if not Hostkit.Fs.Folds_Name_Case (Directory) then
      return Existing;
   end if;
   for Path of Existing loop
      Exact.Include (To_String (Path));
      Folded.Include (Files.Types.Fold_Case (To_String (Path)));
   end loop;
   for Item of Work loop
      declare
         Desired : constant String :=
           Files.Paste.Desired_Path (To_String (Item.Dest_Dir), To_String (Item.Dest_Name));
      begin
         if not Exact.Contains (Desired)
           and then Folded.Contains (Files.Types.Fold_Case (Desired))
         then
            Result.Append (To_Unbounded_String (Desired));
            Exact.Include (Desired);
         end if;
      end;
   end loop;
   return Result;
exception
   when others =>
      return Existing;
end With_Case_Aliases;
