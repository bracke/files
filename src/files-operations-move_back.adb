separate (Files.Operations)
function Move_Back
  (Action : in out Files.Model.Undo_Entry;
   Model : in out Files.Model.Window_Model;
   Forward : Boolean) return Boolean
is
   Sources : constant Files.Types.String_Vectors.Vector := (if Forward then Action.To else Action.From);
   Targets : constant Files.Types.String_Vectors.Vector := (if Forward then Action.From else Action.To);
   Succeeded : Boolean := True;
   Done : Path_Sets.Set := To_Set (if Forward then Action.Forward_Completed else Action.Reverse_Completed);
   procedure Completed (Path : Files.Types.UString) is
   begin
      Done.Include (To_String (Path));
      if Forward then
         Action.Forward_Completed.Append (Path);
      else
         Action.Reverse_Completed.Append (Path);
      end if;
      --  A retry finds a finished move by its identity at the target.
      Files.History_Journal.Checkpoint (Model, Action, Forward, Force => False);
   end Completed;
begin
   for Step in 0 .. Natural (Sources.Length) - 1 loop
      if Files.Job_Context.Cancelled then
         return False;
      end if;
      declare
         --  Undo replays a batch last move first: renaming b to c and then
         --  a to b undoes as b to a, then c to b.
         Index  : constant Positive :=
           (if Forward then Sources.First_Index + Step else Sources.Last_Index - Step);
         Source : constant String := To_String (Sources.Element (Index));
         Target : constant String := To_String (Targets.Element (Index));
         Identity : constant String :=
           (if Index <= Action.Created_Identities.Last_Index
            then To_String (Action.Created_Identities (Index)) else "");
         Marked : constant Boolean := Done.Contains (To_String (Sources (Index)));
         Matches : constant Boolean :=
           Identity /= "" and then Files.File_Identities.Token (Target) = Identity;
      begin
         if Marked and then Matches then
            null;
         else
            if Marked then
               Remove_Completion (Action, Sources (Index), Forward);
               Done.Exclude (To_String (Sources (Index)));
               Files.History_Journal.Checkpoint (Model, Action, Forward);
            end if;
            if Identity = "" then
               Succeeded := False;
            elsif Matches then
               Files.Model.Note_Path_Move (Model, Source, Target);
               Completed (Sources (Index));
            elsif Exists_Safely (Source) then
               if Files.File_System.Rename_Item (Source, Target, Identity).Success then
                  Files.Model.Note_Path_Move (Model, Source, Target);
                  --  A cross-device copy gives the moved entry a new identity.
                  Action.Created_Identities.Replace_Element
                    (Index, To_Unbounded_String (Files.File_Identities.Token (Target)));
                  Completed (Sources (Index));
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
