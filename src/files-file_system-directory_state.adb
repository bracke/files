separate (Files.File_System)
function Directory_State
  (Path : String)
   return Directory_Signature
is
   Result    : Directory_Signature :=
     (Path                  => To_Unbounded_String (Path),
      Exists                => False,
      Entry_Count           => 0,
      Entry_State_Checksum  => 0,
      Latest_Modified       => Files.Types.Unknown_Time,
      Latest_Modified_Known => False);

   procedure Add_Entry (Name : String) is
   begin
      Add_To_Signature (Result, Name);
   end Add_Entry;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path)
   then
      return Result;
   end if;

   Result.Path := To_Unbounded_String (Files.Fs_Primitives.Full_Name (Path));
   Result.Exists := True;
   Support.For_Each_Entry (Path, Add_Entry'Access);
   return Result;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      --  A bounded enumeration failure may happen after some entries were
      --  accumulated.  Once the scan is unavailable none of those partial
      --  counters or timestamps are authoritative.
      return (Path => Result.Path, others => <>);
end Directory_State;
