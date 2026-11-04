with GNAT.Directory_Operations;

separate (Files.Operations)
--  Full paths of every entry directly inside Directory (hidden entries
--  included). Used as the "already exists" set for conflict detection and for
--  rename uniquification, so a renamed paste avoids any existing name, not
--  just the colliding one. Listed is False, with an empty set, when the
--  directory cannot be scanned or holds more than Max_Destination_Entries
--  entries; the caller then checks the incoming names one by one, and a
--  renamed paste may then pick a name already there, which the publish
--  (never replacing) refuses rather than overwrites.
--  The names are read straight from the directory: Ada.Directories' search
--  drops a dangling link, and a paste onto one must still ask.
function Existing_Destination_Paths
  (Directory : String;
   Listed    : out Boolean)
   return Files.Types.String_Vectors.Vector
is
   Max_Destination_Entries : constant Natural := 100_000;
   Result : Files.Types.String_Vectors.Vector;
   Dir : GNAT.Directory_Operations.Dir_Type;
   Buffer : String (1 .. 4_096);
   Last : Natural;
   Count : Natural := 0;
begin
   Listed := False;
   GNAT.Directory_Operations.Open (Dir, Directory);
   loop
      GNAT.Directory_Operations.Read (Dir, Buffer, Last);
      exit when Last = 0;
      if Count = Max_Destination_Entries or else Last = Buffer'Last then
         --  Too many to list, or a name longer than any filesystem stores.
         GNAT.Directory_Operations.Close (Dir);
         return Files.Types.String_Vectors.Empty_Vector;
      end if;
      if Buffer (1 .. Last) /= "." and then Buffer (1 .. Last) /= ".." then
         Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Buffer (1 .. Last))));
         Count := Count + 1;
      end if;
   end loop;
   GNAT.Directory_Operations.Close (Dir);
   Listed := True;
   return Result;
exception
   when Failure : others =>
      Files.Diagnostics.Note (Failure, "Files.Operations");
      if GNAT.Directory_Operations.Is_Open (Dir) then
         begin
            GNAT.Directory_Operations.Close (Dir);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Operations.Transfer");
         end;
      end if;
      Listed := False;
      return Files.Types.String_Vectors.Empty_Vector;
end Existing_Destination_Paths;
