separate (Files.File_System.Recovery)
   function Remove_Move_Source
     (Path         : String;
      Expected     : Support.Source_Snapshot;
      Fallback_Key : String;
      Set_Aside    : out Boolean;
      Cancel       : Cancellation_Check := Job_Cancelled) return Mutation_Result
   is
      use type Files.Types.String_Vectors.Vector;
      Backup : UString;
      Committed : Boolean := False;
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String (Fallback_Key));
      Changed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.move.source_changed"));
   begin
      Set_Aside := False;
      if Expected.Entries.Is_Empty then
         return Failed;
      end if;
      --  A metadata-only early check: the full content check below runs on
      --  the privately renamed source, which nothing else can then replace,
      --  so reading every file here as well only doubled the cost.
      if not Same_Shape (Snapshot (Path, Content => False, Cancel => Cancel), Expected) then
         return Changed;
      end if;
      declare
         Saved : constant Mutation_Result := Preserve (Path, Backup);
      begin
         if not Saved.Success then
            --  A Preserve that could not put the source back leaves Backup
            --  naming the stage that now holds it: the copy must stay.
            Set_Aside := Length (Backup) > 0;
            if Set_Aside then
               return
                 (Success => False, Error_Key => To_Unbounded_String ("error.move.source_set_aside"));
            end if;
            return Saved;
         end if;
      end;
      --  Check the private source too. Its rename changes the root's ctime;
      --  descendants and all identities, sizes, modes and mtimes must match.
      begin
         if Snapshot (To_String (Backup), Cancel => Cancel, Change_Times => Trust_Of (Expected)).Entries /=
           Expected.Entries
         then
            raise Ada.Directories.Use_Error;
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
            --  Changed since the copy. Put it back; if that fails too, it is
            --  safe only in its stage, and the copy must not be dropped.
            if Restore (To_String (Backup)).Success then
               return Changed;
            end if;
            Set_Aside := True;
            return
              (Success => False, Error_Key => To_Unbounded_String ("error.move.source_set_aside"));
      end;
      Committed := True;
      --  Once the source pathname is vacated the move is committed. Refused
      --  cleanup leaves a hidden backup; it cannot invalidate the complete
      --  destination or expose a partly deleted tree at the source pathname.
      declare
         Removed : constant Mutation_Result := Discard (To_String (Backup));
         pragma Unreferenced (Removed);
      begin
         null;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
      end;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return (Success => Committed,
                 Error_Key => (if Committed then Null_Unbounded_String else To_Unbounded_String (Fallback_Key)));
   end Remove_Move_Source;
