separate (Files.File_System)
function Executable_Format_Info (Path : String) return Files.Extra_Info.Info is
   File   : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
   Buffer : Ada.Streams.Stream_Element_Array (1 .. 4);
   Last   : Ada.Streams.Stream_Element_Offset;
begin
   File := Files.Fs_Primitives.Open_Regular_Read (Path);
   if File = GNAT.OS_Lib.Invalid_FD then
      return Files.Extra_Info.No_Info;
   end if;
   Read_Descriptor (File, Buffer, Last);
   Close_Read_Descriptor (File);

   if Matches_Signature (Buffer, Last, ELF_Magic) then
      return Files.Extra_Info.Make (Files.Extra_Info.Executable_Format, Value => "elf");
   elsif Matches_Signature (Buffer, Last, PE_Magic) then
      return Files.Extra_Info.Make (Files.Extra_Info.Executable_Format, Value => "pe");
   elsif Matches_Signature (Buffer, Last, Script_Magic) then
      return Files.Extra_Info.Make (Files.Extra_Info.Executable_Format, Value => "script");
   else
      return Files.Extra_Info.Make (Files.Extra_Info.Executable_Format, Value => "unknown");
   end if;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      Close_Read_Descriptor (File);
      return Files.Extra_Info.No_Info;
end Executable_Format_Info;
