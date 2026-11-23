with Files.Name_Parts;

separate (Files.Operations.Paste.Advance_Paste_Execution)
procedure Settle_Action
  (Action  : Files.Paste.Resolved_Action;
   Result  : Files.Transfer_Jobs.Job_Result;
   Ended   : out Boolean;
   Outcome : out Operation_Result)
is
   Kept : Kept_Copy := No_Kept_Copy;

   procedure Finish (Error_Key : String; Kept_Aside : Kept_Copy := No_Kept_Copy) is
   begin
      Ended := True;
      Outcome := Finalize_Paste_Execution (Model, Settings, Error_Key, Kept_Aside);
   end Finish;
begin
   Ended := False;
   Outcome := (Status => Operation_Success, others => <>);
   --  An original still held after the action (the write succeeded, or
   --  neither it nor putting it back did) is tracked so the paste's undo
   --  entry can restore it.
   if Length (Result.Trashed) > 0 then
      Record_Paste_Replaced_Trash
        (Model, Result.Trashed, To_String (Result.Trashed_Identity), To_String (Action.Dest_Path));
   end if;
   --  A move that failed yet kept its copy at the destination: the copy is
   --  recorded so the paste's undo covers it -- as a move when its source
   --  is gone, as a copy when it remains.
   if not Result.Mutation.Success and then Length (Result.Created_Identity) > 0 then
      if Source_Remains (Action) then
         Kept := (Action.Dest_Path, Action.Source_Path, Result.Created_Identity, Result.Created_Tree_Revision);
      else
         Record_Paste_Write
           (Model, Action.Dest_Path, Action.Source_Path,
            Files.Name_Parts.Leaf_Of (To_String (Action.Dest_Path)),
            To_String (Result.Created_Identity), To_String (Result.Created_Tree_Revision));
      end if;
   end if;
   if Result.Cancelled then
      Finish ("", Kept);
   elsif not Result.Mutation.Success then
      Finish (To_String (Result.Mutation.Error_Key), Kept);
   else
      Record_Paste_Write
        (Model, Action.Dest_Path, Action.Source_Path,
         Files.Name_Parts.Leaf_Of (To_String (Action.Dest_Path)),
         To_String (Result.Created_Identity), To_String (Result.Created_Tree_Revision),
         Retain_Verified_Snapshot => Result.Recovered);
      if Result.Recovered then
         Finish ("error.drop.failed");
      elsif Files.Model.Pasting.Execution_Cancelled (Model) then
         Finish ("");
      end if;
   end if;
end Settle_Action;
