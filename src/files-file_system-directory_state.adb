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
      Latest_Modified       => Ada.Calendar.Time_Of (1901, 1, 1),
      Latest_Modified_Known => False);

   function Entry_Checksum
     (Name : String;
      Kind : Ada.Directories.File_Kind;
      Size : Long_Long_Integer)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Value   : Long_Long_Integer := Long_Long_Integer (Ada.Directories.File_Kind'Pos (Kind) + 1);
   begin
      for Character_Value of Name loop
         Value :=
           (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
      end loop;

      Value := (Value * 131 + Long_Long_Integer'Max (0, Size)) mod Modulus;
      return Natural (Value);
   end Entry_Checksum;

   procedure Add_Entry (Name : String) is
   begin
      Result.Entry_Count := Result.Entry_Count + 1;
      declare
         Full     : constant String := Join_Path (To_String (Result.Path), Name);
         Kind     : Ada.Directories.File_Kind := Ada.Directories.Special_File;
         Size     : Long_Long_Integer := 0;
         Modified : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      begin
         begin
            Kind := Ada.Directories.Kind (Full);
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Directory");
         end;

         if Kind = Ada.Directories.Ordinary_File then
            begin
               Size := Long_Long_Integer (Ada.Directories.Size (Full));
            exception
               when others =>
                  Size := 0;
            end;
         end if;

         Result.Entry_State_Checksum :=
           (Result.Entry_State_Checksum + Entry_Checksum (Name, Kind, Size)) mod 1_000_000_007;

         begin
            Modified := Ada.Directories.Modification_Time (Full);
            if not Result.Latest_Modified_Known
              or else Modified > Result.Latest_Modified
            then
               Result.Latest_Modified := Modified;
               Result.Latest_Modified_Known := True;
            end if;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.File_System.Directory");
         end;
      exception
         when others =>
            Result.Entry_State_Checksum :=
              (Result.Entry_State_Checksum
               + Entry_Checksum (Name, Ada.Directories.Special_File, 0)) mod 1_000_000_007;
      end;
   end Add_Entry;
begin
   if not Files.Fs_Primitives.Directory_Exists (Path)
   then
      return Result;
   end if;

   Result.Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
   Result.Exists := True;
   Support.For_Each_Entry (Path, Add_Entry'Access);
   return Result;
exception
   when others =>
      --  A bounded enumeration failure may happen after some entries were
      --  accumulated.  Once the scan is unavailable none of those partial
      --  counters or timestamps are authoritative.
      return (Path => Result.Path, others => <>);
end Directory_State;
