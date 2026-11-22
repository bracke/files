separate (Files.File_System.Recovery)
   function Restore
     (Path : String; Expected_Identity : String := ""; Expected_Original : String := "") return Mutation_Result is
      Parent : constant String := Files.IO.Fs_Primitives.Parent_Directory (Path);
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
      if not Files.Path_Checks.Valid_Absolute_Path (To_String (Target)) then
         raise Ada.Directories.Use_Error;
      end if;
      --  refusal-safe: a refused target goes on to the no-replace move, which refuses an occupied one
      if Files.IO.Fs_Primitives.Entry_Exists (To_String (Target)) then
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_exists"));
      end if;
      --  A failed post-rename permission restoration can leave the private
      --  payload writable. Restore its recorded mode before retrying the move
      --  -- where the bits are the host's own, as Preserve records them.
      if Hostkit.Metadata.Mode_Bits_Are_Native
        --  refusal-safe: a refused mode record is skipped; the move does not depend on it
        and then Files.IO.Fs_Primitives.Exists (Hostkit.Fs.Join (Parent, Mode_Name))
      then
         declare
            Record_Path : constant String := Hostkit.Fs.Join (Parent, Mode_Name);
            Recorded : Mode_Record;
            Previous : Natural;
            Identity : UString;
            Unused_Previous_Access, Unused_Applied_Access : UString;
            Result : Mutation_Result;
         begin
            if not Record_Is_Regular (Record_Path, Mode_Record_Bytes) then
               raise Ada.Directories.Use_Error;
            end if;
            Recorded := Read_Mode_File (Record_Path, Header => "", Max_Bytes => Mode_Record_Bytes);
            Result := Permissions.Change_Access
              (Path, To_String (Recorded.Identity), Recorded.Mode, "", Previous,
               Unused_Previous_Access, Unused_Applied_Access, Identity);
            if not Result.Success then
               raise Ada.Directories.Use_Error;
            end if;
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
         Let_Go_Marker (Parent, Vacated_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
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
      if Files.IO.Fs_Primitives.Entry_Is_Absent (Parent) then
         Unregister (Path);
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         if Hostkit.Lease_Files.Is_Held (Marker) then
            --  refusal-safe: a refused payload keeps the marker
            Let_Go_Marker (Parent, Vacated_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
         end if;
         return (Success => False, Error_Key => To_Unbounded_String ("error.trash.restore_failed"));
   end Restore;
