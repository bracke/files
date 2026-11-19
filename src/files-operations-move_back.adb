separate (Files.Operations)
function Move_Back
  (Action : in out Files.Undo_History.Undo_Entry;
   Model : in out Files.Model.Window_Model;
   Side : Files.Undo_History.History_Side) return Boolean
is
   use type Files.Undo_History.History_Side;
   --  Redoing re-does To -> From; undoing moves From back to To.
   Forward : constant Boolean := Side = Files.Undo_History.Redo_Side;
   Count : constant Natural := Natural (Action.Items.Length);
   Succeeded : Boolean := True;
   Done : Path_Sets.Set := To_Set (if Forward then Action.Forward_Completed else Action.Reverse_Completed);
   --  Recognisable means a retry finds the step done by its recorded
   --  identity; one a cross-device copy gave a new identity is not, until
   --  the journal holds that identity.
   procedure Completed (Path : Files.Types.UString; Recognisable : Boolean := True) is
   begin
      Done.Include (To_String (Path));
      if Forward then
         Action.Forward_Completed.Append (Path);
      else
         Action.Reverse_Completed.Append (Path);
      end if;
      --  A retry finds a finished move by its identity at the target.
      Files.History_Journal.Checkpoint
        (Files.Model.History.State (Model), Action, Side,
         Timing => (if Recognisable then Files.History_Journal.Within_Second else Files.History_Journal.Write_Now));
   end Completed;
begin
   for Step in 0 .. Count - 1 loop
      if Files.Job_Context.Cancelled then
         return False;
      end if;
      declare
         --  Undo replays a batch last move first: renaming b to c and then
         --  a to b undoes as b to a, then c to b.
         Index  : constant Positive := (if Forward then 1 + Step else Count - Step);
         --  Forward re-does To -> From; reverse moves From back to To.
         Source_Path : constant Files.Types.UString :=
           (if Forward then Action.Items (Index).To else Action.Items (Index).From);
         Source : constant String := To_String (Source_Path);
         Target : constant String :=
           To_String (if Forward then Action.Items (Index).From else Action.Items (Index).To);
         Identity : constant String := To_String (Action.Items (Index).Identity);
         Marked : constant Boolean := Done.Contains (Source);
         Matches : constant Boolean :=
           Identity /= "" and then Files.File_Identities.Token (Target) = Identity;
      begin
         if Marked and then Matches then
            null;
         else
            if Marked then
               Remove_Completion (Action, Source_Path, Side);
               Done.Exclude (Source);
               Files.History_Journal.Checkpoint (Files.Model.History.State (Model), Action, Side);
            end if;
            if Identity = "" then
               Succeeded := False;
            elsif Matches then
               Files.Model.Note_Path_Move (Model, Source, Target);
               Completed (Source_Path);
            --  refusal-safe: a refused source fails the step, which a retry repeats
            elsif Files.Fs_Primitives.Entry_Exists (Source) then
               if Files.File_System.Rename_Item (Source, Target, Identity).Success then
                  Files.Model.Note_Path_Move (Model, Source, Target);
                  --  A cross-device copy gives the moved entry a new identity.
                  declare
                     Now_Identity : constant String := Files.File_Identities.Token (Target);
                  begin
                     Action.Items (Index).Identity := To_Unbounded_String (Now_Identity);
                     Completed (Source_Path, Recognisable => Now_Identity = Identity);
                  end;
               else
                  Succeeded := False;
               end if;
            else
               Succeeded := False;
            end if;
         end if;
      end;
   end loop;
   return Succeeded;
end Move_Back;
