with Files.Name_Parts;

separate (Files.File_System.Recovery)
   function Release
     (Path     : String;
      To_Trash : not null access function (Path, Original : String) return Mutation_Result)
      return Mutation_Result
   is
      Stage  : constant String := Files.IO.Fs_Primitives.Parent_Directory (Path);
      Holder : constant String := Hostkit.Fs.Join (Stage, Release_Name);
      Failed : constant Mutation_Result :=
        (Success => False, Error_Key => To_Unbounded_String ("error.trash.failed"));
      --  Held from before the payload leaves until the release is over.
      Marker : Hostkit.Lease_Files.Lease;

      --  Stop short: the marker goes only with the payload back in place.
      function Give_Up return Mutation_Result is
      begin
         --  refusal-safe: a refused payload keeps the marker
         Let_Go_Marker (Stage, Releasing_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
         return Failed;
      end Give_Up;
   begin
      --  A release or restore stopped earlier: put its payload back, or
      --  finish it -- only through the markers it left, which also tells it
      --  from a stage Preserve is still filling (no payload, no marker).
      Resume_Interrupted_Release (Path);
      if Files.IO.Fs_Primitives.Entry_Is_Absent (Path) then
         if Only_Stage_Left (Path)
           and then Finish_Stopped_Stage (Path)
           and then Files.IO.Fs_Primitives.Entry_Is_Absent (Stage)
         then
            Unregister (Path);
            return (Success => True, Error_Key => Null_Unbounded_String);
         end if;
         return Failed;
      end if;
      if not Recognizes (Path)
        or else not Contains_Only_Owned_Entries (Stage)
        or else not Hold_Marker (Stage, Releasing_Marker, Marker)
      then
         --  Not a payload of ours, or another release is running on it.
         return Failed;
      end if;
      if not Recognizes (Path) then
         --  Another release finished between the check and the marker.
         return Give_Up;
      end if;
      declare
         Original : constant String := Original_Path (Path);
         Leaf     : constant String :=
           (if Valid_Absolute_Path (Original) then Files.Name_Parts.Leaf_Of (Original) else "recovered");
         --  A folder of its own, so the original's name cannot meet the
         --  stage's own files.
         Named    : constant String := Hostkit.Fs.Join (Holder, Leaf);
      begin
         Files.IO.Fs_Primitives.Create_Directory (Holder);
         if not Support.Move_No_Replace (Path, Named) then
            Files.IO.Fs_Primitives.Delete_Directory (Holder);
            return Give_Up;
         end if;
         if not To_Trash (Named, (if Valid_Absolute_Path (Original) then Original else "")).Success then
            if Support.Move_No_Replace (Named, Path) then
               Files.IO.Fs_Primitives.Delete_Directory (Holder);
            end if;
            return Give_Up;
         end if;
      end;
      Remove_Stage_Holding (Stage, Marker);
      Unregister (Path);
      return (Success => True, Error_Key => Null_Unbounded_String);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         if Hostkit.Lease_Files.Is_Held (Marker) then
            --  refusal-safe: a refused payload keeps the marker
            Let_Go_Marker (Stage, Releasing_Marker, Marker, Remove => Files.IO.Fs_Primitives.Entry_Exists (Path));
         end if;
         return Failed;
   end Release;
