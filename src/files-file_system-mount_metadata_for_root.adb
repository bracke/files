separate (Files.File_System)
function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is
   File     : Ada.Text_IO.File_Type;
   Line     : Unbounded_String;
   Complete : Boolean;
   Result   : Mount_Metadata;
begin
   if not Ada.Directories.Exists ("/proc/mounts") then
      return Result;
   end if;

   Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "/proc/mounts");
   while not Ada.Text_IO.End_Of_File (File) loop
      Files.Bounded_Text_IO.Read_Line
        (File, Max_Mount_Record_Length, Line, Complete);
      if Complete then
         declare
            Text        : constant String := To_String (Line);
            Mount_Point : constant String := Mount_Field (Text, 2);
         begin
            if Mount_Point = Path then
               declare
                  Source : constant String := Mount_Field (Text, 1);
                  Known  : Boolean := False;
               begin
                  Ada.Text_IO.Close (File);
                  Result.Source_Device := To_Unbounded_String (Source);
                  Result.Filesystem_Type := To_Unbounded_String (Mount_Field (Text, 3));
                  Result.Mount_Options := To_Unbounded_String (Mount_Field (Text, 4));
                  Result.Removable := Removable_Status_For (Source, Known);
                  Result.Removable_Known := Known;
                  Result.Found := True;
                  return Result;
               end;
            end if;
         end;
      end if;
   end loop;

   Ada.Text_IO.Close (File);
   return Result;
exception
   when others =>
      Safe_Close (File);
      return (others => <>);
end Mount_Metadata_For_Root;
