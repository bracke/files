separate (Files.Operations)
function Replay_Metadata (Action : Files.Undo.History.Undo_Entry; Side : Metadata_Side) return Replay_Outcome is
   Outcome : Replay_Outcome := Replayed;
begin
   for Index in Action.Items.First_Index .. Action.Items.Last_Index loop
      if Files.Jobs.Context.Cancelled then
         return Stopped;
      end if;
      declare
         --  A malformed entry (a value list shorter than From) reads "",
         --  which does not parse: that item fails.
         Text : constant String :=
           Ada.Strings.Fixed.Trim
             ((case Side is
                 when Before_Change => To_String (Action.Items (Index).To),
                 when After_Change  => To_String (Action.Items (Index).Forward)),
              Ada.Strings.Both);
         Mode  : Natural := 0;
         Owner : Files.Undo.Payloads.Ownership;
      begin
         if Action.Kind = Files.Undo.History.Undo_Set_Permissions then
            --  The access record, where one was kept, is put back whole: on
            --  Windows the DACL the change replaced or set.
            if not Files.Undo.Payloads.Parse_Mode (Text, Mode)
              or else not Change_Recorded_Mode (Action, Index, Mode, Files.Undo.Payloads.Mode_Access (Text))
            then
               Outcome := Item_Failed;
            end if;
         elsif not Files.Undo.Payloads.Parse_Ownership (Text, Owner)
           or else not Change_Recorded_Ownership (Action, Index, Owner)
         then
            Outcome := Item_Failed;
         end if;
      end;
   end loop;
   return Outcome;
end Replay_Metadata;
