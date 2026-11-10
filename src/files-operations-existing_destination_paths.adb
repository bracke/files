with Files.Fs_Primitives;
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
   Too_Many : Boolean := False;

   procedure Add (Name : String; Stop : in out Boolean) is
   begin
      if Natural (Result.Length) = Max_Destination_Entries then
         Too_Many := True;
         Stop := True;
      else
         Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Name)));
      end if;
   end Add;
begin
   Files.Fs_Primitives.For_Each_Name (Directory, Add'Access);
   Listed := not Too_Many;
   return (if Too_Many then Files.Types.String_Vectors.Empty_Vector else Result);
exception
   when Failure : others =>
      --  Unreadable, or a name longer than any filesystem stores.
      Files.Diagnostics.Note (Failure, "Files.Operations");
      Listed := False;
      return Files.Types.String_Vectors.Empty_Vector;
end Existing_Destination_Paths;
