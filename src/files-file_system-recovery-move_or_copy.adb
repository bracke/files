separate (Files.File_System.Recovery)
function Move_Or_Copy
  (Source, Destination : String;
   Fallback_Key        : String;
   Route               : out Move_Route;
   Identity, Revision  : out Files.Types.UString;
   Copy_Kept           : out Boolean;
   Cancel              : Cancellation_Check := Job_Cancelled;
   Batch               : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session;
   If_Source_Stays     : Unremoved_Source_Rule := Take_Copy_Back;
   After_Copy          : Copy_Hook := null;
   Expected_Identity   : String := "")
   return Mutation_Result
is
   use type Hostkit.Fs.Move_Outcome;
   Outcome : Hostkit.Fs.Move_Outcome := Hostkit.Fs.Move_Refused;
begin
   Identity := Null_Unbounded_String;
   Revision := Null_Unbounded_String;
   Copy_Kept := False;
   begin
      Outcome := Support.Move_No_Replace_Outcome (Source, Destination);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         Outcome := Hostkit.Fs.Move_Refused;
   end;
   if Outcome = Hostkit.Fs.Moved then
      Route := Renamed;
      return (Success => True, Error_Key => Null_Unbounded_String);
   elsif not Support.Copy_May_Replace_Move (Outcome) then
      Route := Refused;
      return (Success => False, Error_Key => Files.Io_Errors.Error_Key (Fallback_Key));
   end if;
   Route := Copied;
   return Move_By_Copy
     (Source, Destination, Fallback_Key, Identity, Revision, Copy_Kept,
      Cancel            => Cancel,
      Batch             => Batch,
      If_Source_Stays   => If_Source_Stays,
      After_Copy        => After_Copy,
      Expected_Identity => Expected_Identity);
end Move_Or_Copy;
