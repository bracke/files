separate (Files.Operations)
--  On a case-insensitive destination (Windows, macOS by default, a DOS-rule
--  volume anywhere) `Report.txt` collides with an existing `report.txt`, but
--  the planner compares exact strings and saw no conflict; the copy then
--  failed mid-batch. Record each incoming path that matches an existing
--  entry only by case as existing too, so the normal conflict flow applies
--  and a Replace writes through the filesystem's own case rules. A
--  case-sensitive macOS volume at worst asks about a harmless near-match.
--  Names fold with Fold_Case, which covers every script: To_Lower knows
--  only ASCII and Latin-1, so ПРИВЕТ.txt slipped past привет.txt.
function With_Case_Aliases
  (Work      : Files.Paste.Work_Item_Vectors.Vector;
   Existing  : Files.Types.String_Vectors.Vector;
   Directory : String)
   return Files.Types.String_Vectors.Vector
is
   use type Hostkit.Host.Kind;
   Result : Files.Types.String_Vectors.Vector := Existing;
   Exact  : Archive_Name_Sets.Set;
   Folded : Archive_Name_Sets.Set;
begin
   if not (Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS
           or else Hostkit.Fs.Uses_Dos_Filename_Rules (Directory))
   then
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
