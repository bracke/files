separate (Files.File_System.Recovery)
   function Vacate
     (Path  : String;
      Leave : not null access function return Boolean;
      Ran   : out Boolean)
      return Boolean
   is
      Stage  : constant String := Files.IO.Fs_Primitives.Parent_Directory (Path);
      Marker : Hostkit.Lease_Files.Lease;
   begin
      Ran := False;
      --  Durable, and held, before the payload leaves, as Restore marks it:
      --  a stop part way leaves a marked stage the sweep finishes.
      if not Hold_Marker (Stage, Vacated_Marker, Marker) then
         return False;
      end if;
      Ran := True;
      if not Leave.all then
         --  refusal-safe: a refused payload keeps the marker
         Let_Go_Marker (Stage, Vacated_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
         return False;
      end if;
      --  Its record goes only with its stage; a stage that will not go yet
      --  keeps both, marked, for Sweep_Registry to finish.
      begin
         Remove_Stage_Holding (Stage, Marker);
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
      end;
      Hostkit.Lease_Files.Release (Marker);
      if Files.IO.Fs_Primitives.Entry_Is_Absent (Stage) then
         Unregister (Path);
      end if;
      return True;
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         if Hostkit.Lease_Files.Is_Held (Marker) then
            --  refusal-safe: a refused payload keeps the marker
            Let_Go_Marker (Stage, Vacated_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
         end if;
         return False;
   end Vacate;
