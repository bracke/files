separate (Files.File_System.Recovery)
   function Original_Path (Path : String) return String is
      Input : aliased Files.Lease_Streams.Input_Stream;
      Target : UString;
      Identity : UString;
      Record_Path : constant String :=
        Hostkit.Fs.Join (Files.Fs_Primitives.Parent_Directory (Path), "original");
   begin
      if Read_Owner (Files.Fs_Primitives.Parent_Directory (Path), Target, Identity) then
         return To_String (Target);
      end if;
      if not Record_Is_Regular
        (Record_Path, Max_Path_Length + 16)
      then
         return "";
      end if;
      if Files.Lease_Streams.Open (Record_Path, Input) /=
          Hostkit.Lease_Files.Opened
        or else Files.Lease_Streams.Size (Input) > Max_Path_Length + 16
      then
         Files.Lease_Streams.Release (Input);
         return "";
      end if;
      Target := To_Unbounded_String
        (Files.Bounded_Streams.Input_String
           (Input'Access, Max_Path_Length));
      if not Files.Lease_Streams.End_Of_Stream (Input) then
         raise Ada.Directories.Use_Error;
      end if;
      Files.Lease_Streams.Release (Input);
      return
        (if Valid_Absolute_Path (To_String (Target)) then
            To_String (Target)
         else "");
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         Files.Lease_Streams.Release (Input);
         return "";
   end Original_Path;
