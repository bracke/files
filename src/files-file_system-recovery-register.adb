separate (Files.File_System.Recovery)
   function Register (Payload : String) return String is
      Root : constant String := Registry_Root (Create => True);
      Hold : Registry_Hold;
      Directory : UString;
      File : aliased Files.Exclusive_Streams.Output_Stream;
   begin
      if Root = "" or else not Valid_Absolute_Path (Payload) then
         raise Ada.Directories.Use_Error;
      end if;
      Hold_Registry (Root, Hold);
      --  Preserve registers a stage it has just created exclusively, and stage
      --  names are reused once freed, so any record already naming this
      --  payload belongs to an earlier, finished stage of the same name.
      Unregister (Payload);
      for N in 1 .. 9_999 loop
         declare
            Candidate : constant String :=
              Hostkit.Fs.Join (Root, Files.Protocol_Names.Recovery_Stage_Prefix & Natural_Text (N));
         begin
            if Files.Private_Directories.Try_Create (Candidate) =
              Files.Private_Directories.Collision
            then
               --  Reclaim a slot left by a stage that is already gone, so
               --  leaked records cannot exhaust the bounded name space.
               if not Is_Stale_Record (Candidate) then
                  goto Continue;
               end if;
               Delete_Registry_Record (Candidate);
               if Files.Private_Directories.Try_Create (Candidate) =
                 Files.Private_Directories.Collision
               then
                  goto Continue;
               end if;
            end if;
            Directory := To_Unbounded_String (Candidate);
            exit;
            <<Continue>>
         end;
      end loop;
      if Length (Directory) = 0 then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Exclusive_Streams.Create
        (File, Hostkit.Fs.Join (To_String (Directory), "record"));
      Write_Bounded
        (File'Access, Registry_Magic, Max_Header_Length);
      Write_Bounded
        (File'Access, Payload, Max_Path_Length);
      Write_Bounded
        (File'Access,
         Files.File_Identities.Token (Files.Fs_Primitives.Parent_Directory (Payload)),
         Max_Identity_Length);
      Files.Exclusive_Streams.Close (File);
      if Files.Durability.Sync_File (Hostkit.Fs.Join (To_String (Directory), "record")) /=
          Hostkit.Durability.Synced
        or else Files.Durability.Sync_Directory (To_String (Directory)) =
          Hostkit.Durability.Failed
        or else Files.Durability.Sync_Directory (Root) = Hostkit.Durability.Failed
      then
         raise Ada.Directories.Use_Error;
      end if;
      return To_String (Directory);
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (File);
         if Length (Directory) > 0 then
            Delete_Registry_Record (To_String (Directory));
         end if;
         raise;
   end Register;
