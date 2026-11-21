with Files.Text_Basics;

separate (Files.File_System.Recovery)
   function Preserve (Path : String; Backup : out Files.Types.UString) return Mutation_Result is
      --  The entry itself, a link included, made absolute from its text.
      Original : constant String := Files.IO.Fs_Primitives.Absolute_Name (Path);
      Parent   : constant String := Files.IO.Fs_Primitives.Parent_Directory (Original);
      Stage    : UString;
      Registry_Entry : UString;
      File     : aliased Files.IO.Exclusive_Streams.Output_Stream;

      --  Failing once the original has moved into the stage: move it back, so
      --  a failure leaves nothing changed. Backup stays set only when that is
      --  impossible, and then names the one place the original now is.
      function Put_Back return Mutation_Result is
         Failed : constant Mutation_Result :=
           (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      begin
         if Restore (To_String (Backup), Expected_Original => Original).Success then
            Backup := Null_Unbounded_String;
         end if;
         return Failed;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
            return Failed;
      end Put_Back;
   begin
      Files.IO.Errors.Reset;
      Backup := Null_Unbounded_String;
      if not Valid_Absolute_Path (Original) then
         raise Ada.Directories.Use_Error;
      end if;
      for N in 1 .. 9_999 loop
         declare
            Candidate : constant String :=
              Hostkit.Fs.Join (Parent, Files.Protocol_Names.Recovery_Stage_Prefix & Files.Text_Basics.Natural_Text (N));
         begin
            if Files.IO.Private_Directories.Try_Create (Candidate) =
              Files.IO.Private_Directories.Collision
            then
               goto Continue;
            end if;
            Stage := To_Unbounded_String (Candidate);
            exit;
            <<Continue>>
         end;
      end loop;
      if Length (Stage) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.IO.Exclusive_Streams.Create
        (File, Hostkit.Fs.Join (To_String (Stage), "original"));
      Write_Bounded
        (File'Access, Original, Max_Path_Length);
      Files.IO.Exclusive_Streams.Close (File);
      if Files.IO.Durability.Sync_File (Hostkit.Fs.Join (To_String (Stage), "original")) /=
        Hostkit.Durability.Synced
      then
         raise Ada.Directories.Use_Error;
      end if;
      Write_Owner (To_String (Stage), Original);
      Registry_Entry := To_Unbounded_String
        (Register (Hostkit.Fs.Join (To_String (Stage), "payload")));
      --  A read-only folder's mode, to give it back after the rename that
      --  lent it write access. Only where the bits are the host's own: on
      --  Windows they are read out of the folder's ACL, and setting them
      --  writes a new ACL in its place, which would drop what it inherits.
      if Hostkit.Metadata.Mode_Bits_Are_Native
        and then not Hostkit.Fs.Is_Link (Path)
        and then Files.IO.Fs_Primitives.Kind (Path) = Ada.Directories.Directory
      then
         declare
            Available : Boolean;
            Mode : constant Natural := Permission_Bits_Of (Path, Available);
         begin
            if Available and then (Mode / 8#200#) mod 2 = 0 then
               Files.IO.Exclusive_Streams.Create
                 (File, Hostkit.Fs.Join (To_String (Stage), "mode"));
               Natural'Output (File'Access, Mode);
               Write_Bounded
                 (File'Access,
                  Files.File_Identities.Token (Path), Max_Identity_Length);
               Files.IO.Exclusive_Streams.Close (File);
               if Files.IO.Durability.Sync_File (Hostkit.Fs.Join (To_String (Stage), "mode")) /=
                 Hostkit.Durability.Synced
               then
                  raise Ada.Directories.Use_Error;
               end if;
            end if;
         end;
      end if;
      if Files.IO.Durability.Sync_Directory (To_String (Stage)) = Hostkit.Durability.Failed
        or else Files.IO.Durability.Sync_Directory (Parent) = Hostkit.Durability.Failed
      then
         raise Ada.Directories.Use_Error;
      end if;
      if not Support.Move_No_Replace (Path, Hostkit.Fs.Join (To_String (Stage), "payload")) then
         Files.Diagnostics.Trace
           ("Files.File_System.Recovery",
            "preserve_move_refused=" & Path & ",errno=" & Files.IO.Errors.Last_Code'Image);
         --  The backup is beside the original, so a refused rename must leave
         --  the original in place rather than starting a destructive fallback.
         raise Ada.Directories.Use_Error;
      end if;
      Backup := To_Unbounded_String (Hostkit.Fs.Join (To_String (Stage), "payload"));
      if Files.IO.Durability.Sync_Directory (To_String (Stage)) = Hostkit.Durability.Failed
        or else Files.IO.Durability.Sync_Directory (Parent) = Hostkit.Durability.Failed
      then
         return Put_Back;
      end if;
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
         declare
            --  Why, before the cleanup below can record a cause of its own.
            Failed : constant Mutation_Result :=
              (Success => False, Error_Key => Files.IO.Errors.Error_Key ("error.trash.failed"));
         begin
            Files.IO.Exclusive_Streams.Close_Safely (File);
            if Length (Stage) > 0 and then Length (Backup) = 0 then
               --  Unless the payload is surely not there, put it back: the
               --  tree removal below would take the original with it.
               if not Files.IO.Fs_Primitives.Entry_Is_Absent (Hostkit.Fs.Join (To_String (Stage), "payload"))
               then
                  Backup := To_Unbounded_String (Hostkit.Fs.Join (To_String (Stage), "payload"));
                  return Put_Back;
               end if;
               begin
                  Files.IO.Fs_Primitives.Delete_Tree (To_String (Stage));
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
               end;
               if Length (Registry_Entry) > 0 then
                  Delete_Registry_Record (To_String (Registry_Entry));
               end if;
            end if;
            return Failed;
         end;
   end Preserve;
