separate (Files.Operations)
function Completed_Creation_Matches
  (Action : Files.Model.Undo_Entry; Index : Positive; Path : String)
   return Boolean
is
   Identity : constant String :=
     (if Index <= Action.Created_Identities.Last_Index
      then To_String (Action.Created_Identities (Index)) else "");
   Expected_Tree_Revision : constant String :=
     (if Index <= Action.Created_Tree_Revisions.Last_Index
      then To_String (Action.Created_Tree_Revisions (Index)) else "");
begin
   if Identity = "" or else Files.File_Identities.Token (Path) /= Identity then
      return False;
   end if;
   return
     (if Action.Create_Kind = Files.Model.Create_Symbolic_Link
      then Expected_Tree_Revision = ""
      else Expected_Tree_Revision /= ""
        and then Files.File_System.Tree_Revision (Path) = Expected_Tree_Revision);
exception
   when others =>
      return False;
end Completed_Creation_Matches;
