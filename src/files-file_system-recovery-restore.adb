separate (Files.File_System.Recovery)
   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result is
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Path);
      Target : UString;
      --  The stage's restore marker, held while the payload leaves.
      Marker : Hostkit.Lease_Files.Lease;
   begin
      Resume_Interrupted_Release (Path);
      if not Recognizes (Path) or else not Contains_Only_Owned_Entries (Parent) then
         return
           (Success => False,
            Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      Target := To_Unbounded_String
        (if Expected_Original /= "" then Expected_Original else Original_Path (Path));
      if not Valid_Absolute_Path (To_String (Target)) then
         raise Ada.Directories.Use_Error;
      end if;
      --  refusal-safe: a refused target goes on to the no-replace move, which refuses an occupied one
      if Files.Fs_Primitives.Entry_Exists (To_String (Target)) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;
      --  A failed post-rename permission restoration can leave the private
      --  payload writable. Restore its recorded mode before retrying the move
      --  -- where the bits are the host's own, as Preserve records them.
      --  refusal-safe: a refused mode record is skipped; the move does not depend on it
      if Hostkit.Metadata.Mode_Bits_Are_Native and then Files.Fs_Primitives.Exists (Hostkit.Fs.Join (Parent, "mode"))
      then
         declare
            Input : aliased Files.Lease_Streams.Input_Stream;
            Record_Path : constant String := Hostkit.Fs.Join (Parent, "mode");
            Mode, Previous : Natural;
            Expected, Identity : UString;
            Result : Mutation_Result;
         begin
            if not Record_Is_Regular
              (Record_Path, Max_Identity_Length + 32)
            then
               raise Ada.Directories.Use_Error;
            end if;
            if Files.Lease_Streams.Open (Record_Path, Input) /=
                Hostkit.Lease_Files.Opened
              or else Files.Lease_Streams.Size (Input) >
                Max_Identity_Length + 32
            then
               raise Ada.Directories.Use_Error;
            end if;
            Mode := Natural'Input (Input'Access);
            Expected := To_Unbounded_String
              (Files.Bounded_Streams.Input_String
                 (Input'Access, Max_Identity_Length));
            if Mode > 8#7777#
              or else not Files.Lease_Streams.End_Of_Stream (Input)
            then
               raise Ada.Directories.Use_Error;
            end if;
            Files.Lease_Streams.Release (Input);
            if Length (Expected) = 0 then
               raise Ada.Directories.Use_Error;
            end if;
            Result := Change_Mode
              (Path, To_String (Expected), Mode, Previous, Identity);
            if not Result.Success then
               raise Ada.Directories.Use_Error;
            end if;
         exception
            when others => Files.Lease_Streams.Release (Input); raise;
         end;
      end if;
      --  Durable, and held, before the payload leaves, so a sweep finishing
      --  this stage knows the payload went on purpose (see Only_Stage_Left)
      --  and leaves it to this restore while it runs. Held elsewhere: another
      --  restore of this payload is running.
      if not Hold_Marker (Parent, Vacated_Marker, Marker) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      if (Expected_Identity /= "" and then not Rename_Item (Path, To_String (Target), Expected_Identity).Success)
        or else (Expected_Identity = "" and then not Support.Move_No_Replace (Path, To_String (Target)))
      then
         --  refusal-safe: a refused payload keeps the marker
         Let_Go_Marker (Parent, Vacated_Marker, Marker, Remove => Files.Fs_Primitives.Entry_Exists (Path));
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
      end if;
      --  The original is back: the restore has succeeded. Its record goes
      --  only with its stage; a stage that will not go yet keeps the record
      --  and its marker, so Sweep_Registry finds the emptied, marked stage
      --  and finishes it.
      begin
         Remove_Stage_Holding (Parent, Marker);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
      end;
      if Files.Fs_Primitives.Entry_Is_Absent (Parent) then
         Unregister (Path);
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         if Hostkit.Lease_Files.Is_Held (Marker) then
            --  refusal-safe: a refused payload keeps the marker
            Let_Go_Marker (Parent, Vacated_Marker, Marker, Remove => Files.Fs_Primitives.Entry_Exists (Path));
         end if;
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore;
