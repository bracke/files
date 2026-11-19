separate (Files.File_System.Recovery)
   procedure Sweep_Registry is
      Root : constant String := Registry_Root (Create => False);
      --  Each live record the listing found, read under the registry lock:
      --  its directory, the payload it names and the stage identity expected.
      Directories, Payloads, Identities : Files.Types.String_Vectors.Vector;

      procedure Collect (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         Payload, Expected : UString;
         Directory : constant String := Hostkit.Fs.Join (Root, Name);
      begin
         if not Files.Types.Starts_With (Name, Files.Protocol_Names.Recovery_Stage_Prefix)
           or else not Files.Fs_Primitives.Directory_Exists (Directory)
         then
            return;
         elsif Is_Stale_Record (Directory) then
            Delete_Registry_Record (Directory);
         elsif Read_Registry_Record (Directory, Payload, Expected) then
            Directories.Append (To_Unbounded_String (Directory));
            Payloads.Append (Payload);
            Identities.Append (Expected);
         end if;
      end Collect;

      --  Whether the record at Directory still names Payload in the stage
      --  Expected: while the lock was let go another process may have
      --  dropped it and reclaimed the slot for a payload of its own.
      function Still_Names (Directory, Payload, Expected : String) return Boolean is
         Recorded, Identity : UString;
      begin
         return Files.Fs_Primitives.Directory_Exists (Directory)
           and then Read_Registry_Record (Directory, Recorded, Identity)
           and then To_String (Recorded) = Payload
           and then To_String (Identity) = Expected;
      end Still_Names;
   begin
      if Root = "" then
         return;
      end if;
      declare
         Hold : Registry_Hold;
      begin
         Hold_Registry (Root, Hold);
         Files.Fs_Primitives.For_Each_Name (Root, Collect'Access);
      end;
      declare
         Count : constant Natural := Natural (Payloads.Length);
         --  Stopped: a restore or release that stopped after the payload
         --  left; Finished: its stage is gone now, so its record can go.
         Stopped, Finished : array (1 .. Count) of Boolean := [others => False];
         Seen : Path_Sets.Set;
      begin
         --  The work itself, without the lock (see Hold_Registry): each stage's
         --  markers keep two sweeps, or a sweep and a live release, apart.
         for Index in 1 .. Count loop
            declare
               Payload : constant String := To_String (Payloads.Element (Index));
            begin
               if During_Sweep_Work /= null then
                  During_Sweep_Work (Payload);
               end if;
               Resume_Interrupted_Release (Payload);
               if Only_Stage_Left (Payload)
                 and then Stage_Matches (Payload, To_String (Identities.Element (Index)))
               then
                  Stopped (Index) := True;
                  Finished (Index) := Finish_Stopped_Stage (Payload)
                    and then Files.Fs_Primitives.Entry_Is_Absent (Files.Fs_Primitives.Parent_Directory (Payload));
               elsif Abandoned_Unfilled (Payload)
                 and then Stage_Matches (Payload, To_String (Identities.Element (Index)))
               then
                  Stopped (Index) := True;
                  Finished (Index) := Remove_Abandoned_Stage (Payload)
                    and then Files.Fs_Primitives.Entry_Is_Absent (Files.Fs_Primitives.Parent_Directory (Payload));
               end if;
            end;
         end loop;
         --  The records again under the lock, each only while it still names
         --  the payload the work was done for.
         declare
            Hold : Registry_Hold;
         begin
            Hold_Registry (Root, Hold);
            for Index in 1 .. Count loop
               declare
                  Directory : constant String := To_String (Directories.Element (Index));
                  Payload   : constant String := To_String (Payloads.Element (Index));
                  Expected  : constant String := To_String (Identities.Element (Index));
               begin
                  if Stopped (Index) then
                     if Finished (Index) and then Still_Names (Directory, Payload, Expected) then
                        Delete_Registry_Record (Directory);
                     end if;
                  elsif Seen.Contains (Payload) then
                     --  A duplicate left by a reused stage name (see Register);
                     --  one record per payload is all Unregister and recovery need.
                     if Still_Names (Directory, Payload, Expected) then
                        Delete_Registry_Record (Directory);
                     end if;
                  else
                     Seen.Include (Payload);
                  end if;
               end;
            end loop;
         end;
      end;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
   end Sweep_Registry;
